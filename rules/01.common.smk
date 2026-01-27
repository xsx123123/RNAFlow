#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# loading packages
import os
import glob
from pathlib import Path
from typing import Dict, Union, List, Callable
from rich import print as rich_print
from utils.datadeliver import qc_clean,mapping,count,Deg,call_variant,noval_Transcripts,rmats

# Target rule function
def DataDeliver(config: Dict = None, samples: Dict = None, logger) -> List[str]:
    """
    This function performs Bioinformation analysis on the input configuration
    and returns a list of results.
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

    def execute_rmats(samples, data_deliver):
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
    if config.get('only_qc'):
        logger.info('ONLY RUN QC ANALYSIS FOR RNA-SEQ : RAW DATA QC & MAPPING & COUNT')
        for module in module_functions:
            if module in ['qc_clean', 'mapping', 'count']:
                config[module] = True
            else:
                config[module] = False

    # Execute modules based on config
    for module, func in module_functions.items():
        if config[module]:
            data_deliver = func(samples, data_deliver)

    # Print target if required
    if config.get('print_target'):
        rich_print(data_deliver)
    return data_deliver

def get_sample_data_dir(sample_id: str = None, config: dict = None) -> str:
    """
    Find the directory containing fastq files based on sample_id.

    Logic update:
    1. First check if a subdirectory named with sample_id exists.
    2. If the subdirectory doesn't exist, check if there are files starting with sample_id in the directory.
       If files exist, return the base_dir.
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

def get_all_input_dirs(sample_keys:str = None,
                       config:dict = config) -> list:
    """
    Iterate through all sample IDs, call get_sample_data_dir,
    and return a list containing all data directories.
    """
    dir_list = []
    for sample_id in sample_keys:
        dir_list.append(get_sample_data_dir(sample_id,config = config))

    return list(set(dir_list))

def judge_bwa_index(config:dict = None) -> bool:
    """
    Determine whether to rebuild the bwa index
    """
    bwa_index = config['bwa_mem2']['index']
    bwa_index_files = [bwa_index + suffix for suffix in ['.0123', '.amb', '.ann', '.bwt.2bit.64', '.pac', '.alt']]

    return not all(os.path.exists(f) for f in bwa_index_files)

def judge_star_index(config: dict, Genome_Version: str) -> bool:
    """
    Determine whether to rebuild the STAR index
    Returns:
        True: Files are missing, need to build
        False: Files are complete, no need to build
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
    Check if the gene version in config matches allowed list.
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