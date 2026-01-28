#!/usr/bin/snakemake
# -*- coding: utf-8 -*-
"""
RNAFlow Pipeline - RNA-seq Mapping and Post-Alignment Processing Module

This module handles the core alignment step using STAR (Spliced Transcripts
Alignment to a Reference) and performs comprehensive post-alignment processing
including quality control, format conversion, and coverage analysis.

Key Components:
- STAR_mapping: Primary alignment with comprehensive parameter tuning
- sort_index: BAM sorting and indexing for downstream analysis
- Quality Control: Multiple QC metrics using Qualimap, Samtools, and Preseq
- Format Conversion: BAM to CRAM compression for storage efficiency
- Coverage Analysis: BigWig generation for visualization
- Report Aggregation: MultiQC report generation for comprehensive QC summary

The module is designed to handle both standard RNA-seq and specialized analyses
like fusion detection (via chimeric read output) and transcriptome quantification.
"""

import os

rule STAR_mapping:
    """
    Perform spliced alignment of RNA-seq reads using STAR aligner.

    This rule executes the primary alignment step with optimized parameters for
    RNA-seq data, including:
    - Two-pass mode for improved splice junction detection
    - Chimeric read detection for fusion analysis
    - Transcriptome-aligned BAM generation for quantification
    - Comprehensive quality filtering and alignment parameters

    The rule outputs coordinate-sorted BAM files, transcriptome-aligned BAM files,
    and detailed alignment statistics in the Log.final.out file.
    """
    input:
        idx_dir = config['STAR_index'][config['Genome_Version']]['index'],
        genome_fa = config['STAR_index'][config['Genome_Version']]['genome_fa'],
        genome_gtf = config['STAR_index'][config['Genome_Version']]['genome_gtf'],
        r1 = "01.qc/short_read_trim/{sample}.R1.trimed.fq.gz",
        r2 = "01.qc/short_read_trim/{sample}.R2.trimed.fq.gz",
    output:
        Aligned_bam =  temp('02.mapping/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam'),
        Transcriptome_bam = temp('02.mapping/STAR/{sample}/{sample}.Aligned.toTranscriptome.out.bam'),
        log_final = '02.mapping/STAR/{sample}/{sample}.Log.final.out',
    resources:
        **rule_resource(config, 'high_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/star.yml"),
    log:
        "logs/02.mapping/STAR_{sample}.log",
    message:
        "Running STAR mapping on {wildcards.sample} R1 and R2",
    benchmark:
        "benchmarks/{sample}_STAR_benchmark.txt",
    params:
        Prefix = '02.mapping/STAR/{sample}/{sample}.',
        platform = config['parameter']["STAR"]["PL"],
        sample = '{sample}',
    threads:
        config['parameter']['threads']['STAR_MAPPING'],
    shell:
        """
        ulimit -n 65535 && STAR --runMode alignReads \
            --genomeDir {input.idx_dir} \
            --genomeLoad NoSharedMemory  \
            --runThreadN {threads} \
            --sjdbGTFfile {input.genome_gtf} \
            --twopassMode Basic \
            --peOverlapNbasesMin 12  \
            --peOverlapMMp 0.1  \
            --readFilesCommand zcat \
            --readFilesType Fastx \
            --readFilesIn {input.r1} {input.r2} \
            --outFileNamePrefix  {params.Prefix} \
            --outReadsUnmapped Fastx \
            --outSAMtype BAM SortedByCoordinate \
            --outSAMunmapped Within \
            --outSAMattrRGline ID:{params.sample} SM:{params.sample} PL:{params.platform} \
            --outSAMmapqUnique 255  \
            --outSAMstrandField intronMotif \
            --outWigType bedGraph \
            --outWigStrand Stranded \
            --outWigNorm RPM \
            --outStd  Log  \
            --outFilterType BySJout \
            --outFilterMismatchNmax 999 \
            --outFilterMismatchNoverLmax 0.04 \
            --outFilterMultimapNmax 20 \
            --outFilterMatchNminOverLread 0.66 \
            --outFilterIntronMotifs None \
            --outSJfilterReads All \
            --quantMode TranscriptomeSAM \
            --quantTranscriptomeSAMoutput BanSingleEnd_BanIndels_ExtendSoftclip \
            --alignIntronMin 20  \
            --alignIntronMax 1000000  \
            --alignMatesGapMax 1000000  \
            --alignSJoverhangMin 5  \
            --alignSJDBoverhangMin 3  \
            --alignSJstitchMismatchNmax 5 -1 5 5  \
            --chimOutType Junctions  \
            --chimOutJunctionFormat 1  \
            --chimSegmentMin 12  \
            --chimJunctionOverhangMin 12  \
            --chimMultimapScoreRange 10  \
            --chimMultimapNmax 10  \
            --chimNonchimScoreDropMin 10  \
            --chimScoreMin 0 \
            --chimScoreDropMax 20 \
            --chimScoreSeparation 10 \
            --chimScoreJunctionNonGTAG -1  &> {log}
        """

rule sort_index:
    """
    Sort and index aligned BAM files for efficient downstream processing.

    This rule renames the coordinate-sorted BAM file from STAR's output and
    generates a corresponding BAI index file using samtools. The sorted BAM
    files are essential for most downstream analyses including variant calling,
    coverage analysis, and visualization.
    """
    input:
        Aligned_bam = '02.mapping/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam',
        Transcriptome_bam = '02.mapping/STAR/{sample}/{sample}.Aligned.toTranscriptome.out.bam',
    output:
        sort_bam = temp('02.mapping/STAR/sort_index/{sample}.sort.bam'),
        sort_bam_bai = '02.mapping/STAR/sort_index/{sample}.sort.bam.bai',
    resources:
        **rule_resource(config, 'high_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/bwa2.yaml"),
    message:
        "Running samtools sort & index for {wildcards.sample}",
    log:
        "logs/02.mapping/bwa_sort_index_{sample}.log",
    benchmark:
            "benchmarks/{sample}_bam_sort_index_benchmark.txt",
    threads:
        config['parameter']['threads']['samtools'],
    shell:
        """
        ( samtools sort -@ {threads} {input.Aligned_bam} -o {output.sort_bam}
        samtools index -@ {threads} {output.sort_bam})  &>{log}
        """

# rule estimate_library_complexity:
#    """
#    Estimate library complexity using Preseq.
#
#    This rule uses Preseq to predict the complexity of the sequencing library
#    by estimating how many additional unique reads would be observed if more
#    sequencing were performed. This helps assess whether the current sequencing
#    depth is sufficient or if additional sequencing would yield diminishing returns.
#
#    Outputs two files:
#    - lc_extrap.txt: Library complexity extrapolation predictions
#    - c_curve.txt: Complexity curve showing observed vs. predicted unique reads
#    """
#    input:
#        sort_bam = '02.mapping/STAR/sort_index/{sample}.sort.bam',
#        sort_bam_bai = '02.mapping/STAR/sort_index/{sample}.sort.bam.bai',
#    output:
#        preseq = '02.mapping/preseq/{sample}.lc_extrap.txt',
#        c_curve = '02.mapping/preseq/{sample}.c_curve.txt',
#    resources:
#        **rule_resource(config, 'low_resource', skip_queue_on_local=True, logger=logger),
#    conda:
#        workflow.source_path("../envs/Preseq.yaml"),
#    message:
#        "Running Preseq for {wildcards.sample}",
#    log:
#        "logs/02.mapping/preseq_{sample}.log",
#    benchmark:
#        "benchmarks/{sample}_preseq_benchmark.txt",
#    threads:
#        1
#    shell:
#        """
#        exec 2> {log}
#        set -x
#        preseq lc_extrap -pe -v -output {output.preseq} -B {input.sort_bam}
#        preseq c_curve -pe -v -output {output.c_curve} -B  {input.sort_bam}
#        """

rule qualimap_qc:
    """
    Perform comprehensive BAM quality control using Qualimap.

    This rule runs Qualimap's bamqc module to generate detailed quality metrics
    including coverage distribution, insert size distribution, GC content bias,
    and mapping quality statistics. The output includes both HTML reports for
    visual inspection and text files for programmatic analysis.
    """
    input:
        bam = '02.mapping/STAR/sort_index/{sample}.sort.bam',
        bai = '02.mapping/STAR/sort_index/{sample}.sort.bam.bai'
    output:
        qualimap_report_html = '02.mapping/qualimap_report/{sample}/qualimapReport.html',
        qualimap_report_txt = '02.mapping/qualimap_report/{sample}/genome_results.txt',
    resources:
        **rule_resource(config, 'medium_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/qualimap.yaml"),
    message:
        "Running qualimap qc for MarkDuplicates of BAM : {input.bam}",
    log:
        "logs/02.mapping/qualimap_report_{sample}.log",
    benchmark:
        "benchmarks/{sample}_Dup_bam_qualimap_benchmark.txt",
    params:
        genome_gff = config['STAR_index'][config['Genome_Version']]['genome_gtf'],
        outformat = config['parameter']['qualimap']["format"],
        mem = config['parameter']['qualimap']["mem"],
        prefix_dir = '02.mapping/qualimap_report/{sample}/',
    threads:
        config['parameter']["threads"]["qualimap"],
    shell:
        """
        qualimap bamqc \
                 -nt {threads} \
                 -bam {input.bam} \
                 -gff {params.genome_gff} \
                 -outdir {params.prefix_dir} \
                 -outformat {params.outformat} \
                 --java-mem-size=16G &> {log}
        """

rule samtools_flagst:
    """
    Generate alignment statistics using samtools flagstat.

    This rule produces a tab-separated summary of alignment metrics including
    total reads, mapped reads, properly paired reads, and various quality
    categories. The TSV format makes it easy to parse programmatically for
    downstream analysis and reporting.
    """
    input:
        bam = '02.mapping/STAR/sort_index/{sample}.sort.bam',
        bai = '02.mapping/STAR/sort_index/{sample}.sort.bam.bai'
    output:
        samtools_flagstat = '02.mapping/samtools_flagstat/{sample}_bam_flagstat.tsv',
    resources:
        **rule_resource(config, 'medium_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/bwa2.yaml"),
    message:
        "Running flagst for MarkDuplicates of BAM : {input.bam}",
    log:
        "logs/02.mapping/bam_dup_lagstat_{sample}.log",
    benchmark:
        "benchmarks/{sample}_Dup_bam_lagstat_benchmark.txt",
    threads:
        config['parameter']["threads"]["samtools_flagstat"],
    shell:
        """
        samtools flagstat \
                 -@ {threads} \
                 -O tsv \
                 {input.bam} > {output.samtools_flagstat} 2>{log}
        """

rule samtools_stats:
    """
    Generate comprehensive alignment statistics using samtools stats.

    This rule provides detailed alignment statistics including base quality
    distributions, insert size metrics, coverage statistics, and error rates.
    The comprehensive output is useful for deep quality assessment and
    troubleshooting alignment issues.
    """
    input:
        bam = '02.mapping/STAR/sort_index/{sample}.sort.bam',
        bai = '02.mapping/STAR/sort_index/{sample}.sort.bam.bai'
    output:
        samtools_stats = '02.mapping/samtools_stats/{sample}_bam_stats.tsv',
    resources:
        **rule_resource(config, 'medium_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/bwa2.yaml"),
    message:
        "Running stats for MarkDuplicates of BAM : {input.bam}",
    log:
        "logs/02.mapping/bam_dup_stats_{sample}.log",
    benchmark:
        "benchmarks/{sample}_Dup_bam_stats_benchmark.txt",
    threads:
        config['parameter']['threads']['samtools_stats'],
    params:
        reference = config['STAR_index'][config['Genome_Version']]['genome_fa'],
    shell:
        """
        samtools stats \
                 -@ {threads} \
                 --reference {params.reference} \
                 {input.bam} > {output.samtools_stats}  2>{log}
        """

rule bam2cram:
    """
    Convert BAM files to CRAM format for storage efficiency.

    This rule compresses the sorted BAM files into CRAM format, which typically
    achieves 40-60% smaller file sizes compared to BAM while maintaining full
    compatibility with most bioinformatics tools. The CRAM format uses reference-
    based compression, making it ideal for large-scale RNA-seq projects where
    storage costs are a concern.
    """
    input:
        bam = '02.mapping/STAR/sort_index/{sample}.sort.bam',
        bai = '02.mapping/STAR/sort_index/{sample}.sort.bam.bai'
    output:
        cram = '02.mapping/cram/{sample}.cram',
        cram_index = '02.mapping/cram/{sample}.cram.crai',
    resources:
        **rule_resource(config, 'medium_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/bwa2.yaml"),
    message:
        "Running bam compress of BAM : {input.bam}",
    log:
        "logs/02.mapping/bam_dup_stats_{sample}.log",
    benchmark:
        "benchmarks/{sample}_Dup_bam_stats_benchmark.txt",
    threads:
        config['parameter']['threads']['bam2cram'],
    params:
        reference = config['STAR_index'][config['Genome_Version']]['genome_fa'],
    shell:
        """
        samtools view -@ {threads} -C -T {params.reference} -o {output.cram} {input.bam}
        samtools index  -@ {threads} {output.cram}
        """

rule record_ref_metadata:
    """
    Record reference genome metadata for reproducibility.

    This rule creates a text file containing essential reference genome
    information including the genome version, FASTA file path, and sequence
    dictionary information. This metadata is crucial for ensuring reproducibility
    and proper interpretation of results across different analysis runs.
    """
    input:
        ref = config['STAR_index'][config['Genome_Version']]['genome_fa'],
    output:
        ref_info = '02.mapping/cram/reference_version.txt',
    resources:
        **rule_resource(config, 'low_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/bwa2.yaml"),
    log:
        "logs/02.mapping/cram_reference.log",
    benchmark:
        "benchmarks/cram_reference_benchmark.txt",
    threads:
        1
    shell:
        """
        echo "Genome_Version: {config[Genome_Version]}" > {output.ref_info}
        echo "Fasta_Path: {input.ref}" >> {output.ref_info}
        samtools dict  {input.ref} | grep '^@SQ' >> {output.ref_info}
        """

rule bamCoverage:
    """
    Generate normalized coverage tracks in BigWig format for visualization.

    This rule uses deeptools bamCoverage to create normalized coverage tracks
    that can be visualized in genome browsers like IGV or UCSC Genome Browser.
    The normalization method (typically RPKM, CPM, or BPM) ensures that coverage
    tracks are comparable across samples with different sequencing depths.
    """
    input:
        bam = '02.mapping/STAR/sort_index/{sample}.sort.bam',
        bai = '02.mapping/STAR/sort_index/{sample}.sort.bam.bai'
    output:
        bw = f"02.mapping/bamCoverage/{{sample}}_{config['parameter']['bamCoverage']['normalizeUsing']}.bw"
    resources:
        **rule_resource(config, 'high_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/deeptools.yaml"),
    message:
        "Running bamCoverage (bigwig generation) for {input.bam}"
    log:
        "logs/02.mapping/bamCoverage_{sample}.log",
    benchmark:
        "benchmarks/{sample}_bamCoverage_benchmark.txt",
    threads:
        config['parameter']['threads']['bamCoverage'],
    params:
        binSize = config['parameter']['bamCoverage']['binSize'],
        smoothLength = config['parameter']['bamCoverage']['smoothLength'],
        normalizeUsing = config['parameter']['bamCoverage']['normalizeUsing'],
    shell:
        """
        bamCoverage -p {threads} \
                    --bam {input.bam} \
                    --binSize {params.binSize} \
                    --centerReads \
                    --smoothLength {params.smoothLength} \
                    --normalizeUsing {params.normalizeUsing} \
                    -o {output.bw} \
                    &> {log}
        """

rule mapping_report:
    """
    Aggregate all mapping QC results into a comprehensive MultiQC report.

    This rule collects QC metrics from all previous mapping-related rules
    (STAR, Qualimap, Samtools, Preseq) and generates a unified HTML report
    using MultiQC. The aggregated report provides a single dashboard for
    assessing the quality of all samples in the RNA-seq experiment, making
    it easy to identify potential issues or outliers.
    """
    input:
        log_final = expand('02.mapping/STAR/{sample}/{sample}.Log.final.out',sample=samples.keys()),
        qualimap_report_html = expand('02.mapping/qualimap_report/{sample}/qualimapReport.html',sample=samples.keys()),
        qualimap_report_txt = expand('02.mapping/qualimap_report/{sample}/genome_results.txt',sample=samples.keys()),
        samtools_flagstat = expand('02.mapping/samtools_flagstat/{sample}_bam_flagstat.tsv',sample=samples.keys()),
        samtools_stats = expand('02.mapping/samtools_stats/{sample}_bam_stats.tsv',sample=samples.keys()),
        # preseq = expand('02.mapping/preseq/{sample}.lc_extrap.txt',sample=samples.keys()),
        # c_curve = expand('02.mapping/preseq/{sample}.c_curve.txt',sample=samples.keys()),
    output:
        report = "02.mapping/mapping_report/multiqc_mapping_report.html",
    resources:
        **rule_resource(config, 'low_resource',skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/multiqc.yaml"),
    message:
        "Running MultiQC to aggregate mapping reports",
    params:
        fastqc_reports = "02.mapping/",
        report_dir = '02.mapping/mapping_report',
        report = "multiqc_mapping_report.html",
        title = "mapping_report",
    log:
        "logs/02.mapping/multiqc_mapping_report.log",
    benchmark:
        "benchmarks/multiqc_mapping_report_benchmark.txt",
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