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

from utils.common import (
    AnalysisTargets,
    DataDeliver,
    ReportData,
    get_sample_data_dir,
    get_all_input_dirs,
    judge_bwa_index,
    judge_star_index,
    check_gene_version,
    get_docker_image,
)

try:
    from snakemake_logger_plugin_rich_loguru import get_analysis_logger
    logger = get_analysis_logger()
except ImportError:
    try:
        from loguru import logger
    except ImportError:
        import logging
        logging.basicConfig(level=logging.INFO)
        logger = logging.getLogger("Fallback")

# ---------------------
