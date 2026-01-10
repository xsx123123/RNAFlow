#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys
import os
import platform
from datetime import datetime

# Import the unified logger from the plugin
from snakemake_logger_plugin_rich_loguru import get_analysis_logger

# Get the logger instance
logger = get_analysis_logger()

# Log essential runtime information at the start
logger.info("[bold blue]RNAFlow Pipeline Started[/bold blue]")
logger.info(f"Start Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
logger.info(f"System: {platform.system()} {platform.release()}")
logger.info(f"Python Version: {platform.python_version()}")

# Snakemake version
try:
    import snakemake
    logger.info(f"Snakemake Version: {snakemake.__version__}")
except ImportError:
    logger.info("Snakemake Version: unknown")

logger.info(f"Working Directory: {os.getcwd()}")

# Log key configuration parameters
logger.info("Pipeline Configuration:")
logger.info(f"  Project: {config.get('project_name', 'N/A')}")
logger.info(f"  Workflow Dir: {config.get('workflow', 'N/A')}")
logger.info(f"  Sample CSV: {config.get('sample_csv', 'N/A')}")
logger.info(f"  Reference: {config.get('Genome_Version', 'N/A')}")

logger.info("-" * 60)
logger.info("Runtime information captured.")
logger.info("-" * 60)