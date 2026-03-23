#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RNAFlow Pipeline - Common Utility Functions Module
"""

import os
import glob
import sys
import time
from pathlib import Path
from typing import Dict, Union, List, Callable
from rich import print as rich_print

# Global flag for QC warning
_qc_warning_logged = False


def DataDeliver(
    config: Dict = None, samples: Dict = None, all_contrasts: Dict = None
) -> List[str]:
    """
    Main data delivery orchestrator.
    Controls the flow of the pipeline based on 'only_qc' and specific module flags.
    """
    # Initialize config/samples if None
    config = config or {}
    samples = samples or {}

    # Initialize logger
    from snakemake_logger_plugin_rich_loguru import get_analysis_logger

    logger = get_analysis_logger()

    # ---------------------------------------------------------
    # 0. 初始化基础文件列表 (MD5 Check)
    # ---------------------------------------------------------
    convert_md5_path = config.get("convert_md5", "md5_check")
    data_deliver = [
        "01.qc/md5_check.tsv",
        os.path.join("00.raw_data", convert_md5_path),
        os.path.join("00.raw_data", convert_md5_path, "raw_data_md5.json"),
    ]

    # ---------------------------------------------------------
    # 1. 定义模块类别
    # ---------------------------------------------------------

    # [A] 基础模块：无论如何必须运行，不需要用户在 yaml 配置
    basic_modules = ["qc_clean", "mapping", "count"]

    # [B] 深度质控标记：属于 Mapping 内部的参数，默认开启，only_qc=True 时也保留
    deep_qc_flags = ["rseqc", "bamCoverage", "tin"]

    # [C] 下游分析模块：只有当 only_qc=False 时才尝试运行
    downstream_modules = [
        "DEG",
        "call_variant",
        "detect_novel_transcripts",
        "rmats",
        "gene_fusion",
    ]

    # ---------------------------------------------------------
    # 2. 定义执行包装器 (Wrappers)
    # ---------------------------------------------------------
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
        return detect_novel_transcripts(samples, data_deliver)

    def execute_rmats(samples, data_deliver, all_contrasts):
        contrasts = all_contrasts if all_contrasts else config.get("all_contrasts", [])
        return rmats(samples, data_deliver, contrasts)

    def execute_gene_fusion(samples, data_deliver):
        return gene_fusion(samples, data_deliver)

    # 模块函数映射表
    module_functions: Dict[str, Callable] = {
        "qc_clean": execute_qc_clean,
        "mapping": execute_mapping,
        "count": execute_count,
        "DEG": execute_deg,
        "call_variant": execute_call_variant,
        "detect_novel_transcripts": execute_novel_transcripts,
        "rmats": execute_rmats,
        "gene_fusion": execute_gene_fusion,
    }

    # ---------------------------------------------------------
    # 3. 核心逻辑控制 (配置参数修正)
    # ---------------------------------------------------------
    global _qc_warning_logged

    # Step 3.1: 强制开启基础模块 (除非用户显式设为 False)
    for module in basic_modules:
        if config.get(module) is not False:
            config[module] = True

    # Step 3.2: 强制开启深度质控参数 (除非用户显式设为 False)
    for flag in deep_qc_flags:
        if config.get(flag) is not False:
            config[flag] = True

    # Step 3.3: 根据 only_qc 处理下游模块
    if config.get("only_qc"):
        if not _qc_warning_logged:
            logger.warning(
                "**********************************************************************"
            )
            logger.warning(
                "   [MODE] ONLY QC ENABLED                                            "
            )
            logger.warning(
                "   - Running: Raw QC, Mapping, Counting, RSeQC, BamCoverage           "
            )
            logger.warning(
                "   - Skipping: DEG, Variants, Novel Transcripts, rMATS                "
            )
            logger.warning(
                "**********************************************************************"
            )
            time.sleep(1)
            _qc_warning_logged = True

        for module in downstream_modules:
            config[module] = False

    else:
        for module in downstream_modules:
            if config.get(module) is not False:
                config[module] = True

    # ---------------------------------------------------------
    # 4. 执行并收集输出文件
    # ---------------------------------------------------------
    for module, func in module_functions.items():
        if config.get(module):
            if module == "rmats":
                data_deliver = func(samples, data_deliver, all_contrasts)
            elif module == "mapping":
                data_deliver = func(samples, data_deliver, config)
            else:
                data_deliver = func(samples, data_deliver)

    if config.get("print_target"):
        rich_print("[bold green]Generated Target Files:[/bold green]")
        rich_print(data_deliver)

    return data_deliver


def ReportData(config: dict = None) -> List[str]:
    """Collects all files required for generating the final report."""
    if config.get("report"):
        return [
            os.path.join(config["data_deliver"], "delivery_manifest.json"),
            os.path.join(config["data_deliver"], "delivery_manifest.md5"),
            os.path.join(config["data_deliver"], "delivery_details.log"),
            os.path.join(config["data_deliver"], "report_data/project_summary.json"),
            os.path.join(
                config["data_deliver"], "report_data", "delivery_manifest.json"
            ),
            os.path.join(
                config["data_deliver"], "report_data", "delivery_manifest.md5"
            ),
            os.path.join(config["data_deliver"], "report_data", "delivery_details.log"),
            os.path.join(config["data_deliver"], "Analysis_Report/index.html"),
        ]
    else:
        return []


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
