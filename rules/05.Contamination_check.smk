#!/usr/bin/snakemake
# -*- coding: utf-8 -*-
import os
# ----- rule ----- #
rule short_read_fastq_screen_r1:
    input:
        md5_check = "01.qc/md5_check.tsv",
    output:
        fastq_screen_result = "01.qc/fastq_screen_r1/{sample}_R1_screen.txt",
    log:
        "logs/01.short_read_qc_r1/{sample}.r1.fastq_screen.log",
    params:
        out_dir = "01.qc/fastq_screen_r1/",
        link_r1_dir = os.path.join("00.raw_data",
                                      config['convert_md5'],
                                      "{sample}/{sample}_R1.fq.gz"),
        fastq_screen_dir = config['parameter']['fastq_screen']['path'],
        conf = config['parameter']['fastq_screen']['conf'],
        subset = config['parameter'][ 'fastq_screen']['subset'],
        aligner = config['parameter']['fastq_screen']['aligner'],
    message:
        "Running fastq_screen on {wildcards.sample} r1",
    benchmark:
        "benchmarks/{sample}_r1_fastq_screen_benchmark.txt",
    threads: 
        config['parameter']['threads']['fastq_screen'],
    shell:
        """
        {params.fastq_screen_dir} --threads  {threads} \
                     --force \
                     --subset  {params.subset} \
                     --aligner  {params.aligner} \
                     --conf {params.conf} \
                     --outdir {params.out_dir} \
                     {params.link_r1_dir} &> {log}
        """

rule short_read_fastq_screen_r2:
    input:
        md5_check = "01.qc/md5_check.tsv",
    output:
        fastq_screen_result = "01.qc/fastq_screen_r2/{sample}_R2_screen.txt",
    log:
        "logs/01.short_read_qc_r2/{sample}.r2.fastq_screen.log",
    params:
        out_dir = "01.qc/fastq_screen_r2/",
        fastq_screen_dir = config['parameter']['fastq_screen']['path'],
        conf = config['parameter']['fastq_screen']['conf'],
        subset = config['parameter'][ 'fastq_screen']['subset'],
        aligner = config['parameter']['fastq_screen']['aligner'],
        link_r2_dir = os.path.join("00.raw_data",
                                      config['convert_md5'],
                                      "{sample}/{sample}_R2.fq.gz"),
    message:
        "Running fastq_screen on {wildcards.sample} r2",
    benchmark:
        "benchmarks/{sample}_r2_fastq_screen_benchmark.txt",
    threads: 
        config['parameter']['threads']['fastq_screen'],
    shell:
        """
        {params.fastq_screen_dir} --threads  {threads} \
                     --force \
                     --subset  {params.subset} \
                     --aligner  {params.aligner} \
                     --conf {params.conf} \
                     --outdir {params.out_dir} \
                     {params.link_r2_dir} &> {log}
        """

rule fastq_screen_multiqc_r1:
    input:
        fastqc_files_r1 = expand("01.qc/fastq_screen_r1/{sample}_R1_screen.txt",\
                                  sample=samples.keys()),
    output:
        report = "01.qc/fastq_screen_multiqc_r1/multiqc_r1_fastq_screen_report.html",
    conda:
        workflow.source_path("../envs/multiqc.yaml"),
    message:
        "Running MultiQC to aggregate R1 fastq screen reports",
    params:
        fastqc_reports = "01.qc/fastq_screen_r1",
        report_dir = "01.qc/fastq_screen_multiqc_r1/",
        report = "multiqc_r1_fastq_screen_report.html",
        title = "r1-fastq-screen-multiqc-report",
    log:
        "logs/01.multiqc/multiqc-fastq-screen-r1.log",
    benchmark:
        "benchmarks/fastqc_multiqc-fastq-screen-r1_benchmark.txt",
    threads:
        config['parameter']['threads']['multiqc'],
    shell:
        """
        multiqc {params.fastqc_reports} \
                --force \
                --outdir {params.report_dir} \
                -i {params.title} \
                -n {params.report} &> {log}
        """

rule fastq_screen_multiqc_r2:
    input:
        fastqc_files_r1 = expand("01.qc/fastq_screen_r2/{sample}_R2_screen.txt",
                                sample=samples.keys()),
    output:
        report = "01.qc/fastq_screen_multiqc_r2/multiqc_r2_fastq_screen_report.html",
    conda:
        workflow.source_path("../envs/multiqc.yaml"),
    message:
        "Running MultiQC to aggregate R2 fastq screen reports",
    params:
        fastqc_reports = "01.qc/fastq_screen_r2",
        report_dir = "01.qc/fastq_screen_multiqc_r2/",
        report = "multiqc_r2_fastq_screen_report.html",
        title = "r2-fastq-screen-multiqc-report",
    log:
        "logs/01.multiqc/multiqc-fastq-screen-r2.log",
    benchmark:
        "benchmarks/fastqc_multiqc-fastq-screen-r2_benchmark.txt",
    threads:
        config['parameter']['threads']['multiqc'],
    shell:
        """
        multiqc {params.fastqc_reports} \
                --force \
                --outdir {params.report_dir} \
                -i {params.title} \
                -n {params.report} &> {log}
        """
# ----- rule ----- #
