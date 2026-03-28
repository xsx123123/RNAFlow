#!/usr/bin/env python3
"""
Legacy Dispatcher - unified routing for backward-compatible tool names
Reduces tool count from 40+ to ~20 by consolidating legacy tools
"""

import asyncio
import inspect
from typing import Any, Dict

from core.logger import logger


# Legacy tool name to current handler mapping
LEGACY_MAP = {
    "rnaflowRunRnaflow": "run_rnaflow_tool",
    "rnaflowCheckSnakemakeStatusTool": "check_snakemake_status_tool",
    "rnaflowCheckSystemResourcesTool": "check_system_resources_tool",
    "rnaflowCheckCondaEnvironmentTool": "check_conda_environment_tool",
    "rnaflowListRunsTool": "list_runs_tool",
    "rnaflowGetRunDetailsTool": "get_run_details_tool",
    "rnaflowGetRunStatisticsTool": "get_run_statistics_tool",
    "rnaflowCheckProjectNameConflictTool": "check_project_name_conflict_tool",
    "rnaflowGetSnakemakeLogTool": "get_snakemake_log_tool",
    "rnaflowListSupportedGenomesTool": "list_supported_genomes_tool",
    "rnaflowGetConfigTemplateTool": "get_config_template_tool",
    "rnaflowCreateProjectStructureTool": "create_project_structure_tool",
    "rnaflowGenerateConfigFileTool": "generate_config_file_tool",
    "rnaflowCreateSampleCsvTool": "create_sample_csv_tool",
    "rnaflowCreateContrastsCsvTool": "create_contrasts_csv_tool",
    "rnaflowValidateConfigTool": "validate_config_tool",
    "rnaflowGetProjectStructureTool": "get_project_structure_tool",
    "rnaflowSetupCompleteProjectTool": "setup_complete_project_tool",
    "rnaflowRunSimpleQcAnalysisTool": "run_simple_qc_analysis_tool",
}


async def legacy_dispatcher(
    tool_name: str, params: Dict[str, Any], handler_globals: Dict[str, Any]
) -> Any:
    """
    Route legacy tool names to current implementations

    Args:
        tool_name: Legacy tool name (e.g., "rnaflowRunRnaflow")
        params: Parameters to pass to the handler
        handler_globals: Global namespace to find handlers in

    Returns:
        Handler function result

    Raises:
        ValueError: If tool_name not in LEGACY_MAP
    """
    handler_name = LEGACY_MAP.get(tool_name)

    if not handler_name:
        logger.warning(f"Unknown legacy tool requested: {tool_name}")
        return {"error": f"Unknown legacy tool: {tool_name}"}

    handler = handler_globals.get(handler_name)
    if not handler:
        logger.error(f"Handler not found for {tool_name} -> {handler_name}")
        return {"error": f"Handler not found: {handler_name}"}

    logger.info(f"[Legacy Dispatcher] Routing {tool_name} -> {handler_name}")

    # Handle sync/async automatically
    if inspect.iscoroutinefunction(handler):
        return await handler(**params)
    else:
        return handler(**params)
