#!/usr/bin/snakemake
# -*- coding: utf-8 -*-
"""
RNAFlow Pipeline - Gene Fusion Detection Module

This module implements gene fusion detection using Arriba, a fast and accurate tool
for detecting gene fusions from RNA-seq data. Arriba leverages STAR's chimeric read
detection capabilities to identify fusion transcripts with high sensitivity and specificity.

Key Features:
- Utilizes STAR's built-in chimeric read detection (WithinBAM mode)
- Fast and memory-efficient fusion calling
- Comprehensive filtering and annotation of fusion candidates
- Support for both standard and plant-specific genome configurations
- Generates detailed reports including discarded fusions for quality control

Arriba is particularly well-suited for RNA-seq fusion detection as it directly uses
the chimeric reads identified during the STAR alignment process, avoiding the need
for separate realignment steps and providing excellent performance on both human
and non-human genomes.
"""

rule Arriba_Run:
    """
    Detect gene fusions using Arriba from STAR-aligned BAM files.

    This rule runs Arriba to identify gene fusion events from RNA-seq data. Arriba
    takes advantage of STAR's chimeric read detection (enabled by default in the
    mapping step) to efficiently identify potential fusion transcripts.

    Key features of Arriba analysis:
    - Direct processing of STAR's chimeric reads stored within the BAM file
    - Comprehensive annotation of fusion breakpoints and partner genes
    - Built-in filtering to remove likely false positives
    - Generation of both high-confidence fusions and discarded candidates

    Plant-specific optimizations:
    - -D 0 parameter: Disables duplicate read filtering, which is important for
      plant genomes that often contain high levels of repetitive sequences
    - No blacklist filtering: Plant-specific blacklists are not available, so
      this filtering step is omitted

    Outputs:
    - fusions.tsv: High-confidence gene fusion candidates with detailed annotations
    - fusions.discarded.tsv: Fusion candidates that were filtered out with reasons
    - fusions.pdf: Optional visualization report (requires R environment)

    Note: Arriba is highly optimized and typically runs efficiently on a single
    CPU core, with I/O being the primary bottleneck rather than computation.
    """
    input:
        # Arriba 需要包含 Chimeric reads 的 BAM 文件
        bam = "02.mapping/STAR/sort_index/{sample}.sort.bam",
        # 基因组序列 (FASTA)
        fasta = config['STAR_index'][config['Genome_Version']]['genome_fasta'],
        # 基因注释 (GTF)
        gtf = config['STAR_index'][config['Genome_Version']]['genome_gtf']
    output:
        fusions = "06.fusion/arriba/{sample}_fusions.tsv",
        discarded = "06.fusion/arriba/{sample}_fusions.discarded.tsv",
        # 可选: PDF 可视化报告 (如果有 R 环境)
        plot = "06.fusion/arriba/{sample}_fusions.pdf"
    conda:
        workflow.source_path("../envs/arriba.yaml")
    log:
        "logs/06.fusion/arriba/{sample}.log"
    benchmark:
        "benchmarks/06.fusion/arriba/{sample}.txt"
    threads:
        1  # Arriba 计算效率极高，通常单核即可，主要瓶颈在 I/O
    params:
        out_dir = "06.fusion/arriba",
        # 植物特有优化建议:
        # -D 0 : 放宽片段重复的过滤 (植物基因组重复序列多)
        # 移除了 -b (blacklist) 因为没有植物的黑名单
        extra = "-D 0"
    shell:
        """
        # 1. 创建输出目录
        mkdir -p {params.out_dir}

        # 2. 运行 Arriba
        # -c 是 Arriba 寻找 chimeric reads 的模式，配合 STAR 的 WithinBAM 使用
        arriba \
            -x {input.bam} \
            -a {input.fasta} \
            -g {input.gtf} \
            -o {output.fusions} \
            -O {output.discarded} \
            {params.extra} \
            > {log} 2>&1

        # 3. (可选) 生成可视化图表
        # Arriba 自带一个 R 脚本 draw_fusions.R，通常在安装目录里
        # 如果你的 conda 环境里有 R 且安装了依赖，可以把下面这行解注释
        # draw_fusions.R --fusions={output.fusions} --alignments={input.bam} --output={output.plot} --annotation={input.gtf} --cytobands=none --proteinDomains=none
        """