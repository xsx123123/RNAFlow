#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys
import os
import platform
from loguru import logger
from datetime import datetime

# Create log directory if it doesn't exist
log_dir = "logs"
os.makedirs(log_dir, exist_ok=True)

# Generate log file name with valid format (no colons in timestamp)
log_file_name = f"{log_dir}/{config.get('project_name', 'RNAFlow')}_runtime_{datetime.now().strftime('%Y-%m-%d_%H-%M-%S')}.log"

# ------------ loguru logger config ---------------- #
# remove default logger handler
logger.remove()

# Add file logger with clean, simple format
#logger.add(
#    log_file_name,
#    rotation="500 MB",
#    format="{time:YYYY-MM-DD HH:mm:ss} | {level: <8} | {message}",
#    level=config.get("log_level", "INFO"),
#    colorize=False,  # Disable colorization for file logs
#    backtrace=True,
#    diagnose=True
#)

# Add stderr logger with same clean format but with colors for console
# logger.add(
#    sys.stderr,
#    format="{time:YYYY-MM-DD HH:mm:ss} | {level: <8} | {message}",
#    level=config.get("log_level", "INFO"),
#    colorize=True,
#    backtrace=True,
#    diagnose=True
#)

# Log essential runtime information at the start
logger.info("RNAFlow Pipeline Started")
logger.info(f"Start Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
logger.info(f"System: {platform.system()} {platform.release()}")
logger.info(f"Python Version: {platform.python_version()}")

# Snakemake version
try:
    import snakemake
    logger.info(f"Snakemake Version: {snakemake.__version__}")
except ImportError:
    logger.info("Snakemake Version: unknown")

logger.info(f"Log File: {log_file_name}")
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

# logger example usage
# logger.info("This is an info message.")
# logger.debug("This is a debug message.")
# logger.warning("This is a warning message.")
# logger.error("This is an error message.")
# logger.success("This is a success message.")
# ------------ loguru logger config ---------------- #