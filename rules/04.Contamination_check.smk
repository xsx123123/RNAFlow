#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RNAFlow Pipeline - Contamination Screening Module

This module performs comprehensive contamination screening of RNA-seq data using
fastq_screen, which checks for the presence of reads originating from common
contaminant sources such as bacteria, viruses, fungi, and other organisms.

Key Components:
- generate_fastq_screen_conf: Creates configuration file with reference database paths
- check_fastq_screen_conf: Validates the fastq_screen configuration file
- short_read_fastq_screen_r1/r2: Runs contamination screening on R1 and R2 reads
- fastq_screen_multiqc_r1/r2: Aggregates contamination results using MultiQC

Contamination screening is critical for RNA-seq analysis as it helps identify:
- Microbial contamination in samples
- Cross-contamination between samples
- Presence of unexpected organisms (e.g., viral infections)
- Quality issues with library preparation or sample handling

The module uses organism-specific reference databases to screen against potential
contaminants relevant to the experimental system.
"""

import os

rule generate_fastq_screen_conf:
    """
    Generate fastq_screen configuration file with appropriate database paths.

    This rule creates a customized fastq_screen configuration file by substituting
    the actual database path into a template configuration. The configuration file
    defines which reference genomes/databases should be used for contamination
    screening.

    The template file contains placeholder strings (__FASTQ_SCREEN_DB_PATH__) that
    are replaced with the actual path to the contamination reference databases.
    This approach allows for flexible configuration across different computing
    environments while maintaining a consistent template structure.

    The generated configuration file is essential for fastq_screen to know where
    to find the reference databases for alignment-based contamination detection.
    """
    input:
        template = workflow.source_path(config['parameter']['validate_fastq_screen']['path_conf']),
    output:
        conf = "01.qc/fastq_screen.conf"
    message:
        "Running fastq_screen configuration convert & generation",
    localrule: 
        True
    params:
        db_path = config.get("fastq_screen_db_path"),
    threads:
        1
    shell:
        """
        sed "s|__FASTQ_SCREEN_DB_PATH__|{params.db_path}|g" {input.template} > {output.conf}
        """

rule check_fastq_screen_conf:
    """
    Validate fastq_screen configuration file for correctness and completeness.

    This rule runs a validation script to ensure that the generated fastq_screen
    configuration file is properly formatted and that all referenced database
    files exist and are accessible. This validation step prevents runtime errors
    during the actual contamination screening process.

    The validation checks include:
    - Configuration file syntax and structure
    - Existence of referenced database files
    - Proper file permissions for database access
    - Correct formatting of database definitions

    If validation fails, the pipeline will halt, preventing downstream analysis
    with potentially misconfigured contamination screening parameters.
    """
    input:
        conf = "01.qc/fastq_screen.conf",
    output:
        log = "01.qc/fastq_screen_config_check.log",
    resources:
        **rule_resource(config, 'low_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/py3.12.yaml"),
    message:
        "Checking fastq_screen configuration format",
    log:
        "logs/fastq_screen_config_check.log",
    params:
        validate_fastq_screen = workflow.source_path(config['parameter']['validate_fastq_screen']['path']),
    threads:
        1
    shell:
        """
        chmod +x {params.validate_fastq_screen} && \
        {params.validate_fastq_screen} {input.conf} --log {output.log} &> {log}
        """

rule short_read_fastq_screen_r1:
    """
    Screen R1 reads for contamination using fastq_screen.

    This rule runs fastq_screen on R1 (forward) reads to detect potential contamination
    from various sources including bacteria, viruses, fungi, and other organisms.
    fastq_screen aligns reads against multiple reference databases simultaneously and
    reports the percentage of reads mapping to each database.

    Key parameters:
    - --subset: Number of reads to sample for screening (improves performance)
    - --aligner: Alignment tool to use (typically bowtie2 or bwa)
    - --conf: Configuration file specifying reference databases
    - --outdir: Output directory for results

    The output is a text file containing detailed contamination statistics showing
    what percentage of reads map to each reference database. High contamination
    levels may indicate sample quality issues or biological phenomena (e.g., viral
    infection, microbiome presence).
    """
    input:
        md5_check = "01.qc/md5_check.tsv",
        log = "01.qc/fastq_screen_config_check.log",
        conf = "01.qc/fastq_screen.conf"
    output:
        fastq_screen_result = "01.qc/fastq_screen_r1/{sample}_R1_screen.txt",
    resources:
        **rule_resource(config, 'high_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path('../envs/fastq_screen.yaml'),
    log:
        "logs/01.short_read_qc_r1/{sample}.r1.fastq_screen.log",
    message:
        "Running fastq_screen on {wildcards.sample} r1",
    benchmark:
        "benchmarks/{sample}_r1_fastq_screen_benchmark.txt",
    params:
        out_dir = "01.qc/fastq_screen_r1/",
        link_r1_dir = os.path.join("00.raw_data",
                                      config['convert_md5'],
                                      "{sample}/{sample}_R1.fq.gz"),
        subset = config['parameter']['fastq_screen']['subset'],
        aligner = config['parameter']['fastq_screen']['aligner'],
    threads:
        config['parameter']['threads']['fastq_screen'],
    shell:
        """
        fastq_screen --threads  {threads} \
                     --force \
                     --subset  {params.subset} \
                     --aligner  {params.aligner} \
                     --conf {input.conf} \
                     --outdir {params.out_dir} \
                     {params.link_r1_dir} &> {log}
        """

rule short_read_fastq_screen_r2:
    """
    Screen R2 reads for contamination using fastq_screen.

    This rule performs contamination screening on R2 (reverse) reads using the same
    parameters and reference databases as the R1 analysis. Analyzing both read
    directions provides more comprehensive contamination detection and helps
    identify asymmetric contamination patterns.

    Comparing R1 and R2 contamination results can reveal:
    - Consistent contamination across both read directions
    - Direction-specific contamination artifacts
    - Potential issues with reverse read quality affecting alignment

    Like the R1 analysis, this generates a detailed text report showing the
    percentage of R2 reads mapping to each reference database in the contamination
    screening panel.
    """
    input:
        md5_check = "01.qc/md5_check.tsv",
        log = "01.qc/fastq_screen_config_check.log",
        conf = "01.qc/fastq_screen.conf"
    output:
        fastq_screen_result = "01.qc/fastq_screen_r2/{sample}_R2_screen.txt",
    resources:
        **rule_resource(config, 'high_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path('../envs/fastq_screen.yaml'),
    log:
        "logs/01.short_read_qc_r2/{sample}.r2.fastq_screen.log",
    message:
        "Running fastq_screen on {wildcards.sample} r2",
    benchmark:
        "benchmarks/{sample}_r2_fastq_screen_benchmark.txt",
    params:
        out_dir = "01.qc/fastq_screen_r2/",
        subset = config['parameter'][ 'fastq_screen']['subset'],
        aligner = config['parameter']['fastq_screen']['aligner'],
        link_r2_dir = os.path.join("00.raw_data",
                                      config['convert_md5'],
                                      "{sample}/{sample}_R2.fq.gz"),
    threads:
        config['parameter']['threads']['fastq_screen'],
    shell:
        """
        fastq_screen --threads  {threads} \
                     --force \
                     --subset  {params.subset} \
                     --aligner  {params.aligner} \
                     --conf {input.conf} \
                     --outdir {params.out_dir} \
                     {params.link_r2_dir} &> {log}
        """

rule fastq_screen_multiqc_r1:
    """
    Aggregate R1 fastq_screen contamination reports across all samples using MultiQC.

    This rule collects contamination screening results from all samples for R1 reads
    and generates a comprehensive MultiQC report that enables cross-sample comparison
    of contamination levels. The aggregated report provides interactive visualizations
    showing contamination patterns across the entire experiment.

    The MultiQC report helps identify:
    - Samples with unusually high contamination levels
    - Consistent contamination sources across multiple samples
    - Batch effects or technical artifacts related to contamination
    - Overall contamination trends in the dataset

    This quality control step is essential for determining whether samples meet
    contamination thresholds for inclusion in downstream analysis.
    """
    input:
        fastqc_files_r1 = expand("01.qc/fastq_screen_r1/{sample}_R1_screen.txt",\
                                  sample=samples.keys()),
    output:
        report = "01.qc/fastq_screen_multiqc_r1/multiqc_r1_fastq_screen_report.html",
    resources:
        **rule_resource(config, 'low_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/multiqc.yaml"),
    message:
        "Running MultiQC to aggregate R1 fastq screen reports",
    log:
        "logs/01.multiqc/multiqc-fastq-screen-r1.log",
    benchmark:
        "benchmarks/fastqc_multiqc-fastq-screen-r1_benchmark.txt",
    params:
        fastqc_reports = "01.qc/fastq_screen_r1",
        report_dir = "01.qc/fastq_screen_multiqc_r1/",
        report = "multiqc_r1_fastq_screen_report.html",
        title = "r1-fastq-screen-multiqc-report",
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
    """
    Aggregate R2 fastq_screen contamination reports across all samples using MultiQC.

    This rule creates a comprehensive MultiQC report for R2 contamination screening
    results, complementing the R1 report to provide a complete view of contamination
    patterns in both read directions. Having separate reports for R1 and R2 allows
    for detailed comparison of contamination profiles between forward and reverse reads.

    The R2 MultiQC report is particularly useful for:
    - Identifying direction-specific contamination artifacts
    - Validating that contamination patterns are consistent between read pairs
    - Assessing whether R2 quality issues affect contamination detection accuracy
    - Providing comprehensive contamination documentation for all samples

    Together with the R1 report, this provides a thorough assessment of sample
    purity and data quality before proceeding to downstream RNA-seq analysis.
    """
    input:
        fastqc_files_r1 = expand("01.qc/fastq_screen_r2/{sample}_R2_screen.txt",
                                sample=samples.keys()),
    output:
        report = "01.qc/fastq_screen_multiqc_r2/multiqc_r2_fastq_screen_report.html",
    resources:
        **rule_resource(config, 'low_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/multiqc.yaml"),
    message:
        "Running MultiQC to aggregate R2 fastq screen reports",
    log:
        "logs/01.multiqc/multiqc-fastq-screen-r2.log",
    benchmark:
        "benchmarks/fastqc_multiqc-fastq-screen-r2_benchmark.txt",
    params:
        fastqc_reports = "01.qc/fastq_screen_r2",
        report_dir = "01.qc/fastq_screen_multiqc_r2/",
        report = "multiqc_r2_fastq_screen_report.html",
        title = "r2-fastq-screen-multiqc-report",
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