#!/usr/bin/env python3
# *---utf-8---*
# Author : JZHANG

import sys
import os
from snakemake.utils import min_version, validate

# ------- Import Custom Modules ------- #
from rules.utils.id_convert import load_samples,load_contrasts
from rules.utils.validate import check_reference_paths,load_user_config,validate_genome_version
from rules.utils.reference_update import resolve_reference_paths
from rules.utils.resource_manager import rule_resource

# Lock Snakemake Version
min_version("9.9.0")

# --------- 1. Config Loading --------- #
# Load default configs
configfile: "config/config.yaml"
configfile: "config/reference.yaml"
configfile: "config/run_parameter.yaml"
configfile: "config/cluster_config.yaml" 

# Load CLI argument config (Highest Priority)
load_user_config(config, cmd_arg_name='analysisyaml')

# --------- 2. Processing & Validation --------- #
# Update absolute paths for references
resolve_reference_paths(config,
                        ["STAR_index", "deg_enrich_wrapper", "ploidy_setting"],
                        base_path=config.get('reference_path'))

# Validate schema and file existence
validate(config, "schema/config.schema.yaml")
check_reference_paths(config.get("STAR_index", {}), config.get("Genome_Version"))

# Get logger instance for validation
from snakemake_logger_plugin_rich_loguru import get_analysis_logger
logger = get_analysis_logger()
validate_genome_version(config=config, logger=logger)

# --------- 3. Workspaces & Samples --------- #
# Redirect workspace to config['workflow'] directory 
workdir: config["workflow"]
logger.info(f"Redirect workspaces to {config['workflow']}") 

# Load samples and contrasts from CSV files
samples = load_samples(config["sample_csv"], required_cols=["sample", "sample_name", "group"])

# Load contrasts only when a contrast-dependent module is enabled.
needs_contrasts = any(
    config.get(module, True) is not False for module in ("deg", "rmats")
)
if config.get('only_qc', False) or not needs_contrasts:
    logger.info("Contrast-dependent modules disabled: skipping contrast loading")
    ALL_CONTRASTS = []
    CONTRAST_MAP = {}
else:
    ALL_CONTRASTS, CONTRAST_MAP = load_contrasts(config["paired_csv"], samples)

# --------- 4. Rules Import --------- #
include: 'rules/01.common.smk'
include: 'rules/02.file_convert_md5.smk'
include: 'rules/03.short_read_qc.smk'
include: 'rules/04.Contamination_check.smk'
include: 'rules/05.short_read_clean.smk'
include: 'rules/06.mapping.smk'
include: 'rules/07.rsem.smk'
include: 'rules/08.call_variant.smk'
include: 'rules/09.Assembly.smk'
include: 'rules/10.DEG_Enrichments.smk'
include: 'rules/11.rMATS.smk'
include: 'rules/12.GeneFusion.smk'
ANALYSIS_TARGETS = AnalysisTargets(
    config=config,
    samples=samples,
    all_contrasts=ALL_CONTRASTS,
)
include: 'rules/13.deliver.smk'
include: 'rules/14.Report.smk'
# --------- 5. Target Rule --------- #
ALL_TARGETS = DataDeliver(
    config=config,
    samples=samples,
    all_contrasts=ALL_CONTRASTS,
)
# Target rule to run all rules
rule all:
    input:
        ALL_TARGETS,
