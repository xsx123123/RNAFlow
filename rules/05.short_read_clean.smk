#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RNAFlow Pipeline - Short Read Cleaning and Adapter Trimming Module

This module performs comprehensive quality trimming and adapter removal from raw
sequencing reads using Fastp, a fast and efficient preprocessing tool for NGS data.

Key Components:
- short_read_fastp: Main adapter trimming and quality filtering rule
- multiqc_trim: Aggregation of Fastp results using MultiQC

The cleaning process is essential for removing technical artifacts that can negatively
impact downstream alignment and analysis, including:
- Adapter sequences from library preparation
- Low-quality bases at read ends
- Reads that are too short after trimming
- PCR duplicates (optional)

Fastp provides both HTML and JSON reports that document the cleaning process and
provide detailed statistics on what was removed and retained.
"""

import os

rule short_read_fastp:
    """
    Trim adapters and filter low-quality reads using Fastp.

    This rule performs comprehensive preprocessing of paired-end sequencing reads
    using Fastp, which combines adapter trimming, quality filtering, and various
    quality control features in a single, highly optimized tool.

    Key processing steps performed by Fastp:
    - Adapter detection and removal using built-in adapter sequences
    - Quality trimming based on Phred quality scores
    - Length filtering to remove reads that become too short after trimming
    - Per-base quality statistics and sequence content analysis
    - Duplicate read detection and marking (optional)
    - Poly-G tail trimming for Illumina NextSeq/NovaSeq data

    Parameters:
    - length_required: Minimum read length after trimming (reads shorter than this are discarded)
    - quality_threshold: Phred quality score threshold for base trimming
    - adapter_fasta: Custom adapter sequences file (if needed beyond built-in adapters)

    The rule outputs cleaned FASTQ files (R1 and R2) along with comprehensive HTML
    and JSON reports documenting the preprocessing results. These cleaned reads are
    used as input for all downstream alignment and analysis steps.
    """
    input:
        md5_check = "01.qc/md5_check.tsv",
        link_r1_dir =  os.path.join("00.raw_data",
                                      config['convert_md5'],
                                      "{sample}/{sample}_R1.fq.gz"),
        link_r2_dir =  os.path.join("00.raw_data",
                                      config['convert_md5'],
                                      "{sample}/{sample}_R2.fq.gz"),
    output:
        r1_trimmed = "01.qc/short_read_trim/{sample}.R1.trimed.fq.gz",
        r2_trimmed = "01.qc/short_read_trim/{sample}.R2.trimed.fq.gz",
        html_report = "01.qc/short_read_trim/{sample}.trimed.html",
        json_report = "01.qc/short_read_trim/{sample}.trimed.json",
    resources:
        **rule_resource(config, 'high_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/fastp.yaml"),
    log:
        "logs/01.short_read_trim/{sample}.trimed.log",
    message:
        "Running Fastp on {wildcards.sample} r1 and {wildcards.sample} r2",
    benchmark:
        "benchmarks/{sample}_fastp_benchmark.txt",
    params:
        length_required = config['parameter']["trim"]["length_required"],
        quality_threshold = config['parameter']["trim"]["quality_threshold"],
        adapter_fasta = workflow.source_path(config['parameter']["trim"]["adapter_fasta"]),
    threads:
        config['parameter']["threads"]["fastp"],
    shell:
        """
        fastp -i {input.link_r1_dir} -I {input.link_r2_dir} \
              -o {output.r1_trimmed} -O {output.r2_trimmed} \
              --thread {threads} \
              --length_required  {params.length_required} \
              --qualified_quality_phred {params.quality_threshold} \
              --adapter_fasta {params.adapter_fasta} \
              -g -V \
              -h {output.html_report} \
              -j {output.json_report} &> {log}
        """

rule multiqc_trim:
    """
    Aggregate Fastp quality control reports across all samples using MultiQC.

    This rule collects Fastp preprocessing results from all samples and generates
    a comprehensive MultiQC report that enables cross-sample comparison of cleaning
    metrics. The aggregated report provides interactive visualizations showing:
    - Read retention rates after trimming
    - Quality score improvements
    - Adapter contamination levels before and after trimming
    - Sequence length distributions
    - Duplication rates

    The MultiQC report serves as a critical quality control checkpoint to ensure
    that the cleaning process was successful and consistent across all samples.
    It helps identify samples with unusually high adapter contamination, poor
    quality improvement, or other preprocessing issues that might affect downstream
    analysis reliability.

    This report is essential for validating that the cleaned reads meet quality
    standards before proceeding to alignment and quantification steps.
    """
    input:
        md5_check = "01.qc/md5_check.tsv",
        r1_trimmed = expand("01.qc/short_read_trim/{sample}.R1.trimed.fq.gz",
                            sample=samples.keys()),
        r2_trimmed = expand("01.qc/short_read_trim/{sample}.R2.trimed.fq.gz",
                            sample=samples.keys()),
        fastp_report = expand("01.qc/short_read_trim/{sample}.trimed.html",
                              sample=samples.keys()),
    output:
        report = '01.qc/multiqc_short_read_trim/multiqc_short_read_trim_report.html',
    resources:
        **rule_resource(config, 'low_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/multiqc.yaml"),
    log:
        "logs/01.short_read_trim/multiqc_trim.log",
    message:
        "Running MultiQC to aggregate fastp reports",
    benchmark:
        "benchmarks/multiqc_fastp_benchmark.txt",
    params:
        fastqc_reports = "01.qc/short_read_trim/",
        report_dir = "01.qc/multiqc_short_read_trim/",
        report = "multiqc_short_read_trim_report.html",
        title = "short_read_trim-multiqc-report",
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
# ---END--- #