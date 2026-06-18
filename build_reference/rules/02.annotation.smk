#!/usr/bin/env python3
# -*- coding: utf-8 -*-

rule build_bed12:
    input:
        gtf = rules.copy_reference_files.output.gtf,
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
        gtf = rules.copy_reference_files.output.gtf,
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
            tmpfile=$(mktemp {output.ref_all}.tmp.XXXXXX) && \
            gtfToGenePred -genePredExt \
                          -ignoreGroupsWithoutExons \
                          {input.gtf} "$tmpfile" && \
            awk 'BEGIN{{OFS="\\t"}} {{print $12, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10}}' \
                 "$tmpfile" > {output.ref_all} && \
            rm -f "$tmpfile"
        }} > {log} 2>&1
        """
