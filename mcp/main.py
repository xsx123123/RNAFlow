#!/usr/bin/env python3
"""
RNAFlow MCP Server - Main Entry Point
Core entry: only FastMCP instance initialization, tool/resource registration
"""

import sys
from pathlib import Path
from typing import Optional, List, Dict, Any

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

# Database initialization
from db.database import init_database

DB_PATH = init_database()

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

# Initialize MCP server
mcp = FastMCP("RNAFlow")


# ========== Tools Registration ==========


@mcp.tool()
def list_supported_genomes_tool() -> List[Dict[str, str]]:
    """List all supported genome versions in RNAFlow"""
    return list_supported_genomes()


@mcp.tool()
def get_config_template_tool(template_type: str = "standard") -> str:
    """Get a complete RNAFlow configuration template"""
    return get_config_template(template_type)


@mcp.tool()
def create_project_structure_tool(project_root: str) -> Dict[str, Any]:
    """Create standard RNAFlow project directory structure"""
    return create_project_structure(project_root)


@mcp.tool()
def generate_config_file_tool(config: ProjectConfig, output_path: str) -> str:
    """Generate RNAFlow config.yaml using ProjectConfig model"""
    return generate_config_file(config, output_path)


@mcp.tool()
def create_sample_csv_tool(sample_data: List[Dict[str, str]], output_path: str) -> str:
    """Create samples.csv file"""
    return create_sample_csv(sample_data, output_path)


@mcp.tool()
def create_contrasts_csv_tool(contrasts: List[Dict[str, str]], output_path: str) -> str:
    """Create contrasts.csv file"""
    return create_contrasts_csv(contrasts, output_path)


@mcp.tool()
def validate_config_tool(config_path: str) -> Dict[str, Any]:
    """Validate RNAFlow configuration file"""
    return validate_config(config_path)


@mcp.tool()
def get_project_structure_tool() -> Dict[str, Any]:
    """Get standard RNAFlow project structure"""
    return get_project_structure()


@mcp.tool()
def setup_complete_project_tool(
    project_root: str,
    project_name: str,
    genome_version: str,
    species: str,
    analysis_mode: str = "standard",
    client: str = "Research_Lab",
    library_types: str = "fr-firststrand",
) -> Dict[str, Any]:
    """One-stop setup for complete RNAFlow project"""
    return setup_complete_project(
        project_root,
        project_name,
        genome_version,
        species,
        analysis_mode,
        client,
        library_types,
    )


@mcp.tool()
def run_simple_qc_analysis_tool(
    project_root: str,
    genome_version: str,
    species: str,
    project_name: Optional[str] = None,
) -> Dict[str, Any]:
    """Simple one-click QC analysis"""
    return run_simple_qc_analysis(project_root, genome_version, species, project_name)


@mcp.tool()
async def run_rnaflow_tool(
    config_path: str,
    cores: int = 20,
    dry_run: bool = False,
    skip_resource_check: bool = False,
    user_confirmed: bool = False,
) -> str:
    """Run RNAFlow pipeline (Asynchronous / Detached)"""
    return await run_rnaflow(
        config_path, cores, dry_run, skip_resource_check, user_confirmed
    )


@mcp.tool()
def check_conda_environment_tool(env_name: Optional[str] = None) -> Dict[str, Any]:
    """Check if required conda environment exists and is valid"""
    return check_conda_environment(env_name)


@mcp.tool()
def check_system_resources_tool() -> Dict[str, Any]:
    """Check system resources including CPU, memory, and disk usage"""
    return check_system_resources()


@mcp.tool()
def list_runs_tool(
    project_name: str = None, status: str = None, limit: int = 50
) -> List[Dict[str, Any]]:
    """List RNAFlow project run records"""
    return list_runs(project_name, status, limit)


@mcp.tool()
def get_run_details_tool(run_id: str) -> Dict[str, Any]:
    """Get details for a specific run"""
    return get_run_details(run_id)


@mcp.tool()
def get_run_statistics_tool(
    start_date: str = None, end_date: str = None
) -> Dict[str, Any]:
    """Get run statistics for a period"""
    return get_run_statistics(start_date, end_date)


@mcp.tool()
def check_project_name_conflict_tool(project_name: str) -> Dict[str, Any]:
    """Check if project name already exists"""
    return check_project_name_conflict(project_name)


@mcp.tool()
def check_snakemake_status_tool(run_id: str = None) -> Dict[str, Any]:
    """Check Snakemake run status"""
    return check_snakemake_status(run_id)


@mcp.tool()
def get_snakemake_log_tool(run_id: str, lines: int = 50) -> Dict[str, Any]:
    """Get Snakemake run log"""
    return get_snakemake_log(run_id, lines)


# ========== Backward Compatibility Tools ==========


@mcp.tool(name="createProjectStructure")
def create_project_structure_backward(project_root: str) -> Dict[str, Any]:
    """Backward compatibility alias"""
    return create_project_structure(project_root)


@mcp.tool(name="setupCompleteProject")
def setup_complete_project_backward(
    project_root: str,
    project_name: str,
    genome_version: str,
    species: str,
    analysis_mode: str = "standard",
    client: str = "Research_Lab",
    library_types: str = "fr-firststrand",
) -> Dict[str, Any]:
    """Backward compatibility alias"""
    return setup_complete_project(
        project_root,
        project_name,
        genome_version,
        species,
        analysis_mode,
        client,
        library_types,
    )


@mcp.tool(name="rnaflowGenerateConfigFile")
def rnaflow_generate_config_file_old(config: dict, output_path: str) -> str:
    """Backward compatibility: accepts old-style config dict"""
    logger.info("使用向后兼容的 rnaflowGenerateConfigFile (旧格式)")
    try:
        mapped_config = {
            "project_name": config.get("project_name", "unknown_project"),
            "Genome_Version": config.get(
                "genome_version", config.get("Genome_Version", "unknown")
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
    """Backward compatibility alias"""
    result = validate_config(config_path)
    return {
        "valid": result.get("valid", False),
        "error": "; ".join(result.get("errors", [])) if result.get("errors") else None,
    }


@mcp.tool(name="rnaflowRunRnaflow")
def rnaflow_run_rnaflow_old(
    config_path: str,
    cores: int = 20,
    dry_run: bool = False,
    skip_resource_check: bool = False,
) -> str:
    """Backward compatibility alias"""
    return run_rnaflow(config_path, cores, dry_run, skip_resource_check)


@mcp.tool(name="rnaflowCheckSnakemakeStatusTool")
def rnaflow_check_snakemake_status_tool(run_id: str = None) -> Dict[str, Any]:
    """Backward compatibility alias"""
    return check_snakemake_status(run_id)


@mcp.tool(name="rnaflowCheckSystemResourcesTool")
def rnaflow_check_system_resources_tool() -> Dict[str, Any]:
    """Backward compatibility alias"""
    return check_system_resources()


@mcp.tool(name="rnaflowCheckCondaEnvironmentTool")
def rnaflow_check_conda_environment_tool(
    env_name: Optional[str] = None,
) -> Dict[str, Any]:
    """Backward compatibility alias"""
    return check_conda_environment(env_name)


@mcp.tool(name="rnaflowListRunsTool")
def rnaflow_list_runs_tool(
    project_name: str = None, status: str = None, limit: int = 50
) -> List[Dict[str, Any]]:
    """Backward compatibility alias"""
    return list_runs(project_name, status, limit)


@mcp.tool(name="rnaflowGetRunDetailsTool")
def rnaflow_get_run_details_tool(run_id: str) -> Dict[str, Any]:
    """Backward compatibility alias"""
    return get_run_details(run_id)


@mcp.tool(name="rnaflowGetRunStatisticsTool")
def rnaflow_get_run_statistics_tool(
    start_date: str = None, end_date: str = None
) -> Dict[str, Any]:
    """Backward compatibility alias"""
    return get_run_statistics(start_date, end_date)


@mcp.tool(name="rnaflowCheckProjectNameConflictTool")
def rnaflow_check_project_name_conflict_tool(project_name: str) -> Dict[str, Any]:
    """Backward compatibility alias"""
    return check_project_name_conflict(project_name)


@mcp.tool(name="rnaflowGetSnakemakeLogTool")
def rnaflow_get_snakemake_log_tool(run_id: str, lines: int = 50) -> Dict[str, Any]:
    """Backward compatibility alias"""
    return get_snakemake_log(run_id, lines)


@mcp.tool(name="rnaflowListSupportedGenomesTool")
def rnaflow_list_supported_genomes_tool() -> List[Dict[str, str]]:
    """Backward compatibility alias"""
    return list_supported_genomes()


@mcp.tool(name="rnaflowGetConfigTemplateTool")
def rnaflow_get_config_template_tool(template_type: str = "standard") -> str:
    """Backward compatibility alias"""
    return get_config_template(template_type)


@mcp.tool(name="rnaflowCreateProjectStructureTool")
def rnaflow_create_project_structure_tool(project_root: str) -> Dict[str, Any]:
    """Backward compatibility alias"""
    return create_project_structure(project_root)


@mcp.tool(name="rnaflowGenerateConfigFileTool")
def rnaflow_generate_config_file_tool(config: ProjectConfig, output_path: str) -> str:
    """Backward compatibility alias"""
    return generate_config_file(config, output_path)


@mcp.tool(name="rnaflowCreateSampleCsvTool")
def rnaflow_create_sample_csv_tool(
    sample_data: List[Dict[str, str]], output_path: str
) -> str:
    """Backward compatibility alias"""
    return create_sample_csv(sample_data, output_path)


@mcp.tool(name="rnaflowCreateContrastsCsvTool")
def rnaflow_create_contrasts_csv_tool(
    contrasts: List[Dict[str, str]], output_path: str
) -> str:
    """Backward compatibility alias"""
    return create_contrasts_csv(contrasts, output_path)


@mcp.tool(name="rnaflowValidateConfigTool")
def rnaflow_validate_config_tool(config_path: str) -> Dict[str, Any]:
    """Backward compatibility alias"""
    return validate_config(config_path)


@mcp.tool(name="rnaflowGetProjectStructureTool")
def rnaflow_get_project_structure_tool() -> Dict[str, Any]:
    """Backward compatibility alias"""
    return get_project_structure()


@mcp.tool(name="rnaflowSetupCompleteProjectTool")
def rnaflow_setup_complete_project_tool(
    project_root: str,
    project_name: str,
    genome_version: str,
    species: str,
    analysis_mode: str = "standard",
    client: str = "Research_Lab",
    library_types: str = "fr-firststrand",
) -> Dict[str, Any]:
    """Backward compatibility alias"""
    return setup_complete_project(
        project_root,
        project_name,
        genome_version,
        species,
        analysis_mode,
        client,
        library_types,
    )


@mcp.tool(name="rnaflowRunSimpleQcAnalysisTool")
def rnaflow_run_simple_qc_analysis_tool(
    project_root: str,
    genome_version: str,
    species: str,
    project_name: Optional[str] = None,
) -> Dict[str, Any]:
    """Backward compatibility alias"""
    return run_simple_qc_analysis(project_root, genome_version, species, project_name)


# ========== Resources ==========


@mcp.resource("rnaflow://config-templates/complete")
def get_complete_config_template() -> str:
    template_file = EXAMPLES_DIR / "config_complete.yaml"
    if template_file.exists():
        with open(template_file, "r", encoding="utf-8") as f:
            return f.read()
    return "Template not found"


@mcp.resource("rnaflow://config-templates/standard")
def get_standard_config_template() -> str:
    template_file = EXAMPLES_DIR / "config_standard_deg.yaml"
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


# ========== Prompts ==========


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
def quick_qc_analysis(project_root: str, genome_version: str, species: str) -> str:
    """Quick start for QC-only analysis with minimal parameters"""
    return f"""I want to run a QC-only RNA-seq analysis.

Project Details:
- Project root directory: {project_root}
- Genome version: {genome_version}
- Species: {species}

Please follow these steps:
1. First, use `run_simple_qc_analysis` with the above parameters to set everything up
2. Check if FASTQ files are found in 00.raw_data/
3. Help me create the samples.csv file based on the FASTQ files found
4. Then run the analysis with `run_rnaflow`
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
