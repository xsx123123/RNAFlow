#!/usr/bin/env python3
# -*- coding: utf-8 -*-

rule build_bed12:
    input:
        gtf = config["Reference"]["data_dir"]["gtf"],
    output:
        bed12 = f"{config['Reference']['info']['prefix']}.bed12",
    conda:
        workflow.source_path("../envs/ucsc_gff.yaml")
    log:
        "logs/02.annotation/build_bed12.log",
    message:
        "Converting GTF to BED12 with gtfToGenePred and genePredToBed",
    benchmark:
        "benchmarks/02.build_bed12_benchmark.txt",
    shell:
        """
        gtfToGenePred -genePredExt \
                      -ignoreGroupsWithoutExons \
                      {input.gtf} stdout | \
                      genePredToBed stdin {output.bed12} > {log} 2>&1
        """

rule build_ref_all:
    input:
        gtf = config["Reference"]["data_dir"]["gtf"],
    output:
        ref_all = f"{config['Reference']['info']['prefix']}_ref_all.txt",
    conda:
        workflow.source_path("../envs/ucsc_gff.yaml")
    log:
        "logs/02.annotation/build_ref_all.log",
    message:
        "Building ref_all gene information table from GTF",
    benchmark:
        "benchmarks/02.build_ref_all_benchmark.txt",
    shell:
        """
        {{
            gtfToGenePred -genePredExt \
                          -ignoreGroupsWithoutExons \
                          {input.gtf} ref_all.tmp && \
            awk 'BEGIN{{OFS="\\t"}} {{print $12, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10}}' \
                 ref_all.tmp > {output.ref_all} && \
            rm -f ref_all.tmp
        }} > {log} 2>&1
        """
