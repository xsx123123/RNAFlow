#!/usr/bin/env python3
"""
RNAFlow MCP Server
A Model Context Protocol server for RNA-seq analysis using RNAFlow
"""

import os
import sys
import yaml
import csv  # 优化：移至顶部全局导入
import asyncio  # 优化：引入异步处理
import subprocess
import shutil
import logging
import sqlite3
import json
from datetime import datetime
from pathlib import Path
from typing import Optional, List, Dict, Any
from fastmcp import FastMCP
from pydantic import BaseModel, Field

try:
    import psutil

    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False


def setup_logging():
    """配置日志系统，输出到logs/mcp/目录"""
    log_dir = Path(__file__).parent / "logs" / "mcp"
    log_dir.mkdir(parents=True, exist_ok=True)

    # 生成带时间戳的日志文件名
    log_filename = datetime.now().strftime("mcp_server_%Y%m%d_%H%M%S.log")
    log_file = log_dir / log_filename

    # 配置日志格式
    log_format = logging.Formatter(
        "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    # 文件处理器
    file_handler = logging.FileHandler(log_file, encoding="utf-8")
    file_handler.setFormatter(log_format)
    file_handler.setLevel(logging.DEBUG)

    # 控制台处理器
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(log_format)
    console_handler.setLevel(logging.INFO)

    # 获取logger
    logger = logging.getLogger("RNAFlowMCP")
    logger.setLevel(logging.DEBUG)
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)

    # 同时也为第三方库设置日志
    logging.getLogger("fastmcp").setLevel(logging.INFO)

    logger.info(f"=== RNAFlow MCP Server 启动 ===")
    logger.info(f"日志文件: {log_file}")

    return logger, log_file


# 初始化日志系统
logger, current_log_file = setup_logging()

# Add the parent directory to path to access RNAFlow
sys.path.insert(0, str(Path(__file__).parent.parent))

# Initialize MCP server
mcp = FastMCP("RNAFlow")

# Configuration
RNAFLOW_ROOT = Path(__file__).parent.parent
SKILLS_DIR = RNAFLOW_ROOT / "skills"
CONFIG_DIR = RNAFLOW_ROOT / "config"
EXAMPLES_DIR = SKILLS_DIR / "examples"
MCP_CONFIG_FILE = Path(__file__).parent / "mcp_config.yaml"


# Load local MCP configuration for tool paths
def load_mcp_config():
    config = {
        "conda_path": "conda",
        "snakemake_path": "snakemake",
        "default_env": "rnaflow",
    }
    if MCP_CONFIG_FILE.exists():
        try:
            with open(MCP_CONFIG_FILE, "r") as f:
                user_config = yaml.safe_load(f)
                if user_config:
                    config.update(user_config)
        except Exception:
            pass
    return config


MCP_PATHS = load_mcp_config()


# ========== 数据库相关功能 ==========
def init_database():
    """初始化SQLite数据库，创建项目运行记录表"""
    db_dir = Path(__file__).parent / "data"
    db_dir.mkdir(parents=True, exist_ok=True)
    db_path = db_dir / "rnaflow_runs.db"

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # 创建项目运行记录表
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS runs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            run_id TEXT UNIQUE NOT NULL,
            project_name TEXT NOT NULL,
            genome_version TEXT,
            species TEXT,
            config_path TEXT NOT NULL,
            config_json TEXT,
            cores INTEGER,
            start_time TEXT NOT NULL,
            end_time TEXT,
            status TEXT DEFAULT 'running',
            log_file TEXT,
            pid INTEGER,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    # 创建索引
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_run_id ON runs(run_id)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_project_name ON runs(project_name)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_status ON runs(status)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_start_time ON runs(start_time)")

    conn.commit()
    conn.close()

    logger.info(f"数据库已初始化: {db_path}")
    return db_path


def get_db_connection():
    """获取数据库连接"""
    db_path = Path(__file__).parent / "data" / "rnaflow_runs.db"
    return sqlite3.connect(db_path)


def record_run_start(
    run_id: str,
    project_name: str,
    config_path: str,
    config_dict: Dict,
    cores: int,
    log_file: str,
    pid: int = None,
):
    """记录项目运行开始"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # 读取config.yaml的关键信息
        genome_version = config_dict.get(
            "Genome_Version", config_dict.get("genome_version", "")
        )
        species = config_dict.get("species", "")

        cursor.execute(
            """
            INSERT INTO runs 
            (run_id, project_name, genome_version, species, config_path, 
             config_json, cores, start_time, status, log_file, pid)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
            (
                run_id,
                project_name,
                genome_version,
                species,
                config_path,
                json.dumps(config_dict, ensure_ascii=False),
                cores,
                datetime.now().isoformat(),
                "running",
                log_file,
                pid,
            ),
        )

        conn.commit()
        conn.close()
        logger.info(f"已记录运行开始: run_id={run_id}, project={project_name}")
        return True
    except sqlite3.IntegrityError:
        logger.warning(f"运行ID冲突: {run_id}")
        return False
    except Exception as e:
        logger.error(f"记录运行开始失败: {str(e)}", exc_info=True)
        return False


def check_run_id_conflict(run_id: str) -> bool:
    """检查运行ID是否已存在"""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id FROM runs WHERE run_id = ?", (run_id,))
    exists = cursor.fetchone() is not None
    conn.close()
    return exists


def get_run_info(
    run_id: str = None, project_name: str = None, status: str = None, limit: int = 50
) -> List[Dict]:
    """查询运行信息

    Args:
        run_id: 按运行ID查询
        project_name: 按项目名称查询
        status: 按状态查询 (running, completed, failed)
        limit: 返回结果数量限制
    """
    conn = get_db_connection()
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    query = "SELECT * FROM runs WHERE 1=1"
    params = []

    if run_id:
        query += " AND run_id = ?"
        params.append(run_id)
    if project_name:
        query += " AND project_name LIKE ?"
        params.append(f"%{project_name}%")
    if status:
        query += " AND status = ?"
        params.append(status)

    query += " ORDER BY start_time DESC LIMIT ?"
    params.append(limit)

    cursor.execute(query, params)
    rows = cursor.fetchall()

    results = []
    for row in rows:
        result = dict(row)
        if result.get("config_json"):
            try:
                result["config"] = json.loads(result["config_json"])
            except:
                result["config"] = None
        del result["config_json"]
        results.append(result)

    conn.close()
    return results


def get_run_summary(start_date: str = None, end_date: str = None) -> Dict:
    """获取一段时间内的运行统计

    Args:
        start_date: 开始日期 (YYYY-MM-DD)
        end_date: 结束日期 (YYYY-MM-DD)
    """
    conn = get_db_connection()
    cursor = conn.cursor()

    query = "SELECT status, COUNT(*) as count FROM runs WHERE 1=1"
    params = []

    if start_date:
        query += " AND date(start_time) >= ?"
        params.append(start_date)
    if end_date:
        query += " AND date(start_time) <= ?"
        params.append(end_date)

    query += " GROUP BY status"
    cursor.execute(query, params)
    rows = cursor.fetchall()

    summary = {"total_runs": 0, "by_status": {}}

    for status, count in rows:
        summary["by_status"][status] = count
        summary["total_runs"] += count

    # 获取总项目数
    cursor.execute("SELECT COUNT(DISTINCT project_name) FROM runs")
    summary["unique_projects"] = cursor.fetchone()[0]

    conn.close()
    return summary


# 初始化数据库
DB_PATH = init_database()


class ProjectConfig(BaseModel):
    """Project configuration model"""

    project_name: str = Field(..., description="Name of the project")
    genome_version: str = Field(
        ..., description="Genome version (e.g., hg38, TAIR10.1)"
    )
    species: str = Field(..., description="Species name (e.g., Homo_sapiens)")
    raw_data_path: List[str] = Field(..., description="Paths to raw data directories")
    workflow_dir: str = Field(..., description="Working directory for workflow")
    output_dir: str = Field(..., description="Output directory for results")
    only_qc: bool = Field(default=False, description="Only run QC analysis")


@mcp.tool()
def list_supported_genomes() -> List[Dict[str, str]]:
    """List all supported genome versions in RNAFlow"""
    logger.info("=== 调用工具: list_supported_genomes ===")

    reference_yaml = CONFIG_DIR / "reference.yaml"
    if not reference_yaml.exists():
        error_msg = "reference.yaml not found"
        logger.error(error_msg)
        return [{"error": error_msg}]

    logger.info(f"读取配置文件: {reference_yaml}")
    with open(reference_yaml, "r", encoding="utf-8") as f:
        ref_config = yaml.safe_load(f)

    genomes = []
    source = "unknown"

    # 优先从 mcp_genome_version 读取，这样可以和分析流程版本保持一致
    if "mcp_genome_version" in ref_config and ref_config["mcp_genome_version"]:
        source = "mcp_genome_version"
        for genome_name, genome_info in ref_config["mcp_genome_version"].items():
            genomes.append(
                {
                    "name": genome_info.get("name", genome_name),
                    "description": genome_info.get(
                        "description", f"Reference genome: {genome_name}"
                    ),
                }
            )
    # 如果没有 mcp_genome_version，则回退到从 STAR_index 读取
    elif "STAR_index" in ref_config:
        source = "STAR_index"
        for genome_name, genome_info in ref_config["STAR_index"].items():
            genomes.append(
                {"name": genome_name, "description": f"Reference genome: {genome_name}"}
            )

    logger.info(f"从 {source} 读取到 {len(genomes)} 个基因组版本")
    for genome in genomes:
        logger.debug(f"  - {genome['name']}: {genome['description']}")

    logger.info("=== 工具完成: list_supported_genomes ===")
    return genomes


@mcp.tool()
def get_config_template(template_type: str = "standard") -> str:
    """Get an RNAFlow configuration template"""
    template_files = {
        "complete": EXAMPLES_DIR / "config_complete.yaml",
        "standard": EXAMPLES_DIR / "config_standard_deg.yaml",
        "qc_only": EXAMPLES_DIR / "config_qc_only.yaml",
    }
    template_file = template_files.get(template_type, template_files["standard"])

    if not template_file.exists():
        return f"Error: Template {template_type} not found"

    with open(template_file, "r", encoding="utf-8") as f:
        return f.read()


@mcp.tool()
def generate_config_file(config: ProjectConfig, output_path: str) -> str:
    """
    Generate an RNAFlow config.yaml file using the structured ProjectConfig model
    """
    try:
        out_path = Path(output_path).resolve()
        out_path.parent.mkdir(parents=True, exist_ok=True)

        # 优化：利用预定义的 Pydantic 模型生成标准的 YAML 配置
        config_dict = config.model_dump()

        with open(out_path, "w", encoding="utf-8") as f:
            yaml.dump(config_dict, f, default_flow_style=False, sort_keys=False)

        return f"Successfully generated config file at {out_path}"
    except Exception as e:
        return f"Error generating config file: {str(e)}"


@mcp.tool()
def create_sample_csv(sample_data: List[Dict[str, str]], output_path: str) -> str:
    """Create a samples.csv file for RNAFlow"""
    try:
        out_path = Path(output_path).resolve()
        out_path.parent.mkdir(parents=True, exist_ok=True)

        with open(out_path, "w", newline="", encoding="utf-8") as csvfile:
            fieldnames = ["sample", "sample_name", "group"]
            # 优化：添加 extrasaction='ignore' 防止 LLM 传入多余字段导致崩溃
            writer = csv.DictWriter(
                csvfile, fieldnames=fieldnames, extrasaction="ignore"
            )
            writer.writeheader()
            for sample in sample_data:
                # 优化：补全缺失字段防止 KeyError
                safe_sample = {key: sample.get(key, "unknown") for key in fieldnames}
                writer.writerow(safe_sample)
        return f"Successfully created samples.csv at {out_path}"
    except Exception as e:
        return f"Error creating samples.csv: {str(e)}"


@mcp.tool()
def create_contrasts_csv(contrasts: List[Dict[str, str]], output_path: str) -> str:
    """Create a contrasts.csv file for differential peak analysis"""
    try:
        out_path = Path(output_path).resolve()
        out_path.parent.mkdir(parents=True, exist_ok=True)

        with open(out_path, "w", newline="", encoding="utf-8") as csvfile:
            fieldnames = ["contrast", "treatment"]
            writer = csv.DictWriter(
                csvfile, fieldnames=fieldnames, extrasaction="ignore"
            )
            writer.writeheader()
            for contrast in contrasts:
                safe_contrast = {
                    key: contrast.get(key, "unknown") for key in fieldnames
                }
                writer.writerow(safe_contrast)
        return f"Successfully created contrasts.csv at {out_path}"
    except Exception as e:
        return f"Error creating contrasts.csv: {str(e)}"


@mcp.tool()
def validate_config(config_path: str) -> Dict[str, Any]:
    """Validate an RNAFlow configuration file"""
    config_file = Path(config_path).resolve()
    if not config_file.exists():
        return {"valid": False, "errors": ["Configuration file not found"]}

    try:
        with open(config_file, "r", encoding="utf-8") as f:
            config = yaml.safe_load(f)

        errors = []
        required_fields = [
            "project_name",
            "Genome_Version",
            "species",
            "raw_data_path",
            "workflow",
            "data_deliver",
        ]

        for field in required_fields:
            if field not in config:
                errors.append(f"Missing required field: {field}")

        return {
            "valid": len(errors) == 0,
            "errors": errors,
            "config": config if len(errors) == 0 else None,
        }
    except Exception as e:
        return {"valid": False, "errors": [str(e)]}


@mcp.tool()
async def run_rnaflow(
    config_path: str,
    cores: int = 20,
    dry_run: bool = False,
    skip_resource_check: bool = False,
) -> str:
    """
    Run the RNAFlow pipeline (Asynchronous / Detached)

    Args:
        config_path: Path to config.yaml
        cores: Number of cores to use
        dry_run: Perform dry run only
        skip_resource_check: Skip system resource check (not recommended)
    """
    logger.info("=== 调用工具: run_rnaflow ===")
    logger.info(f"配置文件: {config_path}")
    logger.info(f"请求核心数: {cores}")
    logger.info(f"Dry Run: {dry_run}")
    logger.info(f"跳过资源检查: {skip_resource_check}")

    config_file = Path(config_path).resolve()
    if not config_file.exists():
        error_msg = f"Configuration file not found at {config_file}"
        logger.error(error_msg)
        return f"Error: {error_msg}"

    # 读取配置文件
    try:
        with open(config_file, "r", encoding="utf-8") as f:
            config_dict = yaml.safe_load(f)
    except Exception as e:
        error_msg = f"Failed to read config file: {str(e)}"
        logger.error(error_msg)
        return f"Error: {error_msg}"

    project_name = config_dict.get("project_name", "unknown_project")

    # 生成运行ID
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    run_id = f"{project_name}_{timestamp}"

    # 检查项目名称冲突（仅在非dry_run时）
    project_conflict_warning = ""
    if not dry_run:
        conflict_check = check_project_name_conflict(project_name)
        if conflict_check.get("has_conflict"):
            count = conflict_check.get("existing_runs_count", 0)
            project_conflict_warning = (
                f"⚠️  项目名称 '{project_name}' 已存在 {count} 条运行记录！\n"
                f"当前运行ID: {run_id}\n"
            )
            logger.warning(project_conflict_warning)

    # 检查系统资源
    resource_warnings = []
    if not skip_resource_check and not dry_run:
        logger.info("执行系统资源检查...")
        try:
            resources = check_system_resources()
            logger.debug(f"资源检查结果: {resources}")

            if resources.get("status") == "warning" and resources.get("warnings"):
                resource_warnings = resources.get("warnings", [])
                logger.warning(f"发现 {len(resource_warnings)} 个资源警告:")
                for warning in resource_warnings:
                    logger.warning(f"  - {warning}")

                # 检查CPU核心数是否合理
                if PSUTIL_AVAILABLE and "cpu" in resources:
                    cpu_info = resources["cpu"]
                    if "available_cores" in cpu_info:
                        available_cores = cpu_info["available_cores"]
                        if cores > available_cores and available_cores > 0:
                            warning_msg = f"请求的核心数({cores})超过可用核心数({available_cores})，建议减少到 {max(1, available_cores - 2)} 或更少"
                            resource_warnings.append(warning_msg)
                            logger.warning(warning_msg)
        except Exception as e:
            logger.error(f"资源检查失败: {str(e)}", exc_info=True)

    # 优化：更优雅的命令拼接方式
    snakemake_bin = MCP_PATHS.get("snakemake_path", "snakemake")
    cmd = [snakemake_bin]

    if dry_run:
        cmd.extend(["-n", "--quiet"])

    cmd.extend(
        [
            f"--cores={cores}",
            "-p",
            "--conda-frontend",
            "mamba",
            "--use-conda",
            "--rerun-triggers",
            "mtime",
            "--logger",
            "rich-loguru",
            "--config",
            f"analysisyaml={config_file}",
        ]
    )

    try:
        if dry_run:
            logger.info("执行 Dry Run...")
            logger.info(f"Dry Run 命令: {' '.join(cmd)}")

            # 优化：dry_run 使用 asyncio 快速返回预览结果
            process = await asyncio.create_subprocess_exec(
                *cmd,
                cwd=str(RNAFLOW_ROOT),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, stderr = await process.communicate()

            output = f"Dry Run Command: {' '.join(cmd)}\n\n"
            if stdout:
                output += f"Stdout:\n{stdout.decode()}\n"
                logger.debug(f"Dry Run Stdout:\n{stdout.decode()}")
            if stderr:
                output += f"Stderr:\n{stderr.decode()}\n"
                logger.warning(f"Dry Run Stderr:\n{stderr.decode()}")

            logger.info("Dry Run 完成")
            logger.info("=== 工具完成: run_rnaflow ===")
            return output
        else:
            logger.info("启动后台运行...")
            # 优化：实际运行使用后台游离进程 (Detached Process)，彻底释放 MCP 服务器
            log_file = config_file.parent / "rnaflow_run.log"
            logger.info(f"流程日志文件: {log_file}")
            logger.info(f"执行命令: {' '.join(cmd)}")

            with open(log_file, "w") as f:
                process = subprocess.Popen(
                    cmd,
                    cwd=str(RNAFLOW_ROOT),
                    stdout=f,
                    stderr=subprocess.STDOUT,
                    start_new_session=True,  # 将进程与当前服务器剥离
                )
                logger.info(f"后台进程已启动，PID: {process.pid}")

            # 记录到数据库
            record_success = record_run_start(
                run_id=run_id,
                project_name=project_name,
                config_path=str(config_file),
                config_dict=config_dict,
                cores=cores,
                log_file=str(log_file),
                pid=process.pid,
            )

            # 构建返回消息
            message_parts = []

            if project_conflict_warning:
                message_parts.append(project_conflict_warning)

            if resource_warnings:
                message_parts.append("⚠️  **资源警告**：")
                for warning in resource_warnings:
                    message_parts.append(f"  - {warning}")
                message_parts.append(
                    "\n尽管有上述警告，任务仍将启动。如果遇到问题，请考虑减少资源使用。\n"
                )

            message_parts.append(
                "🚀 RNAFlow pipeline has been successfully started in the background!"
            )
            message_parts.append(f"运行ID (Run ID): {run_id}")
            message_parts.append(f"项目名称: {project_name}")
            message_parts.append(f"使用核心数: {cores}")
            message_parts.append(f"Command: {' '.join(cmd)}")
            message_parts.append(f"流程日志: {log_file}")
            message_parts.append(f"MCP服务器日志: {current_log_file}")
            if record_success:
                message_parts.append("✅ 运行记录已保存到数据库")
            else:
                message_parts.append("⚠️  运行记录保存失败")
            message_parts.append("You can safely continue other tasks.")

            result = "\n".join(message_parts)
            logger.info("后台任务启动成功")
            logger.info("=== 工具完成: run_rnaflow ===")
            return result

    except FileNotFoundError:
        error_msg = (
            f"Error: '{snakemake_bin}' not found. "
            "Please update the 'snakemake_path' in mcp/mcp_config.yaml "
            "with the absolute path to your snakemake executable."
        )
        logger.error(error_msg)
        logger.info("=== 工具完成: run_rnaflow (失败) ===")
        return error_msg
    except Exception as e:
        logger.error(f"启动 RNAFlow 失败: {str(e)}", exc_info=True)
        logger.info("=== 工具完成: run_rnaflow (失败) ===")
        return f"Error starting RNAFlow: {str(e)}"


@mcp.tool()
def check_conda_environment(env_name: Optional[str] = None) -> Dict[str, Any]:
    """Check if the required conda environment exists and is valid"""
    logger.info("=== 调用工具: check_conda_environment ===")
    env_name = env_name or MCP_PATHS.get("default_env", "rnaflow")
    conda_bin = MCP_PATHS.get("conda_path", "conda")
    logger.info(f"检查环境: {env_name}")
    logger.info(f"Conda 路径: {conda_bin}")

    try:
        result = subprocess.run(
            [conda_bin, "--version"], capture_output=True, text=True
        )
        if result.returncode != 0:
            return {
                "available": False,
                "error": f"Conda not found at '{conda_bin}'. Please update mcp/mcp_config.yaml.",
            }

        result = subprocess.run(
            [conda_bin, "env", "list"], capture_output=True, text=True
        )
        env_exists = env_name in result.stdout

        snakemake_available = False
        if env_exists:
            try:
                # 尝试在该环境下运行 snakemake
                result = subprocess.run(
                    [conda_bin, "run", "-n", env_name, "snakemake", "--version"],
                    capture_output=True,
                    text=True,
                    timeout=10,
                )
                snakemake_available = result.returncode == 0
            except:
                pass

        result_data = {
            "available": env_exists,
            "env_name": env_name,
            "snakemake_available": snakemake_available,
            "conda_version": result.stdout.strip().split("\n")[0]
            if result.stdout
            else "unknown",
            "message": "Success"
            if env_exists
            else f"Environment '{env_name}' not found. Please create it or update config.",
        }
        logger.info(
            f"环境检查结果: available={env_exists}, snakemake_available={snakemake_available}"
        )
        logger.info("=== 工具完成: check_conda_environment ===")
        return result_data
    except FileNotFoundError:
        error_msg = f"Conda executable '{conda_bin}' not found. Please specify absolute path in mcp/mcp_config.yaml"
        logger.error(error_msg)
        logger.info("=== 工具完成: check_conda_environment (失败) ===")
        return {
            "available": False,
            "error": error_msg,
        }
    except Exception as e:
        logger.error(f"Conda环境检查失败: {str(e)}", exc_info=True)
        logger.info("=== 工具完成: check_conda_environment (失败) ===")
        return {"available": False, "error": str(e)}


@mcp.tool()
def check_system_resources() -> Dict[str, Any]:
    """
    Check system resources including CPU, memory, and disk usage.
    Returns resource status and warnings if resources are low.
    """
    logger.info("=== 调用工具: check_system_resources ===")
    resources = {
        "status": "healthy",
        "warnings": [],
        "cpu": {},
        "memory": {},
        "disk": {},
    }

    # Check CPU
    if PSUTIL_AVAILABLE:
        try:
            cpu_count = psutil.cpu_count(logical=True)
            cpu_percent = psutil.cpu_percent(interval=0.5)
            resources["cpu"] = {
                "total_cores": cpu_count,
                "usage_percent": cpu_percent,
                "available_cores": max(
                    1, cpu_count - int(cpu_count * cpu_percent / 100)
                ),
            }

            if cpu_percent > 80:
                resources["warnings"].append(f"高CPU使用率: {cpu_percent}%")
                resources["status"] = "warning"
        except Exception as e:
            resources["cpu"] = {"error": str(e)}
    else:
        resources["cpu"] = {
            "warning": "psutil not available, install with 'uv add psutil'"
        }

    # Check memory
    if PSUTIL_AVAILABLE:
        try:
            mem = psutil.virtual_memory()
            resources["memory"] = {
                "total_gb": round(mem.total / (1024**3), 2),
                "available_gb": round(mem.available / (1024**3), 2),
                "used_percent": mem.percent,
            }

            if mem.percent > 85:
                resources["warnings"].append(f"内存使用率过高: {mem.percent}%")
                resources["status"] = "warning"
            if mem.available < 4 * 1024**3:  # Less than 4GB available
                resources["warnings"].append("可用内存不足4GB，可能影响分析性能")
                resources["status"] = "warning"
        except Exception as e:
            resources["memory"] = {"error": str(e)}
    else:
        resources["memory"] = {"warning": "psutil not available"}

    # Check disk space
    try:
        # Check current working directory
        disk_usage = shutil.disk_usage("/")
        resources["disk"]["root"] = {
            "total_gb": round(disk_usage.total / (1024**3), 2),
            "used_gb": round(disk_usage.used / (1024**3), 2),
            "free_gb": round(disk_usage.free / (1024**3), 2),
            "used_percent": round((disk_usage.used / disk_usage.total) * 100, 1),
        }

        if disk_usage.free < 50 * 1024**3:  # Less than 50GB free
            resources["warnings"].append("根目录磁盘空间不足50GB")
            resources["status"] = "warning"

        # Check reference data directory if available
        try:
            ref_config_file = CONFIG_DIR / "reference.yaml"
            if ref_config_file.exists():
                with open(ref_config_file, "r", encoding="utf-8") as f:
                    ref_config = yaml.safe_load(f)
                    if "reference_path" in ref_config:
                        ref_path = Path(ref_config["reference_path"])
                        if ref_path.exists():
                            disk_usage_ref = shutil.disk_usage(ref_path)
                            resources["disk"]["reference"] = {
                                "path": str(ref_path),
                                "total_gb": round(disk_usage_ref.total / (1024**3), 2),
                                "free_gb": round(disk_usage_ref.free / (1024**3), 2),
                                "used_percent": round(
                                    (disk_usage_ref.used / disk_usage_ref.total) * 100,
                                    1,
                                ),
                            }
        except:
            pass

    except Exception as e:
        resources["disk"]["error"] = str(e)
        logger.error(f"磁盘检查失败: {str(e)}")

    logger.info(f"系统资源状态: {resources['status']}")
    if resources["warnings"]:
        logger.warning(f"资源警告数量: {len(resources['warnings'])}")
        for warning in resources["warnings"]:
            logger.warning(f"  - {warning}")

    logger.debug(f"CPU详情: {resources['cpu']}")
    logger.debug(f"内存详情: {resources['memory']}")
    logger.debug(f"磁盘详情: {resources['disk']}")

    logger.info("=== 工具完成: check_system_resources ===")
    return resources


@mcp.tool()
def list_runs(
    project_name: str = None, status: str = None, limit: int = 50
) -> List[Dict[str, Any]]:
    """
    列出RNAFlow项目运行记录

    Args:
        project_name: 按项目名称筛选（可选）
        status: 按状态筛选 (running/completed/failed)（可选）
        limit: 返回结果数量限制，默认50
    """
    logger.info("=== 调用工具: list_runs ===")
    logger.info(
        f"筛选条件 - project_name: {project_name}, status: {status}, limit: {limit}"
    )

    try:
        runs = get_run_info(project_name=project_name, status=status, limit=limit)
        logger.info(f"查询到 {len(runs)} 条运行记录")
        logger.info("=== 工具完成: list_runs ===")
        return runs
    except Exception as e:
        logger.error(f"查询运行记录失败: {str(e)}", exc_info=True)
        return [{"error": str(e)}]


@mcp.tool()
def get_run_details(run_id: str) -> Dict[str, Any]:
    """
    获取特定运行的详细信息

    Args:
        run_id: 运行ID
    """
    logger.info("=== 调用工具: get_run_details ===")
    logger.info(f"查询运行ID: {run_id}")

    try:
        runs = get_run_info(run_id=run_id, limit=1)
        if runs:
            logger.info(f"找到运行记录: {run_id}")
            logger.info("=== 工具完成: get_run_details ===")
            return runs[0]
        else:
            logger.warning(f"未找到运行记录: {run_id}")
            logger.info("=== 工具完成: get_run_details ===")
            return {"error": f"Run ID '{run_id}' not found"}
    except Exception as e:
        logger.error(f"获取运行详情失败: {str(e)}", exc_info=True)
        return {"error": str(e)}


def update_run_status_in_db(run_id: str, status: str, end_time: str = None):
    """更新数据库中的运行状态"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        if end_time:
            cursor.execute(
                "UPDATE runs SET status = ?, end_time = ? WHERE run_id = ?",
                (status, end_time, run_id),
            )
        else:
            cursor.execute(
                "UPDATE runs SET status = ? WHERE run_id = ?", (status, run_id)
            )

        conn.commit()
        conn.close()
        logger.info(f"已更新运行状态: run_id={run_id}, status={status}")
        return True
    except Exception as e:
        logger.error(f"更新运行状态失败: {str(e)}", exc_info=True)
        return False


@mcp.tool()
def check_snakemake_status(run_id: str = None) -> Dict[str, Any]:
    """
    检查Snakemake运行状态

    Args:
        run_id: 运行ID（可选，如不提供则检查所有running状态的任务）
    """
    logger.info("=== 调用工具: check_snakemake_status ===")
    logger.info(f"检查运行ID: {run_id}")

    try:
        # 获取要检查的运行记录
        if run_id:
            runs = get_run_info(run_id=run_id, limit=1)
        else:
            runs = get_run_info(status="running", limit=100)

        if not runs:
            return {
                "message": "没有找到运行中的任务"
                if not run_id
                else f"未找到运行ID: {run_id}"
            }

        results = []
        for run in runs:
            pid = run.get("pid")
            log_file = run.get("log_file")
            current_run_id = run.get("run_id")

            status_info = {
                "run_id": current_run_id,
                "project_name": run.get("project_name"),
                "pid": pid,
                "log_file": log_file,
                "process_status": "unknown",
                "recent_logs": [],
            }

            # 检查进程是否还在运行
            if pid and PSUTIL_AVAILABLE:
                try:
                    if psutil.pid_exists(pid):
                        process = psutil.Process(pid)
                        if process.is_running():
                            status_info["process_status"] = "running"
                            status_info["cpu_percent"] = process.cpu_percent()
                            status_info["memory_mb"] = round(
                                process.memory_info().rss / (1024**2), 2
                            )
                        else:
                            status_info["process_status"] = "exited"
                            # 进程已退出，更新数据库状态
                            update_run_status_in_db(
                                current_run_id, "completed", datetime.now().isoformat()
                            )
                    else:
                        status_info["process_status"] = "not_found"
                        update_run_status_in_db(
                            current_run_id, "failed", datetime.now().isoformat()
                        )
                except psutil.NoSuchProcess:
                    status_info["process_status"] = "not_found"
                    update_run_status_in_db(
                        current_run_id, "failed", datetime.now().isoformat()
                    )
                except Exception as e:
                    status_info["process_status"] = f"error: {str(e)}"

            # 读取最近的日志
            if log_file and Path(log_file).exists():
                try:
                    with open(log_file, "r", encoding="utf-8") as f:
                        lines = f.readlines()
                        status_info["recent_logs"] = [
                            line.rstrip() for line in lines[-20:]
                        ]  # 最后20行
                except Exception as e:
                    status_info["recent_logs"] = [f"无法读取日志: {str(e)}"]

            results.append(status_info)

        logger.info(f"检查了 {len(results)} 个任务的状态")
        logger.info("=== 工具完成: check_snakemake_status ===")
        return {"checked_runs": results}
    except Exception as e:
        logger.error(f"检查Snakemake状态失败: {str(e)}", exc_info=True)
        return {"error": str(e)}


@mcp.tool()
def get_snakemake_log(run_id: str, lines: int = 50) -> Dict[str, Any]:
    """
    获取Snakemake运行日志

    Args:
        run_id: 运行ID
        lines: 获取最后多少行，默认50行
    """
    logger.info("=== 调用工具: get_snakemake_log ===")
    logger.info(f"运行ID: {run_id}, 获取行数: {lines}")

    try:
        runs = get_run_info(run_id=run_id, limit=1)
        if not runs:
            return {"error": f"未找到运行ID: {run_id}"}

        log_file = runs[0].get("log_file")
        if not log_file:
            return {"error": "该运行没有记录日志文件路径"}

        log_path = Path(log_file)
        if not log_path.exists():
            return {"error": f"日志文件不存在: {log_file}"}

        with open(log_path, "r", encoding="utf-8") as f:
            all_lines = f.readlines()
            recent_lines = all_lines[-lines:] if len(all_lines) > lines else all_lines

        logger.info(f"成功读取日志文件: {log_file}")
        logger.info("=== 工具完成: get_snakemake_log ===")
        return {
            "run_id": run_id,
            "log_file": log_file,
            "total_lines": len(all_lines),
            "returned_lines": len(recent_lines),
            "logs": [line.rstrip() for line in recent_lines],
        }
    except Exception as e:
        logger.error(f"获取Snakemake日志失败: {str(e)}", exc_info=True)
        return {"error": str(e)}


@mcp.tool()
def get_run_statistics(start_date: str = None, end_date: str = None) -> Dict[str, Any]:
    """
    获取一段时间内的运行统计信息

    Args:
        start_date: 开始日期，格式 YYYY-MM-DD（可选）
        end_date: 结束日期，格式 YYYY-MM-DD（可选）
    """
    logger.info("=== 调用工具: get_run_statistics ===")
    logger.info(f"统计范围 - start_date: {start_date}, end_date: {end_date}")

    try:
        stats = get_run_summary(start_date=start_date, end_date=end_date)
        logger.info(f"统计结果: {stats}")
        logger.info("=== 工具完成: get_run_statistics ===")
        return stats
    except Exception as e:
        logger.error(f"获取统计信息失败: {str(e)}", exc_info=True)
        return {"error": str(e)}


@mcp.tool()
def check_project_name_conflict(project_name: str) -> Dict[str, Any]:
    """
    检查项目名称是否已存在，防止冲突

    Args:
        project_name: 要检查的项目名称
    """
    logger.info("=== 调用工具: check_project_name_conflict ===")
    logger.info(f"检查项目名称: {project_name}")

    try:
        existing_runs = get_run_info(project_name=project_name, limit=100)
        result = {
            "project_name": project_name,
            "has_conflict": len(existing_runs) > 0,
            "existing_runs_count": len(existing_runs),
            "existing_runs": existing_runs[:5],  # 只返回最近5条
        }

        if result["has_conflict"]:
            logger.warning(
                f"项目名称冲突: {project_name}, 已有 {len(existing_runs)} 条记录"
            )
        else:
            logger.info(f"项目名称可用: {project_name}")

        logger.info("=== 工具完成: check_project_name_conflict ===")
        return result
    except Exception as e:
        logger.error(f"检查项目名称冲突失败: {str(e)}", exc_info=True)
        return {"error": str(e)}


@mcp.tool()
def get_project_structure() -> Dict[str, Any]:
    """Get the recommended RNAFlow project structure"""
    return {
        "directories": [
            "Project_Root/00.raw_data/",
            "Project_Root/01.workflow/",
            "Project_Root/02.data_deliver/",
        ],
        "files": [
            "Project_Root/01.workflow/config.yaml",
            "Project_Root/01.workflow/samples.csv",
            "Project_Root/01.workflow/contrasts.csv",
        ],
        "description": "Recommended project structure for RNAFlow analysis",
    }


# Resources remain the same...
@mcp.resource("rnaflow://config-templates/complete")
def get_complete_config_template() -> str:
    template_file = EXAMPLES_DIR / "config_complete.yaml"
    if template_file.exists():
        with open(template_file, "r", encoding="utf-8") as f:
            return f.read()
    return "Template not found"


@mcp.resource("rnaflow://config-templates/standard")
def get_standard_config_template() -> str:
    template_file = EXAMPLES_DIR / "config_standard.yaml"
    if template_file.exists():
        with open(template_file, "r", encoding="utf-8") as f:
            return f.read()
    return "Template not found"


@mcp.resource("rnaflow://config-templates/qc-only")
def get_qc_config_template() -> str:
    template_file = EXAMPLES_DIR / "config_qc_only.yaml"
    if template_file.exists():
        with open(template_file, "r", encoding="utf-8") as f:
            return f.read()
    return "Template not found"


@mcp.resource("rnaflow://skills/main")
def get_skill_documentation() -> str:
    skill_file = SKILLS_DIR / "SKILL.md"
    if skill_file.exists():
        with open(skill_file, "r", encoding="utf-8") as f:
            return f.read()
    return "SKILL.md not found"


# --- Prompts section ---


@mcp.prompt()
def setup_new_project(project_name: str = "My_RNA_Project") -> str:
    """Guide the AI to set up a new RNAFlow analysis project"""
    return f"""I want to start a new RNA-seq analysis project named "{project_name}" using RNAFlow. 

Please follow these steps:
1. First, use `list_supported_genomes` to show me which reference genomes are available.
2. Check if my environment is ready using `check_conda_environment`.
3. Explain the recommended project structure using `get_project_structure`.
4. Ask me for the following details:
   - Species name
   - Absolute path to raw FASTQ data
   - Desired output directory
5. Once I provide those, use `generate_config_file` to create the configuration.
"""


@mcp.prompt()
def troubleshoot_failure(log_path: str = "01.workflow/rnaflow_run.log") -> str:
    """Guide the AI to help debug a pipeline failure"""
    return f"""My RNAFlow pipeline failed. The log file is located at "{log_path}".

Please help me debug by:
1. Reading the last 50 lines of the log file to identify the specific rule that failed.
2. Checking if there are any common issues like "Command not found" or "Out of memory".
3. Using `validate_config` to ensure my config.yaml is still valid.
4. Suggesting a fix or explaining the error message in simple terms.
"""


@mcp.prompt()
def prepare_publication_report() -> str:
    """Guide the AI to summarize results for a report or publication"""
    return """I have finished my RNA-seq analysis. Please help me summarize the results for a report.

Please:
1. Guide me to find the key QC metrics (e.g., TSS enrichment, FRiP scores).
2. Look for the peak calling results in the output directory.
3. Help me describe the differential analysis (DEG) results if they were performed.
4. Provide a structure for the "Methods" section of my paper based on the current RNAFlow workflow.
"""


if __name__ == "__main__":
    logger.info(f"Starting RNAFlow MCP Server...")
    logger.info(f"RNAFlow Root: {RNAFLOW_ROOT}")
    logger.info(f"配置文件: {MCP_CONFIG_FILE}")
    logger.info(f"Conda路径: {MCP_PATHS.get('conda_path')}")
    logger.info(f"Snakemake路径: {MCP_PATHS.get('snakemake_path')}")

    try:
        mcp.run()
    except Exception as e:
        logger.error(f"服务器运行异常: {str(e)}", exc_info=True)
        raise
