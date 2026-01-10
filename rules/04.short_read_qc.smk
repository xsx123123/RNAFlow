#!/usr/bin/snakemake
# -*- coding: utf-8 -*-
import os
# ----- rule ----- #
rule short_read_qc_r1:
    input:
        md5_check = "01.qc/md5_check.tsv",
        link_r1_dir = os.path.join("00.raw_data",
                                      config['convert_md5'],
                                      "{sample}/{sample}_R1.fq.gz"),
    output:
        r1_html = "01.qc/short_read_qc_r1/{sample}_R1_fastqc.html",
        r1_zip = "01.qc/short_read_qc_r1/{sample}_R1_fastqc.zip",
    resources:
        **rule_resource(config,'low_resource', skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/fastqc.yaml"),
    log:
        r1 = "logs/01.short_read_qc_r1/{sample}.r1.fastqc.log",
    params:
        out_dir = "01.qc/short_read_qc_r1/",
        r1 = "00.link_dir/{sample}/{sample}_R1.fq.gz",
    message:
        "Running FastQC on {wildcards.sample} r1",
    benchmark:
        "benchmarks/{sample}_r1_fastqc_benchmark.txt",
    threads: 
        config['parameter']['threads']['fastqc'],
    shell:
        """
        fastqc {input.link_r1_dir} \
               -o {params.out_dir} \
               --threads {threads} &> {log.r1}
        """

rule short_read_qc_r2:
    input:
        md5_check = "01.qc/md5_check.tsv",
        link_r2_dir = os.path.join("00.raw_data",
                                      config['convert_md5'],
                                      "{sample}/{sample}_R2.fq.gz"),
    output:
        r2_html = "01.qc/short_read_qc_r2/{sample}_R2_fastqc.html",
        r2_zip = "01.qc/short_read_qc_r2/{sample}_R2_fastqc.zip",
    resources:
        **rule_resource(config, 'low_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/fastqc.yaml"),
    log:
        r2 = "logs/01.short_read_qc_r2/{sample}.r2.fastqc.log",
    params:
        out_dir = "01.qc/short_read_qc_r2",
        r2 = "00.link_dir/{sample}/{sample}_R2.fq.gz",
    message:
        "Running FastQC on {wildcards.sample} r2",
    benchmark:
        "benchmarks/{sample}_r2_fastqc_benchmark.txt",
    threads:
        config['parameter']['threads']['fastqc'],
    shell:
        """
        fastqc {input.link_r2_dir} \
               -o {params.out_dir} \
               --threads {threads} &> {log.r2}
        """

# logger.info('Run MultiQC to summarize R1 fastqc QC reports')
rule short_read_multiqc_r1:
    input:
        fastqc_files_r1 = expand("01.qc/short_read_qc_r1/{sample}_R1_fastqc.zip", sample=samples.keys()),
    output:
        report_dir = "01.qc/short_read_r1_multiqc/multiqc_r1_raw-data_report.html",
    resources:
        **rule_resource(config, 'low_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/multiqc.yaml"),
    message:
        "Running MultiQC to aggregate R1 FastQC reports",
    params:
        fastqc_reports = "01.qc/short_read_qc_r1",
        multiqc_dir = '01.qc/short_read_r1_multiqc/',
        report = "multiqc_r1_raw-data_report.html",
        title = "r1-raw-data-multiqc-report",
    log:
        "logs/01.multiqc/multiqc-r1.log",
    benchmark:
        "benchmarks/fastqc_multiqc-r1_benchmark.txt",
    threads:
        config['parameter']['threads']['multiqc'],
    shell:
        """
        multiqc {params.fastqc_reports} \
                --force \
                --outdir {params.multiqc_dir} \
                -i {params.title} \
                -n {params.report} &> {log}
        """

# logger.info('Run MultiQC to summarize R2 fastqc QC reports')
rule short_read_multiqc_r2:
    input:
        fastqc_files_r2 = expand("01.qc/short_read_qc_r2/{sample}_R2_fastqc.zip", sample=samples.keys()),
    output:
        report = "01.qc/short_read_r2_multiqc/multiqc_r2_raw-data_report.html",
    resources:
        **rule_resource(config, 'low_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/multiqc.yaml"),
    message:
        "Running MultiQC to aggregate R2 FastQC reports",
    params:
        fastqc_reports = "01.qc/short_read_qc_r2",
        report_dir = "01.qc/short_read_r2_multiqc/",
        multiqc_dir = '01.qc/short_read_r2_multiqc/',
        report = "multiqc_r2_raw-data_report.html",
        title = "r2-raw-data-multiqc-report",
    log:
        "logs/01.multiqc/multiqc-r2.log",
    benchmark:
        "benchmarks/fastqc_multiqc-r2_benchmark.txt",
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
