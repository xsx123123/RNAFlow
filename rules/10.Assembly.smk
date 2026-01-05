#!/usr/bin/snakemake
# -*- coding: utf-8 -*-

rule StringTie_Assembly:
    input:
        bam = "02.mapping/STAR/sort_index/{sample}.sort.bam",
        gtf = config['parameter']['star_index'][config['Genome_Version']]['genome_gff'],
    output:
        gtf = "05.assembly/stringtie/{sample}.gtf"
    conda:
        workflow.source_path("../envs/stringtie.yaml"),
    log:
        "logs/05.assembly/stringtie/{sample}.log",
    benchmark:
        "benchmarks/05.assembly/stringtie/{sample}.txt",
    threads: 
        config['parameter']['threads']['stringtie'],
    shell:
        """
        stringtie {input.bam} \
            -G {input.gtf} \
            -o {output.gtf} \
            -p {threads} \
            -l {wildcards.sample} 2> {log}
        """

rule StringTie_Merge:
    input:
        gtfs = expand("05.assembly/stringtie/{sample}.gtf",
                      sample=samples.keys()),
        ref_gtf = config['parameter']['star_index'][config['Genome_Version']]['genome_gff'],
    output:
        merged_gtf = "05.assembly/stringtie/merged.gtf",
        gtf_list = "05.assembly/stringtie/mergelist.txt",
    conda:
        workflow.source_path("../envs/stringtie.yaml"),
    log:
        "logs/05.assembly/stringtie/merge.log"
    benchmark:
        "benchmarks/05.assembly/stringtie/merge.txt"
    threads: 
        config['parameter']['threads']['stringtie'],
    params:
        min_len = config['parameter']['stringtie']['min_length'],
        min_cov = config['parameter']['stringtie']['min_cov'],
        min_fpkm = config['parameter']['stringtie']['min_fpkm'],
    shell:
        """
        (ls {input.gtfs} > {output.gtf_list} && \
        stringtie --merge \
            -p {threads} \
            -G {input.ref_gtf} \
            -o {output.merged_gtf} \
            -m {params.min_len} \
            -c {params.min_cov} \
            -F {params.min_fpkm} \
            {output.gtf_list}) 2> {log}
        """

rule GffCompare:
    input:
        merged_gtf = "05.assembly/stringtie/merged.gtf",
        ref_gtf = config['parameter']['star_index'][config['Genome_Version']]['genome_gff'],
    output:
        annotated_gtf = "05.assembly/gffcompare/stringtie.annotated.gtf",
        stats = "05.assembly/gffcompare/stringtie.stats",
        tracking = "05.assembly/gffcompare/stringtie.tracking",
    conda:
        workflow.source_path("../envs/gffcompare.yaml"),
    log:
        "logs/05.assembly/gffcompare/gffcompare.log",
    benchmark:
        "benchmarks/05.assembly/gffcompare/gffcompare.txt",
    params:
        out_prefix = "05.assembly/gffcompare/stringtie",
    threads:
        1
    shell:
        """
        gffcompare -r {input.ref_gtf} \
                   -o {params.out_prefix} \
                   {input.merged_gtf} 2> {log}
        """

rule Filter_Novel_Transcripts:
    input:
        annotated_gtf = "05.assembly/gffcompare/stringtie.annotated.gtf",
    output:
        novel_gtf = "05.assembly/filter/novel_transcripts.gtf",
        final_gtf = "05.assembly/filter/final_all.gtf",
    log:
        "logs/05.assembly/filter/filter.log"
    benchmark:
        "benchmarks/05.assembly/filter/filter.txt",
    threads:
        1
    shell:
        """
        (awk '$0 ~ /class_code "[ujxi]"/ {{print $0}}' {input.annotated_gtf} > {output.novel_gtf} && \
        cp {input.annotated_gtf} {output.final_gtf}) 2> {log}
        """
# ------- rule ------- #