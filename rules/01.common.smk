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
from pathlib import Path
from typing import Dict, Union, List, Callable
from rich import print as rich_print
from utils.datadeliver import qc_clean,mapping,count,Deg,call_variant,noval_Transcripts,rmats

# Import logger for consistent logging
from snakemake_logger_plugin_rich_loguru import get_analysis_logger
logger = get_analysis_logger()

# Flag to track if the QC warning has already been displayed
_qc_warning_logged = False

def DataDeliver(config: Dict = None, samples: Dict = None, all_contrasts: Dict = None) -> List[str]:
    """
    Main data delivery orchestrator function that determines which analysis modules
    to execute based on the pipeline configuration and returns the list of expected
    output files.

    This function serves as the central hub for the RNA-seq analysis workflow,
    dynamically enabling/disabling analysis modules based on user configuration.

    Args:
        config (Dict): Pipeline configuration dictionary containing module flags
        samples (Dict): Dictionary of sample information from sample sheet
        all_contrasts (Dict): Dictionary of differential expression contrasts

    Returns:
        List[str]: List of expected output file paths that will be generated
                  by the enabled analysis modules.

    Configuration Options:
        - only_qc: When True, runs only QC, mapping, and counting modules
        - print_target: When True, prints the target file list using Rich
        - Individual module flags: qc_clean, mapping, count, DEG, call_variant,
          noval_Transcripts, rmats (set to True to enable each module)
    """
    # Initialize data deliver - short-read raw-data QC result
    data_deliver = [
        "01.qc/md5_check.tsv",
        os.path.join('00.raw_data', config['convert_md5']),
        os.path.join('00.raw_data', config['convert_md5'], "raw_data_md5.json")
    ]

    # Define module functions and their default behavior
    def execute_qc_clean(samples, data_deliver):
        return qc_clean(samples, data_deliver)

    def execute_mapping(samples, data_deliver):
        return mapping(samples, data_deliver, config)

    def execute_count(samples, data_deliver):
        return count(samples, data_deliver)

    def execute_deg(samples, data_deliver):
        return Deg(samples, data_deliver)

    def execute_call_variant(samples, data_deliver):
        return call_variant(samples, data_deliver)

    def execute_novel_transcripts(samples, data_deliver):
        return noval_Transcripts(samples, data_deliver)

    def execute_rmats(samples, data_deliver, all_contrasts):
        # Assuming ALL_CONTRASTS is available in the config or global scope
        all_contrasts = config.get('all_contrasts', []) if config else []
        return rmats(samples, data_deliver, all_contrasts)

    module_functions: Dict[str, Callable] = {
        'qc_clean': execute_qc_clean,
        'mapping': execute_mapping,
        'count': execute_count,
        'DEG': execute_deg,
        'call_variant': execute_call_variant,
        'noval_Transcripts': execute_novel_transcripts,
        'rmats': execute_rmats
    }

    # Default behavior for modules (execute only if explicitly enabled in config)
    default_config = {module: False for module in module_functions}
    config = {**default_config, **(config or {})}

    # Special case: If `only_qc` is True, enable `qc_clean`, `mapping`, and `count`, disable others
    global _qc_warning_logged
    if config.get('only_qc'):
        if not _qc_warning_logged:
            logger.warning(' 🦉🦉 \033[33m ONLY RUN QC ANALYSIS FOR RNA-SEQ : RAW DATA QC & MAPPING & COUNT \033[0m🐝🐝 ')
            _qc_warning_logged = True
        for module in module_functions:
            if module in ['qc_clean', 'mapping', 'count']:
                config[module] = True
            else:
                config[module] = False

    # Execute modules based on config
    for module, func in module_functions.items():
        if config.get(module, False):  # Only execute if the module is enabled in config
            if module == "rmats":
                data_deliver = func(samples, data_deliver, all_contrasts)
            else:
                data_deliver = func(samples, data_deliver)
    # Print target if required
    if config.get('print_target'):
        rich_print(data_deliver)
    return data_deliver

def ReportData(config: dict = None) -> List[str]:
    """
    Collects all files required for generating the final Quarto RNA-seq analysis report.

    This function returns the list of manifest files, summary JSON, and HTML report
    that are needed for the final delivery and reporting stage of the pipeline.

    Args:
        config (dict): Pipeline configuration dictionary

    Returns:
        List[str]: List of report-related file paths, or empty list if reporting
                   is disabled in configuration.
    """
    if config.get('report'):
        return [
                os.path.join(config['data_deliver'],'delivery_manifest.json'),
                os.path.join(config['data_deliver'],'delivery_manifest.md5'),
                os.path.join(config['data_deliver'],'delivery_details.log'),
                os.path.join(config['data_deliver'],'report_data/project_summary.json'),
                os.path.join(config['data_deliver'],'report_data','delivery_manifest.json'),
                os.path.join(config['data_deliver'],'report_data','delivery_manifest.md5'),
                os.path.join(config['data_deliver'],'report_data','delivery_details.log'),
                os.path.join(config['data_deliver'], "Analysis_Report/index.html")
                ]
    else:
        return []

def get_sample_data_dir(sample_id: str = None, config: dict = None) -> str:
    """
    Resolves the directory path containing FASTQ files for a given sample ID.

    This function handles two common directory structures:
    1. Sample-specific subdirectories: raw_data/SampleID/
    2. Flat directory structure: raw_data/SampleID_R1.fq.gz

    The function uses fuzzy matching with glob patterns to handle various
    naming conventions and file extensions.

    Args:
        sample_id (str): The sample identifier to search for
        config (dict): Pipeline configuration with 'raw_data_path' key

    Returns:
        str: Absolute path to the directory containing the sample's FASTQ files

    Raises:
        ValueError: If 'raw_data_path' is missing from config
        FileNotFoundError: If no matching files or directories are found
    """

    # Ensure config has this key to prevent errors
    if "raw_data_path" not in config:
        raise ValueError("Config dictionary missing 'raw_data_path' key.")

    # Iterate through all raw data paths in the config
    for base_dir in config["raw_data_path"]:

        # --- Case A: Your previous logic (raw_data/SampleID/xxx.fq) ---
        sample_subdir = os.path.join(base_dir, sample_id)
        if os.path.isdir(sample_subdir):
            return sample_subdir

        # --- Case B: Your current ls result (raw_data/SampleID.R1.fq) ---
        # Use glob fuzzy matching: check if there are files starting with sample_id in the directory
        # pattern similar to: /data/.../00.raw_data/L1MKK1806607-a1*
        pattern = os.path.join(base_dir, f"{sample_id}*")

        # Get the list of matching files
        matching_files = glob.glob(pattern)

        # If matching files are found (and they are files not directories), it means data is at the base_dir level
        if matching_files:
            # Simple filter: ensure they are files (to avoid having a folder named SampleID_tmp by coincidence)
            # As long as one is a file, we consider it found
            if any(os.path.isfile(f) for f in matching_files):
                return base_dir

    # If the loop ends without finding anything
    raise FileNotFoundError(f"Could not find data directory or files for {sample_id} in {config['raw_data_path']}")

def get_all_input_dirs(sample_keys: str = None,
                       config: dict = config) -> list:
    """
    Aggregates unique input directories for all specified samples.

    This function iterates through all sample IDs and resolves their data
    directories using get_sample_data_dir(), then returns a deduplicated list.

    Args:
        sample_keys (str): Iterable of sample identifiers
        config (dict): Pipeline configuration dictionary

    Returns:
        list: Deduplicated list of input directories containing sample data
    """
    dir_list = []
    for sample_id in sample_keys:
        dir_list.append(get_sample_data_dir(sample_id, config = config))

    return list(set(dir_list))

def judge_bwa_index(config: dict = None) -> bool:
    """
    Validates BWA-MEM2 index completeness by checking for required index files.

    BWA-MEM2 requires specific index files to be present for proper alignment.
    This function checks if all necessary files exist and returns True if
    the index needs to be rebuilt.

    Args:
        config (dict): Pipeline configuration with 'bwa_mem2' section

    Returns:
        bool: True if index files are missing (needs rebuild), False if complete
    """
    bwa_index = config['bwa_mem2']['index']
    bwa_index_files = [bwa_index + suffix for suffix in ['.0123', '.amb', '.ann', '.bwt.2bit.64', '.pac', '.alt']]

    return not all(os.path.exists(f) for f in bwa_index_files)

def judge_star_index(config: dict, Genome_Version: str) -> bool:
    """
    Validates STAR index completeness by checking for required index files.

    STAR aligner requires a comprehensive set of index files generated during
    the indexing process. This function verifies that all necessary files are
    present and returns True if the index needs to be rebuilt.

    Args:
        config (dict): Pipeline configuration with 'STAR_index' section
        Genome_Version (str): Specific genome version to validate

    Returns:
        bool: True if index files are missing (needs rebuild), False if complete

    Raises:
        KeyError: If the specified genome version is not found in configuration
    """

    try:
        star_config = config['STAR_index'][Genome_Version]
        index_dir = star_config['index']
    except KeyError:
        print(f"Error: Genome Version '{Genome_Version}' not found in config or structure incorrect.")
        sys.exit(1)

    if not os.path.isdir(index_dir):
        return True

    required_files = [
        "chrLength.txt",
        "exonGeTrInfo.tab",
        "genomeParameters.txt",
        "sjdbInfo.txt",
        "chrNameLength.txt",
        "exonInfo.tab",
        "Log.out",
        "sjdbList.fromGTF.out.tab",
        "chrName.txt",
        "geneInfo.tab",
        "SA",
        "sjdbList.out.tab",
        "chrStart.txt",
       " Genome",
        "SAindex",
        "transcriptInfo.tab"
    ]

    full_paths = [os.path.join(index_dir, f) for f in required_files]

    missing_files = [f for f in full_paths if not os.path.exists(f)]

    if missing_files:
        return True

    return False

def check_gene_version(config: dict = None, logger = None) -> None:
    """
    Validates that the configured genome version is supported by the pipeline.

    This function ensures that the user-specified genome version matches one of
    the allowed versions defined in the pipeline configuration, preventing
    runtime errors due to unsupported reference genomes.

    Args:
        config (dict): Pipeline configuration with 'Genome_Version' and
                      'can_use_genome_version' keys
        logger: Optional logger instance (falls back to unified logger if None)

    Raises:
        ValueError: If the genome version is not in the allowed list
        KeyError: If required configuration keys are missing
        TypeError: If config is not a valid dictionary
    """
    # Use the provided logger or get the unified logger
    if logger is None:
        from snakemake_logger_plugin_rich_loguru import get_analysis_logger
        logger = get_analysis_logger()

    try:
        version = config['Genome_Version']
        allowed = config['can_use_genome_version']

        if version not in allowed:
            logger.error(f"Version mismatch! '{version}' is not in {allowed}")
            raise ValueError(f"Unsupported genome version: {version}")

        logger.info(f"Config check passed: Genome_Version '{version}' is supported.")

    except KeyError as e:
        logger.error(f"Config structure error: Missing key {e}")
        raise
    except TypeError:
        logger.error("Config must be a valid dictionary.")
        raise
# --------------------- #