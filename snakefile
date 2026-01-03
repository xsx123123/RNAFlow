#!/usr/bin/env python3
# *---utf-8---*
# Version: RNAFlow_v0.1
# Author : JZHANG
# ------- snakemake version check ------- #
from snakemake.utils import min_version
from rules.id_convert import load_samples,_validate_df
min_version("9.9.0")
# --------- main snakefile --------- #
configfile: "config/config.yaml"
configfile: "config.yaml"
# workspaces
workdir: config["workflow"]
# ----   input sample info   ---- #
samples = load_samples(config["sample_csv"],required_cols = ["sample", "sample_name", "group"])
# --------- snakemake rule --------- #
# include all rules from the rules directory
include: 'rules/00.log.smk'
include: 'rules/01.common.smk'
include: 'rules/03.file_convert_md5.smk'
include: 'rules/04.short_read_qc.smk'
include: 'rules/05.Contamination_check.smk'
include: 'rules/06.short_read_clean.smk'
include: 'rules/07.mapping.smk'
include: 'rules/08.rsem.smk'
include: 'rules/09.call_variant.smk'
include: 'rules/10.Assembly.smk'
include: 'rules/11.DEG.smk'
# ---- check genome version  ---- #
check_gene_version(config = config,logger = logger)
# --------- target rule --------- #
rule all:
    input:
        DataDeliver(config = config)
# --------- target rule --------- #