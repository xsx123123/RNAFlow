#!/usr/bin/snakemake
# -*- coding: utf-8 -*-
"""
RNAFlow Pipeline - RNA-seq Variant Calling Module

This module implements a comprehensive variant calling pipeline for RNA-seq data
using GATK (Genome Analysis Toolkit) best practices adapted for RNA-seq analysis.

Key Components:
- Reference preparation: Creating sequence dictionary and FASTA index
- BAM preprocessing: Read group assignment, duplicate marking, and N-cigar splitting
- Variant calling: HaplotypeCaller for SNP and indel detection
- Variant filtering: Quality-based filtering using RNA-seq specific parameters
- Quality control: Comprehensive statistics and MultiQC reporting

The pipeline follows GATK's recommended RNA-seq variant calling workflow, which includes
special handling for spliced reads and RNA-specific artifacts. This is particularly
important for detecting variants in expressed regions and can be used for applications
like somatic mutation detection in cancer RNA-seq or population genetics studies.
"""

def get_java_opts(wildcards, input, resources):
    """
    Calculate appropriate Java memory options based on available resources.

    This function dynamically adjusts the Java heap size by subtracting 4GB from
    the allocated memory (to leave room for system overhead) with a minimum of 2GB.
    It also configures parallel garbage collection for better performance.

    Args:
        wildcards: Snakemake wildcards object
        input: Rule input files
        resources: Allocated computational resources

    Returns:
        str: Java command line options string
    """
    mem_gb = max(int(resources.mem_mb / 1024) - 4, 2)
    return f"-Xmx{mem_gb}g -XX:+UseParallelGC -XX:ParallelGCThreads=4"

rule CreateRefIndex:
    """
    Create reference genome index files required for GATK processing.

    This rule generates two essential reference files:
    - .dict: Sequence dictionary containing chromosome metadata
    - .fai: FASTA index for rapid sequence access

    These files are prerequisites for most GATK tools and ensure proper
    reference handling throughout the variant calling pipeline.
    """
    input:
        fasta = config['STAR_index'][config['Genome_Version']]['genome_fa'],
    output:
        dict = os.path.splitext(config['STAR_index'][config['Genome_Version']]['genome_fa'])[0] + ".dict",
        fai = config['STAR_index'][config['Genome_Version']]['genome_fa'] + ".fai",
    resources:
        **rule_resource(config, 'medium_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/gatk.yaml")
    log:
        "logs/00.prepare/create_ref_index.log"
    shell:
        """
        gatk CreateSequenceDictionary -R {input.fasta} -O {output.dict} > {log} 2>&1

        samtools faidx {input.fasta} >> {log} 2>&1
        """

rule AddOrReplaceReadGroups:
    """
    Add or replace read group information in BAM files.

    Read groups are essential metadata that identify the sequencing run, library,
    platform, and sample information. GATK requires properly formatted read groups
    for accurate variant calling. This rule assigns standardized read group tags:
    - ID: Run identifier (set to "1")
    - LB: Library identifier (set to "lib1")
    - PL: Platform (set to "illumina")
    - PU: Platform unit (set to "unit1")
    - SM: Sample name (from wildcard)

    The output BAM is coordinate-sorted and indexed for downstream processing.
    """
    input:
        bam = '02.mapping/STAR/sort_index/{sample}.sort.bam',
        bai = '02.mapping/STAR/sort_index/{sample}.sort.bam.bai',
    output:
        bam = temp('04.variant/gatk/{sample}/{sample}.rg.bam'),
        bai = temp('04.variant/gatk/{sample}/{sample}.rg.bai')
    conda:
        workflow.source_path("../envs/gatk.yaml")
    log:
        "logs/04.variant/gatk/AddRG/{sample}.log"
    benchmark:
        "benchmarks/04.variant/gatk/AddRG/{sample}.txt"
    resources:
        **rule_resource(config, 'medium_resource',  skip_queue_on_local=True,logger = logger),
    threads: 1
    params:
        java_opts = get_java_opts
    shell:
        """
        gatk --java-options "{params.java_opts}" AddOrReplaceReadGroups \
             -I {input.bam} \
             -O {output.bam} \
             -SO coordinate \
             -ID 1 -LB lib1 \
             -PL illumina -PU unit1 \
             -SM {wildcards.sample} \
             --CREATE_INDEX true 2> {log}
        """

rule MarkDuplicates:
    """
    Identify and mark PCR/optical duplicates in BAM files.

    Duplicate marking is crucial for variant calling as PCR duplicates can create
    false positive variant calls by artificially inflating coverage at specific
    positions. This rule uses GATK's MarkDuplicates tool to identify duplicates
    based on alignment coordinates and orientation, then marks them in the BAM
    file rather than removing them (preserving data for potential re-analysis).

    The rule outputs both the marked BAM file and a metrics file containing
    duplicate statistics for quality assessment.
    """
    input:
        bam = '04.variant/gatk/{sample}/{sample}.rg.bam',
    output:
        bam = temp('04.variant/gatk/{sample}/{sample}.rg.dedup.bam'),
        metrics = '04.variant/gatk_MarkDuplicates/{sample}.rg.dedup.metrics.txt',
    resources:
        **rule_resource(config, 'high_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/gatk.yaml")
    log:
        "logs/04.variant/gatk/MarkDup/{sample}.log"
    benchmark:
        "benchmarks/04.variant/gatk/MarkDup/{sample}.txt"
    threads: 2
    params:
        java_opts = get_java_opts
    shell:
        """
        gatk --java-options "{params.java_opts}" MarkDuplicates \
             -I {input.bam} \
             -O {output.bam} \
             -M {output.metrics} \
             --CREATE_INDEX true \
             --MAX_RECORDS_IN_RAM 5000000 \
             --SORTING_COLLECTION_SIZE_RATIO 0.5 2> {log}
        """

rule SplitNCigarReads:
    """
    Split reads into exon segments and hard-clip overhanging intronic sequences.

    This RNA-seq specific preprocessing step is critical for accurate variant calling
    in spliced regions. RNA-seq reads often span exon-exon junctions, represented as
    N-cigars in BAM files. However, variant callers like HaplotypeCaller cannot handle
    these N-cigars properly.

    SplitNCigarReads splits each read into separate exon segments and hard-clips any
    overhanging sequences that extend into intronic regions. This transforms the BAM
    into a format suitable for DNA-based variant callers while preserving the essential
    exonic information needed for variant detection.
    """
    input:
        bam = '04.variant/gatk/{sample}/{sample}.rg.dedup.bam',
        ref_dict = os.path.splitext(config['STAR_index'][config['Genome_Version']]['genome_fa'])[0] + ".dict",
        ref_fai = config['STAR_index'][config['Genome_Version']]['genome_fa'] + ".fai",
    output:
        bam = '04.variant/gatk/{sample}/{sample}.rg.dedup.split.bam',
        bai = '04.variant/gatk/{sample}/{sample}.rg.dedup.split.bai',
    resources:
        **rule_resource(config, 'high_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/gatk.yaml")
    log:
        "logs/04.variant/gatk/SplitN/{sample}.log"
    benchmark:
        "benchmarks/04.variant/gatk/SplitN/{sample}.txt"
    threads: 4
    params:
        fasta = config['STAR_index'][config['Genome_Version']]['genome_fa'],
        java_opts = get_java_opts
    shell:
        """
        gatk --java-options "{params.java_opts}" SplitNCigarReads \
             -R {params.fasta} \
             -I {input.bam} \
             -O {output.bam} 2> {log}
        """

rule HaplotypeCaller:
    """
    Perform local de-novo assembly and variant calling using GATK HaplotypeCaller.

    HaplotypeCaller is GATK's primary variant caller that uses a sophisticated
    local assembly approach to detect SNPs and small indels. For RNA-seq data,
    it's configured with RNA-specific parameters:
    - --dont-use-soft-clipped-bases: Avoids using soft-clipped bases which are
      common in RNA-seq due to splicing and can introduce false positives
    - --standard-min-confidence-threshold-for-calling: Sets minimum confidence
      threshold (20) for variant calling
    - Ploidy setting: Configurable based on organism (diploid, haploid, etc.)

    The output is a raw VCF file containing all candidate variants before filtering.
    """
    input:
        bam = '04.variant/gatk/{sample}/{sample}.rg.dedup.split.bam',
        bai = '04.variant/gatk/{sample}/{sample}.rg.dedup.split.bai',
        ref_dict = os.path.splitext(config['STAR_index'][config['Genome_Version']]['genome_fa'])[0] + ".dict",
        ref_fai = config['STAR_index'][config['Genome_Version']]['genome_fa'] + ".fai",
    output:
        vcf = '04.variant/gatk/{sample}/{sample}.raw_variants.vcf',
        idx = '04.variant/gatk/{sample}/{sample}.raw_variants.vcf.idx'
    resources:
        **rule_resource(config, 'high_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/gatk.yaml")
    log:
        "logs/04.variant/gatk/HC/{sample}.log"
    benchmark:
        "benchmarks/04.variant/gatk/HC/{sample}.txt"
    threads:
        config['parameter']['threads']['gatk']
    params:
        fasta = config['STAR_index'][config['Genome_Version']]['genome_fa'],
        ploidy = config['ploidy_setting'][config['Genome_Version']]['ploidy'],
        java_opts = get_java_opts
    shell:
        """
        gatk --java-options "{params.java_opts}" HaplotypeCaller \
             -R {params.fasta} \
             -I {input.bam} \
             -O {output.vcf} \
             -ploidy {params.ploidy} \
             --dont-use-soft-clipped-bases \
             --standard-min-confidence-threshold-for-calling 20 \
             --native-pair-hmm-threads {threads} 2> {log}
        """

rule VariantFiltration:
    """
    Apply quality-based filters to raw variant calls using RNA-seq specific criteria.

    This rule implements GATK's recommended RNA-seq variant filtering strategy,
    which uses different thresholds than DNA-seq due to the unique characteristics
    of RNA-seq data:
    - FS (FisherStrand): Filter variants with strand bias > threshold (typically 30.0)
    - QD (QualByDepth): Filter variants with low quality-to-depth ratio < threshold
      (typically 2.0)

    The filtering uses sliding window and cluster-based approaches to account for
    RNA-seq specific artifacts like mapping errors near splice junctions.
    """
    input:
        vcf = '04.variant/gatk/{sample}/{sample}.raw_variants.vcf',
        idx = '04.variant/gatk/{sample}/{sample}.raw_variants.vcf.idx',
        ref_dict = os.path.splitext(config['STAR_index'][config['Genome_Version']]['genome_fa'])[0] + ".dict",
        ref_fai = config['STAR_index'][config['Genome_Version']]['genome_fa'] + ".fai",
    output:
        vcf = '04.variant/gatk/{sample}/{sample}.filtered.vcf',
        idx = '04.variant/gatk/{sample}/{sample}.filtered.vcf.idx'
    resources:
        **rule_resource(config, 'medium_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/gatk.yaml")
    log:
        "logs/04.variant/gatk/Filter/{sample}.log"
    benchmark:
        "benchmarks/04.variant/gatk/Filter/{sample}.txt"
    threads: 1
    params:
        fasta = config['STAR_index'][config['Genome_Version']]['genome_fa'],
        java_opts = get_java_opts,
        win = config['parameter']['gatk']['filter']['rna_seq']['window_size'],
        clus = config['parameter']['gatk']['filter']['rna_seq']['cluster_size'],
        fs = config['parameter']['gatk']['filter']['rna_seq']['fs_threshold'],
        qd = config['parameter']['gatk']['filter']['rna_seq']['qd_threshold'],
    shell:
        """
        gatk --java-options "{params.java_opts}" VariantFiltration \
             -R {params.fasta} \
             -V {input.vcf} \
             -O {output.vcf} \
             --window {params.win} \
             --cluster {params.clus} \
             --filter-name "FS{params.fs}" --filter-expression "FS > {params.fs}" \
             --filter-name "QD{params.qd}" --filter-expression "QD < {params.qd}" 2> {log}
        """

rule SelectVariants:
    """
    Extract high-confidence PASS variants from filtered VCF files.

    This rule selects only variants that passed all quality filters (marked as PASS
    in the FILTER column) and excludes any variants that were flagged during the
    VariantFiltration step. The resulting VCF contains only high-confidence variants
    suitable for downstream analysis like annotation, functional prediction, or
    biological interpretation.
    """
    input:
        vcf = '04.variant/gatk/{sample}/{sample}.filtered.vcf',
        ref_dict = os.path.splitext(config['STAR_index'][config['Genome_Version']]['genome_fa'])[0] + ".dict",
        ref_fai = config['STAR_index'][config['Genome_Version']]['genome_fa'] + ".fai",
    output:
        vcf = '04.variant/gatk/{sample}/{sample}.final.pass.vcf',
        idx = '04.variant/gatk/{sample}/{sample}.final.pass.vcf.idx'
    resources:
        **rule_resource(config, 'medium_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/gatk.yaml")
    log:
        "logs/04.variant/gatk/Select/{sample}.log"
    benchmark:
        "benchmarks/04.variant/gatk/Select/{sample}.txt"
    threads: 1
    params:
        fasta = config['STAR_index'][config['Genome_Version']]['genome_fa'],
        java_opts = get_java_opts
    shell:
        """
        gatk --java-options "{params.java_opts}" SelectVariants \
             -R {params.fasta} \
             -V {input.vcf} \
             --exclude-filtered \
             -O {output.vcf} 2> {log}
        """

rule bcftools_stats_raw:
    """
    Generate comprehensive statistics for raw variant calls using bcftools.

    This rule uses bcftools stats to produce detailed quality metrics for the
    unfiltered variant calls, including:
    - Number of SNPs, indels, and multi-allelic sites
    - Transition/transversion ratios
    - Allele frequency distributions
    - Genotype quality distributions
    - Missing data statistics

    These statistics provide insights into the raw variant calling performance
    and help identify potential issues before filtering.
    """
    input:
        vcf = '04.variant/gatk/{sample}/{sample}.raw_variants.vcf',
        idx = '04.variant/gatk/{sample}/{sample}.raw_variants.vcf.idx',
    output:
        stats = '04.variant/gatk_bcftools_stats_raw/{sample}.raw_variants.stats'
    resources:
        **rule_resource(config, 'medium_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/bcftools.yaml"),
    params:
        fasta = config['STAR_index'][config['Genome_Version']]['genome_fa'],
    log:
        "logs/04.variant/gatk/bcftools_stats_raw/{sample}.log"
    benchmark:
        "benchmarks/04.variant/gatk/bcftools_stats_raw/{sample}.txt"
    threads:
        5
    shell:
        """
        bcftools stats --threads {threads} \
                       --fasta-ref {params.fasta} \
                        {input.vcf} > {output.stats} 2>{log}
        """


rule bcftools_stats_pass:
    """
    Generate comprehensive statistics for filtered PASS variants using bcftools.

    Similar to the raw statistics rule, this generates quality metrics specifically
    for the high-confidence PASS variants after filtering. Comparing these statistics
    with the raw variant statistics helps assess the effectiveness of the filtering
    process and provides final quality metrics for the variant calling pipeline.
    """
    input:
        vcf = '04.variant/gatk/{sample}/{sample}.final.pass.vcf',
        idx = '04.variant/gatk/{sample}/{sample}.final.pass.vcf.idx'
    output:
        stats = '04.variant/gatk_bcftools_stats_pass/{sample}.final.pass.stats'
    resources:
        **rule_resource(config, 'medium_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/bcftools.yaml"),
    params:
        fasta = config['STAR_index'][config['Genome_Version']]['genome_fa'],
    log:
        "logs/04.variant/gatk/bcftools_stats_pass/{sample}.log"
    benchmark:
        "benchmarks/04.variant/gatk/bcftools_stats_pass/{sample}.txt"
    threads:
        5
    shell:
        """
        bcftools stats --threads {threads} \
                       --fasta-ref {params.fasta} \
                        {input.vcf} > {output.stats} 2>{log}
        """

rule multiqc_bcftools_stats_raw:
    """
    Aggregate raw variant calling statistics into a comprehensive MultiQC report.

    This rule collects bcftools statistics from all samples for raw variant calls
    and generates a unified HTML report using MultiQC. The report provides
    sample-level and cross-sample comparisons of variant calling quality metrics,
    making it easy to identify outliers or systematic issues in the raw variant
    calling results.
    """
    input:
        stats = expand("04.variant/gatk_bcftools_stats_raw/{sample}.raw_variants.stats",
                            sample=samples.keys()),
    output:
        report = '04.variant/multiqc_gatk_bcftools_stats_raw/multiqc_gatk_bcftools_stats_raw.html',
    resources:
        **rule_resource(config, 'low_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/multiqc.yaml"),
    message:
        "Running MultiQC to aggregate gatk reports",
    benchmark:
        "benchmarks/multiqc_gatk_bcftools_stats_raw.txt",
    params:
        fastqc_reports = "04.variant/gatk_bcftools_stats_raw/",
        report_dir = "04.variant/multiqc_gatk_bcftools_stats_raw/",
        report = "multiqc_gatk_bcftools_stats_raw.html",
        title = "multiqc_gatk_bcftools_stats_raw",
    log:
        "logs/04.variant/multiqc_gatk_bcftools_stats_raw.log",
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

rule multiqc_bcftools_stats_pass:
    """
    Aggregate filtered PASS variant statistics into a comprehensive MultiQC report.

    This rule creates a MultiQC report specifically for the high-confidence PASS
    variants, providing the final quality assessment of the variant calling pipeline.
    This report is essential for validating that the filtering process successfully
    removed low-quality variants while retaining biologically relevant calls, and
    serves as the primary QC deliverable for variant calling results.
    """
    input:
        stats = expand("04.variant/gatk_bcftools_stats_pass/{sample}.final.pass.stats",
                            sample=samples.keys()),
    output:
        report = '04.variant/multiqc_gatk_bcftools_stats_pass/multiqc_gatk_bcftools_stats_pass.html',
    resources:
        **rule_resource(config, 'low_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/multiqc.yaml"),
    message:
        "Running MultiQC to aggregate gatk reports",
    benchmark:
        "benchmarks/multiqc_gatk_bcftools_stats_pass.txt",
    params:
        fastqc_reports = "04.variant/gatk_bcftools_stats_pass/",
        report_dir = "04.variant/multiqc_gatk_bcftools_stats_pass/",
        report = "multiqc_gatk_bcftools_stats_pass.html",
        title = "multiqc_gatk_bcftools_stats_pass",
    log:
        "logs/04.variant/multiqc_gatk_bcftools_stats_pass.log",
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