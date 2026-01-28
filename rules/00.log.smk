#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RNAFlow Pipeline - Logging and Runtime Information Module

This module handles the initialization of the logging system and captures
essential runtime information at the start of the RNA-seq analysis pipeline.

Key Responsibilities:
- Initialize the unified Rich/Loguru logger
- Log system and environment details
- Capture pipeline configuration parameters
- Provide comprehensive audit trail for reproducibility

The logging is currently commented out to avoid excessive output during
normal pipeline execution, but can be enabled for debugging purposes.
"""

import sys
import os
import platform
from datetime import datetime

try:
    # 1. 优先尝试导入你写的 Snakemake 自定义插件
    from snakemake_logger_plugin_rich_loguru import get_analysis_logger
    logger = get_analysis_logger()
    logger_type = "Custom Plugin"

except ImportError:
    try:
        from loguru import logger
        logger_type = "Standard Loguru"
        logger.warning("Custom logger plugin not found. Falling back to standard loguru.")
        
    except ImportError:
        import logging 
        logging.basicConfig(level=logging.INFO)
        logger = logging.getLogger("Fallback")
        logger.warning("Neither custom plugin nor loguru found. Using built-in logging.")
        logger_type = "Built-in Logging"

# Log essential runtime information at the start
# logger.info("[bold blue]RNAFlow Pipeline Started[/bold blue]")
# logger.info(f"Start Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
# logger.info(f"System: {platform.system()} {platform.release()}")
# logger.info(f"Python Version: {platform.python_version()}")

# Snakemake version
# try:
#     import snakemake
#     logger.info(f"Snakemake Version: {snakemake.__version__}")
# except ImportError:
#     logger.info("Snakemake Version: unknown")

# logger.info(f"Working Directory: {os.getcwd()}")

# Log key configuration parameters
# logger.info("Pipeline Configuration:")
# logger.info(f"  Project: {config.get('project_name', 'N/A')}")
# logger.info(f"  Workflow Dir: {config.get('workflow', 'N/A')}")
# logger.info(f"  Sample CSV: {config.get('sample_csv', 'N/A')}")
# logger.info(f"  Reference: {config.get('Genome_Version', 'N/A')}")

# logger.info("-" * 60)
# logger.info("Runtime information captured.")
# logger.info("-" * 60)