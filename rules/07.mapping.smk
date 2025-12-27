#!/usr/bin/snakemake
# -*- coding: utf-8 -*-
import os
from loguru import logger

rule build_STAR_index:
    input:
        genome_fa = config["parameter"]['star_index'][config['Genome_Version']]['genome_fa'],
        genome_gtf = config["parameter"]['star_index'][config['Genome_Version']]['genome_gtf']
    output:
        idx_dir = directory(config["parameter"]['star_index'][config['Genome_Version']]['index'])
    conda:
        workflow.source_path("../envs/star.yml")
    log:
        "logs/02.mapping/STAR_index.log"
    message:
        "Building STAR index for {input.genome_fa}"
    benchmark:
        "benchmarks/STAR_index_benchmark.txt"
    params:
        genomeDir = config["parameter"]['star_index'][config['Genome_Version']]['index']
    threads:
        config['parameter']['threads']['STAR_INDEX']
    shell:
        """
        mkdir -p {params.genomeDir} && \
        STAR --genomeSAindexNbases 12 \
             --runThreadN {threads} \
             --runMode genomeGenerate \
             --genomeDir {params.genomeDir} \
             --genomeFastaFiles {input.genome_fa} \
             --sjdbGTFfile {input.genome_gtf} \
             > {log} 2>&1
        """

rule STAR_mapping:
    input:
        idx_dir = config["parameter"]['star_index'][config['Genome_Version']]['index'],
        genome_fa = config["parameter"]['star_index'][config['Genome_Version']]['genome_fa'],
        genome_gtf = config["parameter"]['star_index'][config['Genome_Version']]['genome_gtf'],
        r1 = "01.qc/short_read_trim/{sample}.R1.trimed.fq.gz",
        r2 = "01.qc/short_read_trim/{sample}.R2.trimed.fq.gz",
    output:
        Aligned_bam = '02.mapping/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam',
        Transcriptome_bam = '02.mapping/STAR/{sample}/{sample}.Aligned.toTranscriptome.out.bam',
        log_final = '02.mapping/STAR/{sample}/{sample}.Log.final.out',
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
    input:
        Aligned_bam = '02.mapping/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam',
        Transcriptome_bam = '02.mapping/STAR/{sample}/{sample}.Aligned.toTranscriptome.out.bam',
    output:
        rename_bam = '02.mapping/STAR/sort_index/{sample}.bam',
        sort_bam = '02.mapping/STAR/sort_index/{sample}.sort.bam',
        sort_bam_bai = '02.mapping/STAR/sort_index/{sample}.sort.bam.bai',
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
        (mv {input.Aligned_bam} {output.rename_bam} &&
        samtools sort -@ {threads} -o {output.sort_bam} {output.rename_bam} &&
        samtools index -@ {threads} {output.sort_bam})  &>{log}
        """

rule qualimap_qc:
    input:
        bam = '02.mapping/STAR/sort_index/{sample}.sort.bam',
        bai = '02.mapping/STAR/sort_index/{sample}.sort.bam.bai'
    output:
        qualimap_report_html = '02.mapping/qualimap_report/{sample}/qualimapReport.html',
        qualimap_report_txt = '02.mapping/qualimap_report/{sample}/genome_results.txt',
    conda:
        workflow.source_path("../envs/qualimap.yaml"),
    message:
        "Running qualimap qc for MarkDuplicates of BAM : {input.bam}",
    log:
        "logs/02.mapping/qualimap_report_{sample}.log",
    benchmark:
        "benchmarks/{sample}_Dup_bam_qualimap_benchmark.txt",
    params:
        genome_gff = config['parameter']['qualimap']["genome_gff"],
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
    input:
        bam = '02.mapping/STAR/sort_index/{sample}.sort.bam',
        bai = '02.mapping/STAR/sort_index/{sample}.sort.bam.bai'
    output:
        samtools_flagstat = '02.mapping/samtools_flagstat/{sample}_bam_flagstat.tsv',
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
    input:
        bam = '02.mapping/STAR/sort_index/{sample}.sort.bam',
        bai = '02.mapping/STAR/sort_index/{sample}.sort.bam.bai'
    output:
        samtools_stats = '02.mapping/samtools_stats/{sample}_bam_stats.tsv',
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
        reference = config['parameter']['star_index'][config['Genome_Version']]['genome_fa'],
    shell:
        """
        samtools stats \
                 -@ {threads} \
                 --reference {params.reference} \
                 {input.bam} > {output.samtools_stats}  2>{log}
        """

rule bamCoverage:
    input:
        bam = '02.mapping/STAR/sort_index/{sample}.sort.bam',
        bai = '02.mapping/STAR/sort_index/{sample}.sort.bam.bai'
    output:
        bw = f"02.mapping/bamCoverage/{{sample}}_{config['parameter']['bamCoverage']['normalizeUsing']}.bw"
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
# ----- rule ----- #