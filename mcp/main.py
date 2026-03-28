#!/usr/bin/env python3
"""
RNAFlow MCP Server - Main Entry Point
Core entry: only FastMCP instance initialization, tool/resource registration

Optimized with:
- P0: Fixed async bug in backward compat tools
- P0: Legacy dispatcher to reduce tool count
- P1: Lazy database initialization
- P1: Async safety with executor for blocking operations
"""

import asyncio
import functools
import sys
from pathlib import Path
from typing import Dict, Any, Optional, List

from fastmcp import FastMCP

# Initialize logging and config
from core.logger import logger, current_log_file
from core.config import (
    RNAFLOW_ROOT,
    SKILLS_DIR,
    EXAMPLES_DIR,
    MCP_CONFIG_FILE,
    MCP_PATHS,
)

# Import models
from models.schemas import ProjectConfig

# Import services
from services.project_mgr import (
    list_supported_genomes,
    get_config_template,
    create_project_structure,
    generate_config_file,
    create_sample_csv,
    create_contrasts_csv,
    validate_config,
    get_project_structure,
    setup_complete_project,
    run_simple_qc_analysis,
    scan_fastq_directory,
)
from services.snakemake import run_rnaflow
from services.system import (
    check_conda_environment,
    check_system_resources,
    list_runs,
    get_run_details,
    get_run_statistics,
    check_project_name_conflict,
    check_snakemake_status,
    get_snakemake_log,
)

# Lazy database session
from db.session import get_db_path

# Initialize MCP server
mcp = FastMCP("RNAFlow")


# ========== Helper Functions ==========


@functools.lru_cache(maxsize=8)
def _read_template(path: Path) -> str:
    """
    Cache template file reads with error handling

    Args:
        path: Path to template file

    Returns:
        Template content or error message
    """
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        logger.error(f"Template not found: {path}")
        return f"Template not found: {path}"
    except Exception as e:
        logger.error(f"Error reading template {path}: {e}")
        return f"Error reading template: {e}"


# ========== Tools Registration ==========


@mcp.tool()
def list_supported_genomes_tool() -> List[Dict[str, str]]:
    """
    List all supported genome versions in RNAFlow

    Returns:
        List of genome dictionaries with name and description
    """
    return list_supported_genomes()


@mcp.tool()
def get_config_template_tool(template_type: str = "standard") -> str:
    """
    Get a complete RNAFlow configuration template

    Args:
        template_type: Template type - "standard", "complete", or "qc_only"

    Returns:
        Template YAML content as string
    """
    return get_config_template(template_type)


@mcp.tool()
async def create_project_structure_tool(project_root: str) -> Dict[str, Any]:
    """
    Create standard RNAFlow project directory structure

    Args:
        project_root: Path to project root directory

    Returns:
        Dict with success status and created directories
    """
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None, create_project_structure, project_root
    )


@mcp.tool()
def generate_config_file_tool(config: ProjectConfig, output_path: str) -> str:
    """
    Generate RNAFlow config.yaml using ProjectConfig model

    Args:
        config: ProjectConfig pydantic model instance
        output_path: Path where to write the config file

    Returns:
        Success message with file path or error message
    """
    return generate_config_file(config, output_path)


@mcp.tool()
def create_sample_csv_tool(sample_data: List[Dict[str, str]], output_path: str) -> str:
    """
    Create samples.csv file

    Args:
        sample_data: List of sample dicts with keys: sample, sample_name, group
        output_path: Path where to write samples.csv

    Returns:
        Success message or error message
    """
    return create_sample_csv(sample_data, output_path)


@mcp.tool()
def create_contrasts_csv_tool(contrasts: List[Dict[str, str]], output_path: str) -> str:
    """
    Create contrasts.csv file

    Args:
        contrasts: List of contrast dicts with keys: contrast, treatment
        output_path: Path where to write contrasts.csv

    Returns:
        Success message or error message
    """
    return create_contrasts_csv(contrasts, output_path)


@mcp.tool()
async def validate_config_tool(config_path: str) -> Dict[str, Any]:
    """
    Validate RNAFlow configuration file

    Args:
        config_path: Path to config.yaml file

    Returns:
        Dict with validity, errors, and warnings
    """
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None, validate_config, config_path
    )


@mcp.tool()
def get_project_structure_tool() -> Dict[str, Any]:
    """
    Get standard RNAFlow project structure

    Returns:
        Dict describing recommended project layout
    """
    return get_project_structure()


@mcp.tool()
async def setup_complete_project_tool(
    project_root: str,
    project_name: str,
    genome_version: str,
    species: str,
    analysis_mode: str = "standard",
    client: str = "Research_Lab",
    library_types: str = "fr-firststrand",
) -> Dict[str, Any]:
    """
    One-stop setup for complete RNAFlow project

    Creates directory structure and generates all config files.
    Does NOT execute analysis - use run_rnaflow_tool for that.

    Args:
        project_root: Path to project root directory
        project_name: Name of the project
        genome_version: Reference genome version (e.g., "hg38")
        species: Species name (e.g., "human")
        analysis_mode: "standard", "complete", or "qc_only"
        client: Client/lab name for records
        library_types: Library type, typically "fr-firststrand"

    Returns:
        Dict with success status and file paths
    """
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None,
        setup_complete_project,
        project_root,
        project_name,
        genome_version,
        species,
        analysis_mode,
        client,
        library_types,
    )


@mcp.tool()
async def run_simple_qc_analysis_tool(
    project_root: str,
    genome_version: str,
    species: str,
    project_name: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Simple one-click QC analysis

    Automatically creates project structure, generates config files,
    and prepares for QC-only analysis.

    Note: This creates the setup but does NOT execute the analysis.
    Use run_rnaflow_tool after reviewing the generated config.

    Args:
        project_root: Path to project root directory
        genome_version: Reference genome version
        species: Species name
        project_name: Optional project name (defaults to directory name)

    Returns:
        Dict with setup status and next steps
    """
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None,
        run_simple_qc_analysis,
        project_root,
        genome_version,
        species,
        project_name,
    )


@mcp.tool()
async def run_rnaflow_tool(
    config_path: str,
    cores: int = 20,
    dry_run: bool = False,
    skip_resource_check: bool = False,
    user_confirmed: bool = False,
) -> str:
    """
    Run RNAFlow pipeline (Asynchronous / Detached)

    Submit RNAFlow pipeline for execution. Returns immediately with a job_id.
    The pipeline runs in the background and can be monitored separately.

    IMPORTANT: This is async/non-blocking. Pipeline runs in background.
    Use check_snakemake_status_tool(run_id=job_id) to monitor progress.
    Use get_snakemake_log_tool(run_id=job_id) to view logs.

    Recommended workflow:
      1. Call with dry_run=True first to validate
      2. Review the output
      3. Call with user_confirmed=True to actually submit

    Args:
        config_path: Absolute path to config.yaml
        cores: CPU cores to allocate (default 20)
        dry_run: Validate only, do not execute
        skip_resource_check: Skip memory/disk checks (not recommended)
        user_confirmed: Must be True to submit real job

    Returns:
        Either confirmation prompt (if not confirmed) or job_id with status
    """
    return await run_rnaflow(
        config_path, cores, dry_run, skip_resource_check, user_confirmed
    )


@mcp.tool()
async def check_conda_environment_tool(env_name: Optional[str] = None) -> Dict[str, Any]:
    """
    Check if required conda environment exists and is valid

    Args:
        env_name: Name of conda environment to check (default from config)

    Returns:
        Dict with availability status and environment details
    """
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None, check_conda_environment, env_name
    )


@mcp.tool()
async def check_system_resources_tool() -> Dict[str, Any]:
    """
    Check system resources including CPU, memory, and disk usage

    Returns:
        Dict with CPU, memory, and disk status information
        Includes warnings if resources are insufficient
    """
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None, check_system_resources
    )


@mcp.tool()
async def list_runs_tool(
    project_name: str = None, status: str = None, limit: int = 50
) -> List[Dict[str, Any]]:
    """
    List RNAFlow project run records

    Args:
        project_name: Filter by project name
        status: Filter by run status (e.g., "running", "completed")
        limit: Maximum number of records to return

    Returns:
        List of run record dictionaries
    """
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None, list_runs, project_name, status, limit
    )


@mcp.tool()
async def get_run_details_tool(run_id: str) -> Dict[str, Any]:
    """
    Get details for a specific run

    Args:
        run_id: Unique run identifier

    Returns:
        Run details dictionary or error message
    """
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None, get_run_details, run_id
    )


@mcp.tool()
async def get_run_statistics_tool(
    start_date: str = None, end_date: str = None
) -> Dict[str, Any]:
    """
    Get run statistics for a period

    Args:
        start_date: Start date filter (ISO format)
        end_date: End date filter (ISO format)

    Returns:
        Statistics dictionary with counts and summaries
    """
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None, get_run_statistics, start_date, end_date
    )


@mcp.tool()
async def check_project_name_conflict_tool(project_name: str) -> Dict[str, Any]:
    """
    Check if project name already exists

    Args:
        project_name: Name to check for conflicts

    Returns:
        Dict indicating if conflict exists and listing existing runs
    """
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None, check_project_name_conflict, project_name
    )


@mcp.tool()
async def check_snakemake_status_tool(run_id: str = None) -> Dict[str, Any]:
    """
    Check Snakemake run status

    When run_id is None, returns status for all active running tasks.

    Args:
        run_id: Specific run ID to check (optional)
                   If None, checks all running tasks

    Returns:
        Dict with run status, process state, and recent logs
    """
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None, check_snakemake_status, run_id
    )


@mcp.tool()
async def get_snakemake_log_tool(run_id: str, lines: int = 50) -> Dict[str, Any]:
    """
    Get Snakemake run log

    Args:
        run_id: Unique run identifier
        lines: Number of lines to retrieve (default 50)

    Returns:
        Dict with log content and metadata
    """
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None, get_snakemake_log, run_id, lines
    )


@mcp.tool()
async def scan_samples_tool(directory_path: str) -> List[Dict[str, str]]:
    """
    扫描指定目录下的 FASTQ 文件并自动提取样本信息。
    
    遵守以下规范：
    1. sample: 去除 R1/R2/RAW/fastq 等后缀后的名称。
    2. sample_name: 具有表达性的 ID 缩写 (如 L1MLA1700058-PI_L18_1 -> PI_L18_1)。
    3. group: 默认初始化为 sample_name。
    """
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None, scan_fastq_directory, Path(directory_path)
    )


# ========== Legacy Configuration Support ==========


@mcp.tool(name="rnaflowGenerateConfigFile")
def rnaflow_generate_config_file_old(config: dict, output_path: str) -> str:
    """
    Backward compatibility: accepts old-style config dict

    Maps legacy field names to new ProjectConfig model format.
    Use generate_config_file_tool for new code.

    Args:
        config: Legacy-style dict with various field names
        output_path: Path where to write config file

    Returns:
        Success message or error message
    """
    logger.info("使用向后兼容的 rnaflowGenerateConfigFile (旧格式)")
    try:
        mapped_config = {
            "project_name": config.get("project_name", "unknown_project"),
            "Genome_Version": config.get(
                "fgenome_version", config.get("Genome_Version", "unknown")
            ),
            "species": config.get("species", "unknown"),
            "client": config.get("client", "Research_Lab"),
            "raw_data_path": config.get("raw_data_path", []),
            "sample_csv": config.get(
                "sample_csv", str(Path(config.get("workflow_dir", ".")) / "samples.csv")
            ),
            "paired_csv": config.get(
                "paired_csv",
                str(Path(config.get("workflow_dir", ".")) / "contrasts.csv"),
            ),
            "workflow": config.get("workflow", config.get("workflow_dir", ".")),
            "data_deliver": config.get("data_deliver", config.get("output_dir", ".")),
            "execution_mode": config.get("execution_mode", "local"),
            "Library_Types": config.get("Library_Types", "fr-firststrand"),
            "only_qc": config.get("only_qc", False),
            "deg": config.get("deg", not config.get("only_qc", False)),
            "call_variant": config.get("call_variant", False),
            "detect_novel_transcripts": config.get("detect_novel_transcripts", False),
            "rmats": config.get("rmats", False),
            "fastq_screen": config.get("fastq_screen", True),
            "report": config.get("report", True),
        }
        project_config = ProjectConfig(**mapped_config)
        return generate_config_file(project_config, output_path)
    except Exception as e:
        logger.error(f"旧格式配置生成失败: {str(e)}", exc_info=True)
        return f"Error: {str(e)}"


@mcp.tool(name="rnaflowValidateConfig")
def rnaflow_validate_config_old(config_path: str) -> Dict[str, Any]:
    """
    Backward compatibility alias with adjusted return format

    Returns legacy format with 'valid' and 'error' fields.
    Use validate_config_tool for new code with richer response.

    Args:
        config_path: Path to config.yaml file

    Returns:
        Dict with legacy format fields
    """
    result = validate_config(config_path)
    return {
        "valid": result.get("valid", False),
        "error": "; ".join(result.get("errors", [])) if result.get("errors") else None,
    }


# ========== CamelCase Backward Compatibility ==========


@mcp.tool(name="createProjectStructure")
async def create_project_structure_backward(project_root: str) -> Dict[str, Any]:
    """Backward compatibility alias for camelCase usage"""
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None, create_project_structure, project_root
    )


@mcp.tool(name="setupCompleteProject")
async def setup_complete_project_backward(
    project_root: str,
    project_name: str,
    genome_version: str,
    species: str,
    analysis_mode: str = "standard",
    client: str = "Research_Lab",
    library_types: str = "fr-firststrand",
) -> Dict[str, Any]:
    """Backward compatibility alias for camelCase usage"""
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None,
        setup_complete_project,
        project_root,
        project_name,
        genome_version,
        species,
        analysis_mode,
        client,
        library_types,
    )


# ========== Resources (with async support) ==========


@mcp.resource("rnaflow://config-templates/complete")
async def get_complete_config_template() -> str:
    """
    Resource: Complete RNAFlow configuration template

    Returns full-featured config with all analysis options enabled.
    """
    template_file = EXAMPLES_DIR / "config_complete.yaml"
    return _read_template(template_file)


@mcp.resource("rnaflow://config-templates/standard")
async def get_standard_config_template() -> str:
    """
    Resource: Standard DEG analysis template

    Returns config template for standard differential expression analysis.
    """
    template_file = EXAMPLES_DIR / "config_standard_deg.yaml"
    return _read_template(template_file)


@mcp.resource("rnaflow://config-templates/qc-only")
async def get_qc_config_template() -> str:
    """
    Resource: QC-only analysis template

    Returns config template for quality control analysis only (no DEG).
    """
    template_file = EXAMPLES_DIR / "config_qc_only.yaml"
    return _read_template(template_file)


@mcp.resource("rnaflow://skills/main")
async def get_skill_documentation() -> str:
    """
    Resource: RNAFlow SKILL.md documentation

    Returns main skill documentation content.
    """
    skill_file = SKILLS_DIR / "SKILL.md"
    return _read_template(skill_file)


# ========== Prompts ==========


@mcp.prompt()
def setup_new_project(project_name: str = "My_RNA_Project") -> str:
    """
    引导 AI 创建新的 RNAFlow 项目，并严格遵守样本命名、分组和确认规范。
    """
    return f"""我想开始一个名为 "{project_name}" 的 RNA-seq 分析项目。

请严格执行以下标准化操作程序 (SOP)：

1. 【样本扫描与识别】：
   - 当我提供原始数据目录时，你**必须**先调用 `scan_samples_tool`。
   - 准备 `samples.csv` 时，必须包含：`sample`, `sample_name`, `group` 三列。
   - **命名规则**：
     - `sample`: 去除 R1, R2, RAW, .fastq.gz 等后缀。
     - `sample_name`: 提取具有表达性的 ID 缩写。例如：`L1MLA1700058-PI_L18_1` 应提取为 `PI_L18_1`。
     - `group` 逻辑：
       - 若仅进行 QC 分析 (`only_qc: true`)，`group` 默认使用 `sample_name`。
       - 若我提供了样本配对/分组信息，请务必使用我提供的 group 名称。
       - 默认情况下使用 `sample_name`。

2. 【核心配置准备】：
   - 确认基因组版本。
   - 自动生成 `config.yaml`, `samples.csv` 和 `contrasts.csv`。

3. 【停顿与手动确认】：
   - **核心步骤**：在生成上述三个核心文件后，请向我展示它们的预览摘要。
   - 明确询问：“核心配置已生成（config.yaml, samples.csv, contrasts.csv），请手动确认无误后，再调用 run_rnaflow 开始分析。”
   - **严禁**在未得到我明确确认（如“确认”或“开始”）的情况下启动 `run_rnaflow`。
"""


@mcp.prompt()
def troubleshoot_failure(log_path: str = "01.workflow/rnaflow_run.log") -> str:
    """
    Guide AI to help debug a pipeline failure

    Use this prompt when RNAFlow execution fails.
    """
    return f"""My RNAFlow pipeline failed. The log file is located at "{log_path}".

Please help me debug by:
1. Reading the last 50 lines of the log file to identify the specific rule that failed.
2. Checking if there are any common issues like "Command not found" or "Out of memory".
3. Using `validate_config_tool` to ensure my config.yaml is still valid.
4. Suggesting a fix or explaining the error message in simple terms.
"""


@mcp.prompt()
def analyze_data_directory(directory_path: str) -> str:
    """
    针对特定数据目录的快速分析引导词。
    """
    return f"""请对目录 "{directory_path}" 下的数据进行分析准备。

你的任务流水线：
1. 立即调用 `scan_samples_tool` 扫描该目录。
2. 按照规范生成样本表：
   - 列：sample, sample_name, group。
   - 智能提取 ID 缩写（例：`L1MLA1700058-PI_L18_1` -> `PI_L18_1`）。
   - 分组逻辑：QC 模式默认用 `sample_name`；若有配对信息或 DEG 需求，请根据实际情况设置 group。
3. 自动生成 `config.yaml` 和 `contrasts.csv`。
4. **汇报并等待确认**：列出配置详情，告知我你已准备好，并等待我的手动确认指令后再开始 `run_rnaflow`。
"""


@mcp.prompt()
def quick_qc_analysis(project_root: str, genome_version: str, species: str) -> str:
    """
    Quick start for QC-only analysis with minimal parameters

    Use this for quick quality control setup.
    """
    return f"""I want to run a QC-only RNA-seq analysis.

Project Details:
- Project root directory: {project_root}
- Genome version: {genome_version}
- Species: {species}

Please follow these steps:
1. First, use `run_simple_qc_analysis_tool` with the above parameters to set everything up
2. Check if FASTQ files are found in 00.raw_data/
3. Help me create the samples.csv file based on the FASTQ files found
4. Then run the analysis with `run_rnaflow_tool`
"""


@mcp.prompt()
def prepare_publication_report() -> str:
    """
    Guide AI to summarize results for a report or publication

    Use this after completing RNAFlow analysis.
    """
    return """I have finished my RNA-seq analysis. Please help me summarize results for a report.

Please:
1. Guide me to find the key QC metrics (e.g., TSS enrichment, FRiP scores).
2. Look for the peak calling results in the output directory.
3. Help me describe the differential analysis (DEG) results if they were performed.
4. Provide a structure for the "Methods" section of my paper based on current RNAFlow workflow.
"""


# ========== Entry Point ==========


def _print_startup_info():
    """Print server startup information"""
    logger.info("=" * 60)
    logger.info("RNAFlow MCP Server v0.2.0 (Optimized)")
    logger.info("=" * 60)
    logger.info(f"RNAFlow Root: {RNAFLOW_ROOT}")
    logger.info(f"配置文件: {MCP_CONFIG_FILE}")
    logger.info(f"Conda路径: {MCP_PATHS.get('conda_path')}")
    logger.info(f"Snakemake路径: {MCP_PATHS.get('snakemake_path')}")
    logger.info(f"数据库路径: {get_db_path()}")
    logger.info("=" * 60)


if __name__ == "__main__":
    _print_startup_info()

    try:
        mcp.run()
    except KeyboardInterrupt:
        logger.info("服务器被用户中断")
    except Exception as e:
        logger.error(f"服务器运行异常: {str(e)}", exc_info=True)
        sys.exit(1)
