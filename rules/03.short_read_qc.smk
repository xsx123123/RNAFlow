#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RNAFlow Pipeline - Short Read Quality Control Module

This module performs comprehensive quality control analysis on raw sequencing reads
using FastQC and MultiQC. The analysis is performed separately on R1 and R2 reads
to provide detailed insights into read quality, adapter contamination, sequence
bias, and other quality metrics.

Key Components:
- short_read_qc_r1/r2: Individual FastQC analysis for R1 and R2 reads
- short_read_multiqc_r1/r2: Aggregation of FastQC results using MultiQC

The quality control results serve as the foundation for downstream analysis decisions,
including adapter trimming, quality filtering, and assessment of overall data quality.
Poor quality metrics can indicate issues with library preparation, sequencing runs,
or sample quality that may require troubleshooting or exclusion from further analysis.
"""

import os

rule short_read_qc_r1:
    """
    Perform comprehensive quality control analysis on R1 reads using FastQC.

    This rule runs FastQC on the R1 (forward) reads to generate detailed quality
    metrics including:
    - Per base sequence quality
    - Per sequence quality scores
    - Per base sequence content
    - Per sequence GC content
    - Sequence length distribution
    - Sequence duplication levels
    - Overrepresented sequences
    - Adapter content

    FastQC provides both HTML reports for visual inspection and ZIP files containing
    raw data tables for programmatic analysis. The MD5 check dependency ensures that
    only validated, uncorrupted data is processed.

    Quality metrics from this analysis inform downstream decisions about:
    - Whether adapter trimming is necessary
    - Appropriate quality filtering thresholds
    - Potential issues with library preparation or sequencing
    """
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
    message:
        "Running FastQC on {wildcards.sample} r1",
    benchmark:
        "benchmarks/{sample}_r1_fastqc_benchmark.txt",
    params:
        out_dir = "01.qc/short_read_qc_r1/",
        r1 = "00.link_dir/{sample}/{sample}_R1.fq.gz",
    threads:
        config['parameter']['threads']['fastqc'],
    shell:
        """
        fastqc {input.link_r1_dir} \
               -o {params.out_dir} \
               --threads {threads} &> {log.r1}
        """

rule short_read_qc_r2:
    """
    Perform comprehensive quality control analysis on R2 reads using FastQC.

    This rule runs FastQC on the R2 (reverse) reads, providing the same comprehensive
    quality metrics as the R1 analysis but specific to the reverse reads. In paired-end
    sequencing, R2 reads often show different quality patterns compared to R1 reads,
    particularly in terms of quality degradation towards the end of reads.

    Comparing R1 and R2 quality metrics helps identify:
    - Asymmetric quality degradation between read pairs
    - Differences in adapter contamination patterns
    - Potential issues with reverse read sequencing chemistry

    Like the R1 analysis, this generates both HTML and ZIP output formats for flexible
    downstream analysis and reporting.
    """
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
    message:
        "Running FastQC on {wildcards.sample} r2",
    benchmark:
        "benchmarks/{sample}_r2_fastqc_benchmark.txt",
    params:
        out_dir = "01.qc/short_read_qc_r2",
        r2 = "00.link_dir/{sample}/{sample}_R2.fq.gz",
    threads:
        config['parameter']['threads']['fastqc'],
    shell:
        """
        fastqc {input.link_r2_dir} \
               -o {params.out_dir} \
               --threads {threads} &> {log.r2}
        """

rule short_read_multiqc_r1:
    """
    Aggregate R1 FastQC quality control reports across all samples using MultiQC.

    This rule collects FastQC results from all samples for R1 reads and generates
    a comprehensive HTML report that enables cross-sample comparison of quality
    metrics. MultiQC provides interactive plots and summary statistics that help
    identify:
    - Consistent quality issues across all samples
    - Outlier samples with poor quality metrics
    - Batch effects or technical artifacts
    - Overall data quality trends

    The aggregated report is essential for quality assurance and provides a single
    dashboard for assessing the quality of all R1 reads in the experiment before
    proceeding to downstream analysis.
    """
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
    log:
        "logs/01.multiqc/multiqc-r1.log",
    benchmark:
        "benchmarks/fastqc_multiqc-r1_benchmark.txt",
    params:
        fastqc_reports = "01.qc/short_read_qc_r1",
        multiqc_dir = '01.qc/short_read_r1_multiqc/',
        report = "multiqc_r1_raw-data_report.html",
        title = "r1-raw-data-multiqc-report",
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

rule short_read_multiqc_r2:
    """
    Aggregate R2 FastQC quality control reports across all samples using MultiQC.

    Similar to the R1 aggregation, this rule creates a comprehensive MultiQC report
    for all R2 reads across samples. Having separate R1 and R2 MultiQC reports allows
    for detailed comparison of quality patterns between forward and reverse reads.

    This report is particularly useful for:
    - Identifying asymmetric quality issues between read pairs
    - Assessing whether R2-specific problems exist (e.g., worse quality in R2)
    - Comparing adapter contamination patterns between R1 and R2
    - Validating that both read directions meet quality standards

    The R2 MultiQC report complements the R1 report to provide a complete picture
    of raw data quality for paired-end sequencing experiments.
    """
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
    log:
        "logs/01.multiqc/multiqc-r2.log",
    benchmark:
        "benchmarks/fastqc_multiqc-r2_benchmark.txt",
    params:
        fastqc_reports = "01.qc/short_read_qc_r2",
        report_dir = "01.qc/short_read_r2_multiqc/",
        multiqc_dir = '01.qc/short_read_r2_multiqc/',
        report = "multiqc_r2_raw-data_report.html",
        title = "r2-raw-data-multiqc-report",
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
