#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import glob
from pathlib import Path
from typing import Dict, List, Union
from snakemake.io import expand


def qc_clean(samples: Dict = None, data_deliver: List = None) -> List:
    """
    Handle quality control and cleaning steps.

    Args:
        samples: Dictionary of sample information
        data_deliver: List of deliverable files to extend

    Returns:
        Updated list of deliverable files
    """
    if samples is None:
        samples = {}
    if data_deliver is None:
        data_deliver = []

    # fastq-screen
    data_deliver.extend(expand("01.qc/fastq_screen_r1/{sample}_R1_screen.txt", sample=samples.keys()))
    data_deliver.extend(expand("01.qc/fastq_screen_r2/{sample}_R2_screen.txt", sample=samples.keys()))
    data_deliver.append("01.qc/fastq_screen_multiqc_r1/multiqc_r1_fastq_screen_report.html")
    data_deliver.append("01.qc/fastq_screen_multiqc_r2/multiqc_r2_fastq_screen_report.html")
    # fastqc & multiqc
    data_deliver.append("01.qc/short_read_r1_multiqc/multiqc_r1_raw-data_report.html")
    data_deliver.append("01.qc/short_read_r2_multiqc/multiqc_r2_raw-data_report.html")
    # short-read trim & clean result
    data_deliver.append("01.qc/multiqc_short_read_trim/multiqc_short_read_trim_report.html")
    # merge qc
    data_deliver.append("01.qc/multiqc_merge_qc/multiqc_merge_qc_report.html")
    return data_deliver


def mapping(samples: Dict = None, data_deliver: List = None, config: Dict = None) -> List:
    """
    Handle sequence alignment and related outputs.

    Args:
        samples: Dictionary of sample information
        data_deliver: List of deliverable files to extend
        config: Configuration dictionary containing parameters

    Returns:
        Updated list of deliverable files
    """
    if samples is None:
        samples = {}
    if data_deliver is None:
        data_deliver = []
    if config is None:
        config = {}

    # mapping
    data_deliver.extend(expand("02.mapping/STAR/sort_index/{sample}.sort.bam", sample=samples.keys()))
    data_deliver.extend(expand("02.mapping/STAR/sort_index/{sample}.sort.bam.bai", sample=samples.keys()))
    data_deliver.extend(expand("02.mapping/samtools_flagstat/{sample}_bam_flagstat.tsv", sample=samples.keys()))
    data_deliver.extend(expand("02.mapping/samtools_stats/{sample}_bam_stats.tsv", sample=samples.keys()))
    data_deliver.extend(expand("02.mapping/qualimap_report/{sample}/qualimapReport.html", sample=samples.keys()))
    data_deliver.extend(expand("02.mapping/qualimap_report/{sample}/genome_results.txt", sample=samples.keys()))
    data_deliver.extend(expand('02.mapping/cram/{sample}.cram',sample=samples.keys()))
    data_deliver.extend(expand('02.mapping/cram/{sample}.cram.crai',sample=samples.keys()))
    data_deliver.append('02.mapping/cram/reference_version.txt')
    # bamcoverage - need to handle config parameter properly
    normalize_method = config.get('parameter', {}).get('bamCoverage', {}).get('normalizeUsing', 'RPKM')
    # Create file paths dynamically since expand doesn't support variable substitution in the middle of the string
    for sample in samples.keys():
        data_deliver.append(f"02.mapping/bamCoverage/{sample}_{normalize_method}.bw")

    data_deliver.append("02.mapping/mapping_report/multiqc_mapping_report.html")
    return data_deliver


def count(samples: Dict = None, data_deliver: List = None) -> List:
    """
    Handle gene expression quantification.

    Args:
        samples: Dictionary of sample information
        data_deliver: List of deliverable files to extend

    Returns:
        Updated list of deliverable files
    """
    if samples is None:
        samples = {}
    if data_deliver is None:
        data_deliver = []

    # count
    data_deliver.extend(expand("03.count/rsem/{sample}.genes.results", sample=samples.keys()))
    data_deliver.extend(expand("03.count/rsem/{sample}.isoforms.results", sample=samples.keys()))
    data_deliver.append("03.count/multiqc_rsem_report.html")
    data_deliver.append("03.count/merge_rsem_tpm.tsv")
    data_deliver.append("03.count/merge_rsem_counts.tsv")
    data_deliver.append("03.count/merge_rsem_fpkm.tsv")
    data_deliver.append("03.count/rsem_ultimate/")
    return data_deliver


def Deg(samples: Dict = None, data_deliver: List = None) -> List:
    """
    Handle differential expression analysis.

    Args:
        samples: Dictionary of sample information
        data_deliver: List of deliverable files to extend

    Returns:
        Updated list of deliverable files
    """
    if samples is None:
        samples = {}
    if data_deliver is None:
        data_deliver = []

    data_deliver.append("06.DEG/DESEQ2")
    # Gene_Expression_Distribution
    data_deliver.append('06.DEG/Gene_Expression/Gene_Expression_Distribution.pdf')
    data_deliver.append('06.DEG/Gene_Expression/Gene_Expression_Distribution.png')
    # heatmap
    data_deliver.append('06.DEG/Heatmap_tpm/Heatmap_TopVar.pdf')
    data_deliver.append('06.DEG/Heatmap_tpm/Heatmap_TopVar.png')
    data_deliver.append('06.DEG/Heatmap_fpkm/Heatmap_TopVar.pdf')
    data_deliver.append('06.DEG/Heatmap_fpkm/Heatmap_TopVar.png')
    data_deliver.append("07.Enrichments/")
    return data_deliver


def call_variant(samples: Dict = None, data_deliver: List = None) -> List:
    """
    Handle variant calling analysis.

    Args:
        samples: Dictionary of sample information
        data_deliver: List of deliverable files to extend

    Returns:
        Updated list of deliverable files
    """
    if samples is None:
        samples = {}
    if data_deliver is None:
        data_deliver = []

    data_deliver.extend(expand("04.variant/gatk/{sample}/{sample}.final.pass.vcf", sample=samples.keys()))
    data_deliver.extend(expand("04.variant/gatk/{sample}/{sample}.final.pass.vcf.idx", sample=samples.keys()))
    data_deliver.extend(expand("04.variant/gatk_bcftools_stats_raw/{sample}.raw_variants.stats", sample=samples.keys()))
    data_deliver.extend(expand("04.variant/gatk_bcftools_stats_pass/{sample}.final.pass.stats", sample=samples.keys()))
    data_deliver.append('04.variant/multiqc_gatk_bcftools_stats_raw/multiqc_gatk_bcftools_stats_raw.html')
    data_deliver.append('04.variant/multiqc_gatk_bcftools_stats_pass/multiqc_gatk_bcftools_stats_pass.html')
    return data_deliver


def noval_Transcripts(samples: Dict = None, data_deliver: List = None) -> List:
    """
    Handle novel transcript discovery.

    Args:
        samples: Dictionary of sample information
        data_deliver: List of deliverable files to extend

    Returns:
        Updated list of deliverable files
    """
    if samples is None:
        samples = {}
    if data_deliver is None:
        data_deliver = []

    data_deliver.append("05.assembly/filter/novel_transcripts.gtf")
    data_deliver.append("05.assembly/filter/final_Novel_Isoforms.gtf")
    return data_deliver


def rmats(samples: Dict = None, data_deliver: List = None, all_contrasts: List = None) -> List:
    """
    Handle alternative splicing analysis with rMATS.

    Args:
        samples: Dictionary of sample information
        data_deliver: List of deliverable files to extend
        all_contrasts: List of all contrasts for pairwise comparisons

    Returns:
        Updated list of deliverable files
    """
    if samples is None:
        samples = {}
    if data_deliver is None:
        data_deliver = []
    if all_contrasts is None:
        # In Snakemake context, ALL_CONTRASTS should be defined globally
        # For now, we'll use an empty list, but this should be passed from the main script
        all_contrasts = []

    # rmats single sample
    data_deliver.extend(expand("07.AS/rmats_single/{sample}/SE.MATS.JC.txt", sample=samples.keys()))
    data_deliver.extend(expand("07.AS/rmats_single/{sample}/MXE.MATS.JC.txt", sample=samples.keys()))
    data_deliver.extend(expand("07.AS/rmats_single/{sample}/summary.txt", sample=samples.keys()))
    data_deliver.append("07.AS/rmats_single/rmats_detail.txt")
    data_deliver.append("07.AS/rmats_single/rmats_summary.txt")
    # rmats pair sample
    if all_contrasts:  # Only add contrast-related outputs if contrasts are provided
        data_deliver.extend(expand("07.AS/rmats_pair/{contrast}/summary.txt", contrast=all_contrasts))
        data_deliver.extend(expand("07.AS/rmats_pair/{contrast}/SE.MATS.JC.txt", contrast=all_contrasts))
        data_deliver.append("07.AS/rmats_pair/rmats_detail.txt")
        data_deliver.append("07.AS/rmats_pair/rmats_summary.txt")
    return data_deliver