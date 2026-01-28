#!/usr/bin/snakemake
# -*- coding: utf-8 -*-
"""
RNAFlow Pipeline - Data Delivery and Final Report Generation Module

This module handles the final organization and delivery of RNA-seq analysis results
using the Rust-accelerated rnaflow-cli delivery tool. The delivery process ensures
that all analysis outputs are properly organized, validated, and prepared for
downstream use or sharing with collaborators.

Key Components:
- delivery: Main data delivery rule that organizes and transfers all analysis results
- delivery_report: Specialized delivery for report generation with curated file selection

The delivery tool performs several critical functions:
- File organization and directory structure standardization
- MD5 checksum generation for data integrity verification
- Manifest file creation documenting all delivered files
- Configuration-driven file selection based on analysis modules enabled
- Efficient file copying/symlinking with parallel processing support

This module represents the final step in the RNA-seq analysis pipeline, ensuring that
results are delivered in a consistent, reproducible, and well-documented format.
"""

import os
import pandas as pd

rule delivery:
    """
    Execute the main data delivery process using the Rust-accelerated rnaflow-cli tool.

    This rule orchestrates the final organization and transfer of all RNA-seq analysis
    results to a designated delivery directory. The delivery process is driven by the
    DataDeliver() function which dynamically determines which files should be included
    based on the analysis modules that were enabled in the pipeline configuration.

    Key features of the delivery process:
    - Comprehensive file organization following standardized directory structure
    - MD5 checksum generation for all delivered files to ensure data integrity
    - JSON manifest creation documenting all delivered files with metadata
    - Detailed delivery log capturing the complete delivery process
    - Configuration-driven file selection based on enabled analysis modules

    The rnaflow-cli tool is optimized for performance using Rust, enabling efficient
    handling of large datasets with parallel file operations and minimal memory overhead.

    Outputs:
    - delivery_manifest.json: Comprehensive JSON manifest of all delivered files
    - delivery_manifest.md5: MD5 checksums for all delivered files
    - delivery_details.log: Detailed log of the delivery process
    """
    input:
        DataDeliver(config)
    output:
        manifest_json = os.path.join(config['data_deliver'],'delivery_manifest.json'),
        manifest_md5 = os.path.join(config['data_deliver'],'delivery_manifest.md5'),
        manifest_log = os.path.join(config['data_deliver'],'delivery_details.log'),
    resources:
        **rule_resource(config, 'high_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/py3.12.yaml"),
    params:
        out_dir = config['data_deliver'],
        config_path = workflow.source_path(config['parameter']['RNAFlow_Deliver_Tool']['config_path']),
        source_dir = config['workflow'],
    log:
        "logs/delivery.log",
    benchmark:
        "benchmark/delivery.txt",
    threads:
        config['parameter']['threads']['rnaflow-cli'],
    shell:
        """
        ( rnaflow-cli deliver \
                    -d {params.source_dir} \
                    -o {params.out_dir} \
                    -c {params.config_path} ) &>{log}
        """

rule delivery_report:
    """
    Execute specialized data delivery for final report generation.

    This rule performs a targeted delivery specifically designed for report generation,
    using a different configuration file that selects only the files needed for the
    final analysis report. This ensures that the report generation process has access
    to all necessary files while avoiding unnecessary data transfer.

    The report-specific delivery configuration typically includes:
    - Key QC metrics and summary statistics
    - Differential expression results
    - Functional enrichment results
    - Visualization files and plots
    - Metadata and sample information

    This separation between full data delivery and report-specific delivery allows
    for efficient report generation without requiring access to the complete dataset,
    which is particularly useful for web-based reporting systems or when sharing
    reports with collaborators who don't need the raw data.

    Outputs are organized in a dedicated 'report_data' subdirectory within the main
    delivery directory, maintaining clear separation between full results and report
    assets.
    """
    input:
        DataDeliver(config),
        manifest_json = os.path.join(config['data_deliver'],'delivery_manifest.json'),
        manifest_md5 = os.path.join(config['data_deliver'],'delivery_manifest.md5'),
        manifest_log = os.path.join(config['data_deliver'],'delivery_details.log'),
    output:
        manifest_json = os.path.join(config['data_deliver'],'report_data','delivery_manifest.json'),
        manifest_md5 = os.path.join(config['data_deliver'],'report_data','delivery_manifest.md5'),
        manifest_log = os.path.join(config['data_deliver'],'report_data','delivery_details.log'),
    resources:
        **rule_resource(config, 'high_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/py3.12.yaml"),
    params:
        out_dir =  os.path.join(config['data_deliver'],'report_data'),
        config_path = workflow.source_path(config['parameter']['RNAFlow_Deliver_Tool']['config_path_report']),
        source_dir = config['workflow'],
    log:
        "logs/delivery_report.log",
    benchmark:
        "benchmark/delivery_report.txt",
    threads:
        config['parameter']['threads']['rnaflow-cli'],
    shell:
        """
        ( rnaflow-cli deliver \
                    -d {params.source_dir} \
                    -o {params.out_dir} \
                    -c {params.config_path}  ) &>{log}
        """