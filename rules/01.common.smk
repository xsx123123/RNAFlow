#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RNAFlow Pipeline - Common Utility Functions Module

This module provides essential utility functions that are used across multiple
rules in the RNA-seq analysis pipeline. It handles core functionality including:

Key Components:
- Data delivery orchestration (DataDeliver function)
- Report data collection (ReportData function)
- Sample data directory resolution
- Reference index validation (BWA, STAR)
- Genome version compatibility checking

These functions ensure consistent behavior across the pipeline and provide
robust error handling for common scenarios like missing files, invalid
configurations, and path resolution issues.
"""

import os
import glob
import sys
import time
from pathlib import Path
from typing import Dict, Union, List, Callable
from rich import print as rich_print
from utils.datadeliver import qc_clean,mapping,count,Deg,call_variant,detect_novel_transcripts,rmats,gene_fusion


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

# Import logger for consistent logging
from snakemake_logger_plugin_rich_loguru import get_analysis_logger
logger = get_analysis_logger()

# Flag to track if the QC warning has already been displayed
_qc_warning_logged = False

from utils.common import (
    DataDeliver, ReportData, get_sample_data_dir, 
    get_all_input_dirs, judge_bwa_index, 
    judge_star_index, check_gene_version
)

# --------------------- #