#!/usr/bin/env python3
"""
Snakemake execution services for RNAFlow MCP
"""

import asyncio
import subprocess
import yaml
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, Any

from core.logger import logger, current_log_file
from core.config import RNAFLOW_ROOT, MCP_PATHS
from db.crud import record_run_start, get_run_info, update_run_status_in_db


def _generate_confirmation_prompt(config_path: str, cores: int) -> str:
    """Generate user confirmation prompt"""
    config_file = Path(config_path).resolve()
    project_info = {
        "config_path": str(config_file),
        "project_name": "Unknown",
        "genome_version": "Unknown",
        "species": "Unknown",
        "analysis_type": "Unknown",
        "cores": cores,
    }

    if config_file.exists():
        try:
            with open(config_file, "r", encoding="utf-8") as f:
                config_dict = yaml.safe_load(f)
                project_info["project_name"] = config_dict.get(
                    "project_name", "Unknown"
                )
                project_info["genome_version"] = config_dict.get(
                    "Genome_Version", "Unknown"
                )
                project_info["species"] = config_dict.get("species", "Unknown")

                if config_dict.get("only_qc", False):
                    project_info["analysis_type"] = "QC Only"
                elif config_dict.get("deg", False):
                    if config_dict.get("call_variant") or config_dict.get("rmats"):
                        project_info["analysis_type"] = (
                            "Complete (DEG + Variants/Splicing)"
                        )
                    else:
                        project_info["analysis_type"] = "Standard (DEG Only)"
                else:
                    project_info["analysis_type"] = "Basic"
        except Exception as e:
            logger.warning(f"读取配置文件获取详细信息失败: {e}")

    prompt = f"""
╔══════════════════════════════════════════════════════════════════════╗
║                    ⚠️  RNAFlow分析待确认                                ║
╚══════════════════════════════════════════════════════════════════════╝

📋 **项目信息：**
   • 配置文件: {project_info["config_path"]}
   • 项目名称: {project_info["project_name"]}
   • 物种: {project_info["species"]}
   • 基因组版本: {project_info["genome_version"]}
   • 分析类型: {project_info["analysis_type"]}

⚙️ **运行参数：**
   • CPU核心数: {project_info["cores"]}

📝 **下一步操作：**

请确认是否开始RNAFlow分析？

如果您确认以上参数正确并准备开始分析，请使用以下命令：

```python
run_rnaflow(
    config_path="{project_info["config_path"]}",
    cores={project_info["cores"]},
    user_confirmed=True
)
```

✅ 设置 `user_confirmed=True` 将立即开始RNAFlow分析
"""
    logger.info("已生成用户确认提示")
    return prompt


async def run_rnaflow(
    config_path: str,
    cores: int = 20,
    dry_run: bool = False,
    skip_resource_check: bool = False,
    user_confirmed: bool = False,
) -> str:
    """Run RNAFlow pipeline (Asynchronous / Detached)"""
    logger.info("=== 调用工具: run_rnaflow ===")
    logger.info(f"配置文件: {config_path}")
    logger.info(f"请求核心数: {cores}")
    logger.info(f"Dry Run: {dry_run}")
    logger.info(f"跳过资源检查: {skip_resource_check}")
    logger.info(f"用户已确认: {user_confirmed}")

    if not user_confirmed and not dry_run:
        logger.info("等待用户确认...")
        return _generate_confirmation_prompt(config_path, cores)

    config_file = Path(config_path).resolve()
    if not config_file.exists():
        error_msg = f"Configuration file not found at {config_file}"
        logger.error(error_msg)
        return f"Error: {error_msg}"

    try:
        with open(config_file, "r", encoding="utf-8") as f:
            config_dict = yaml.safe_load(f)
    except Exception as e:
        error_msg = f"Failed to read config file: {str(e)}"
        logger.error(error_msg)
        return f"Error: {error_msg}"

    project_name = config_dict.get("project_name", "unknown_project")
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    run_id = f"{project_name}_{timestamp}"

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
            log_file = config_file.parent / "rnaflow_run.log"
            logger.info(f"流程日志文件: {log_file}")
            logger.info(f"执行命令: {' '.join(cmd)}")

            with open(log_file, "w") as f:
                process = subprocess.Popen(
                    cmd,
                    cwd=str(RNAFLOW_ROOT),
                    stdout=f,
                    stderr=subprocess.STDOUT,
                    start_new_session=True,
                )
                logger.info(f"后台进程已启动，PID: {process.pid}")

            record_success = record_run_start(
                run_id=run_id,
                project_name=project_name,
                config_path=str(config_file),
                config_dict=config_dict,
                cores=cores,
                log_file=str(log_file),
                pid=process.pid,
            )

            message_parts = [
                "🚀 RNAFlow pipeline has been successfully started in the background!",
                f"运行ID (Run ID): {run_id}",
                f"项目名称: {project_name}",
                f"使用核心数: {cores}",
                f"Command: {' '.join(cmd)}",
                f"流程日志: {log_file}",
                f"MCP服务器日志: {current_log_file}",
            ]
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
            f"Error: '{snakemake_bin}' not found. Please update mcp_config.yaml."
        )
        logger.error(error_msg)
        return error_msg
    except Exception as e:
        logger.error(f"启动 RNAFlow 失败: {str(e)}", exc_info=True)
        return f"Error starting RNAFlow: {str(e)}"
