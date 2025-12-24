#!/usr/bin/env python3
# *---utf-8---*
# Version: RNAFlow_v0.1
# Author : JZHANG
# ------- snakemake version check ------- #
from snakemake.utils import min_version
min_version("9.9.0")
# --------- main snakefile --------- #
configfile: "config/config.yaml"
configfile: "config.yaml"
# workspaces
workdir: config["workflow"]
# --------- snakemake rule --------- #
# include all rules from the rules directory
include: 'rules/00.log.smk'
include: 'rules/01.common.smk'
include: 'rules/02.id_convert.smk'
include: 'rules/03.file_convert_md5.smk'
include: 'rules/04.short_read_qc.smk'
include: 'rules/05.Contamination_check.smk'
include: 'rules/06.short_read_clean.smk'
include: 'rules/07.mapping.smk'
# --------- target rule --------- #
rule all:
    input:
        DataDeliver(config = config)
# --------- target rule --------- #