#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RNAFlow Pipeline - Common Utility Functions Module
"""

import os
import glob
import sys
from pathlib import Path
from typing import Dict, Union, List
from rich import print as rich_print

from utils import datadeliver


MODULE_DEPENDENCIES = {
    "qc_clean": [],
    "mapping": ["qc_clean"],
    "count": ["mapping"],
    "deg": ["count"],
    "call_variant": ["mapping"],
    "detect_novel_transcripts": ["mapping"],
    "rmats": ["mapping"],
    "gene_fusion": ["mapping"],
}

MODULE_COLLECTORS = {
    "qc_clean": datadeliver.qc_clean,
    "mapping": datadeliver.mapping,
    "count": datadeliver.count,
    "deg": datadeliver.deg,
    "call_variant": datadeliver.call_variant,
    "detect_novel_transcripts": datadeliver.detect_novel_transcripts,
    "rmats": datadeliver.rmats,
    "gene_fusion": datadeliver.gene_fusion,
}

def get_docker_image(config:dict = None,
                     image_key:str = None,
                     use_prefix=True) -> str:
    """
    Extracts the full Docker URI from the config using the image key (e.g., 'rnaflow-rsem').
    
    Args:
        image_key (str): The key name of the image, e.g., "rnaflow-rsem".
        use_prefix (bool): Whether to automatically add the "docker://" prefix. 
                           Defaults to True (Snakemake standard).
    """
    try:
        # Extract the URI from the global config dictionary
        uri = config["images"][image_key]["full_image_uri"]
        
        # Format and return the path
        if use_prefix:
            return f"docker://{uri}"
        else:
            return uri
            
    except KeyError:
        # Provide a clear error message to prevent silent workflow crashes due to typos
        raise ValueError(f"\n[Hajimi Error]: Cannot find the image '{image_key}' in the configuration. Please check your spelling or verify the yaml file!\n")


def _resolve_enabled_modules(config: Dict) -> List[str]:
    """Resolve module switches without mutating the global Snakemake config."""
    enabled = {
        module for module in MODULE_DEPENDENCIES
        if config.get(module) is not False
    }

    if config.get("only_qc"):
        return ["qc_clean"] if "qc_clean" in enabled else []

    changed = True
    while changed:
        changed = False
        for module in tuple(enabled):
            for dependency in MODULE_DEPENDENCIES[module]:
                if dependency not in enabled:
                    enabled.add(dependency)
                    changed = True

    return [module for module in MODULE_DEPENDENCIES if module in enabled]


def AnalysisTargets(
    config: Dict = None, samples: Dict = None, all_contrasts: List = None
) -> List[str]:
    """Collect analysis targets for the enabled modules as a pure function."""
    config = config or {}
    samples = samples or {}
    all_contrasts = all_contrasts or []
    convert_md5_path = config.get("convert_md5", "link_dir")
    targets = [
        os.path.join("00.raw_data", convert_md5_path, "raw_data_md5.json"),
        "01.qc/md5_check.tsv",
    ]

    for module in _resolve_enabled_modules(config):
        collector = MODULE_COLLECTORS[module]
        if module == "mapping":
            targets = collector(samples, targets, config)
        elif module == "qc_clean":
            targets = collector(samples, targets, config=config)
        elif module == "rmats":
            targets = collector(samples, targets, all_contrasts)
        else:
            targets = collector(samples, targets)
    return targets


def delivery_outputs(config: Dict) -> List[str]:
    deliver_dir = config["data_deliver"]
    return [
        os.path.join(deliver_dir, "delivery_manifest.json"),
        os.path.join(deliver_dir, "delivery_manifest.md5"),
        os.path.join(deliver_dir, "delivery_details.log"),
    ]


def report_outputs(config: Dict) -> List[str]:
    return [
        os.path.join(config["data_deliver"], "report_data", "delivery_manifest.json"),
        os.path.join(config["data_deliver"], "report_data", "delivery_manifest.md5"),
        os.path.join(config["data_deliver"], "report_data", "delivery_details.log"),
        os.path.join(config["data_deliver"], "report_data", "project_summary.json"),
        os.path.join(config["data_deliver"], "Analysis_Report", "index.html"),
    ]


def DataDeliver(
    config: Dict = None, samples: Dict = None, all_contrasts: List = None
) -> List[str]:
    """Collect analysis, delivery, and report targets exactly once."""
    config = config or {}
    targets = AnalysisTargets(config, samples, all_contrasts)
    deliver_enabled = config.get("deliver", True) is not False
    report_enabled = config.get("report", True) is not False

    if deliver_enabled:
        targets.extend(delivery_outputs(config))
    if report_enabled:
        targets.extend(report_outputs(config))

    if config.get("print_target"):
        rich_print("[bold green]Generated Target Files:[/bold green]")
        rich_print(targets)
    return targets


def ReportData(config: dict = None) -> List[str]:
    """Backward-compatible report target collector."""
    return report_outputs(config or {}) if (config or {}).get("report", True) is not False else []


def get_sample_data_dir(sample_id: str = None, config: dict = None) -> str:
    """Resolves the directory path containing FASTQ files for a given sample ID."""
    if "raw_data_path" not in config:
        raise ValueError("Config dictionary missing 'raw_data_path' key.")

    for base_dir in config["raw_data_path"]:
        sample_subdir = os.path.join(base_dir, sample_id)
        if os.path.isdir(sample_subdir):
            return sample_subdir

        pattern = os.path.join(base_dir, f"{sample_id}*")
        matching_files = glob.glob(pattern)
        if matching_files:
            if any(os.path.isfile(f) for f in matching_files):
                return base_dir

    raise FileNotFoundError(
        f"Could not find data directory or files for {sample_id} in {config['raw_data_path']}"
    )


def get_all_input_dirs(sample_keys: List[str] = None, config: dict = None) -> list:
    """Aggregates unique input directories for all specified samples."""
    dir_list = []
    for sample_id in sample_keys:
        dir_list.append(get_sample_data_dir(sample_id, config=config))
    return list(set(dir_list))


def judge_bwa_index(config: dict = None) -> bool:
    """Validates BWA-MEM2 index completeness."""
    bwa_index = config["bwa_mem2"]["index"]
    bwa_index_files = [
        bwa_index + suffix
        for suffix in [".0123", ".amb", ".ann", ".bwt.2bit.64", ".pac", ".alt"]
    ]
    return not all(os.path.exists(f) for f in bwa_index_files)


def judge_star_index(config: dict, Genome_Version: str) -> bool:
    """Validates STAR index completeness."""
    try:
        star_config = config["STAR_index"][Genome_Version]
        index_dir = star_config["index"]
    except KeyError:
        print(f"Error: Genome Version '{Genome_Version}' not found in config.")
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
        "Genome",
        "SAindex",
        "transcriptInfo.tab",
    ]

    full_paths = [os.path.join(index_dir, f) for f in required_files]
    return any(not os.path.exists(f) for f in full_paths)


def check_gene_version(config: dict = None, logger=None) -> None:
    """Validates that the configured genome version is supported."""
    if logger is None:
        from snakemake_logger_plugin_rich_loguru import get_analysis_logger

        logger = get_analysis_logger()

    try:
        version = config["Genome_Version"]
        allowed = config["can_use_genome_version"]

        if version not in allowed:
            logger.error(f"Version mismatch! '{version}' is not in {allowed}")
            raise ValueError(f"Unsupported genome version: {version}")

        logger.info(f"Config check passed: Genome_Version '{version}' is supported.")
    except (KeyError, TypeError) as e:
        logger.error(f"Config structure error or invalid type: {e}")
        raise
