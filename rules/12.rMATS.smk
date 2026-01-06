#!/usr/bin/snakemake
# -*- coding: utf-8 -*-
def get_contrast_bams(wildcards):
    """
    根据 wildcards.contrast 从字典中取回 {'b1': [...], 'b2': [...]}
    """
    if wildcards.contrast not in CONTRAST_MAP:
        raise ValueError(f"Unknown contrast: {wildcards.contrast}")
    return CONTRAST_MAP[wildcards.contrast]

rule rmats_run:
    input:
        unpack(get_contrast_bams),
        gtf = config['parameter']['star_index'][config['Genome_Version']]['genome_gtf']
    output:
        "07.AS/rmats_pair/{contrast}/summary.txt",
        "07.AS/rmats_pair/{contrast}/SE.MATS.JC.txt"
    params:
        od = "07.AS/rmats_pair/{contrast}",
        tmp = "07.AS/rmats_pair/{contrast}/tmp",
        libType = config['Library_Types'],
        readLength = config['parameter']['rmats']['readLength'],
        b1_str = lambda w, input: ",".join([os.path.abspath(f) for f in input.b1]),
        b2_str = lambda w, input: ",".join([os.path.abspath(f) for f in input.b2]),
    threads: 
        config['parameter']['threads']['rmats']
    conda:
        workflow.source_path("../envs/rmats.yaml")
    log:
        "logs/07.AS/rmats_pair/rmats_{contrast}.log"
    benchmark:
        "benchmarks/rmats_pair_{contrast}.txt"
    shell:
        """
        mkdir -p {params.tmp}
        echo "{params.b1_str}" > {params.tmp}/b1.txt
        echo "{params.b2_str}" > {params.tmp}/b2.txt
        
        rmats.py \
            --b1 {params.tmp}/b1.txt \
            --b2 {params.tmp}/b2.txt \
            --gtf {input.gtf} \
            --od {params.od} \
            --tmp {params.tmp} \
            -t paired \
            --readLength {params.readLength} \
            --variable-read-length \
            --libType {params.libType} \
            --task both \
            --nthread {threads} \
            > {log} 2>&1
        """

rule rmats_single_run:
    input:
        bam = "02.mapping/STAR/sort_index/{sample}.sort.bam",
        gtf = "05.assembly/filter/final_Novel_Isoforms.gtf"
    output:
        se = "07.AS/rmats_single/{sample}/SE.MATS.JC.txt",
        mx = "07.AS/rmats_single/{sample}/MXE.MATS.JC.txt",
        summary = "07.AS/rmats_single/{sample}/summary.txt"
    params:
        od = "07.AS/rmats_single/{sample}",
        tmp = "07.AS/rmats_single/{sample}/tmp",
        libType = config['Library_Types'],
        readLength = config['parameter']['rmats']['readLength'],
        b1_abs = lambda w, input: os.path.abspath(input.bam)
    threads: 
        config['parameter']['threads']['rmats']
    conda:
        workflow.source_path("../envs/rmats.yaml")
    log:
        "logs/07.AS/rmats_single/{sample}.log"
    benchmark:
        "benchmarks/rmats_single_{sample}.txt"
    shell:
        """
        mkdir -p {params.tmp}
        echo "{params.b1_abs}" > {params.tmp}/b1.txt
        rmats.py \
            --b1 {params.tmp}/b1.txt \
            --gtf {input.gtf} \
            --od {params.od} \
            --tmp {params.tmp} \
            -t paired \
            --readLength {params.readLength} \
            --variable-read-length \
            --libType {params.libType} \
            --statoff \
            --nthread {threads} \
            > {log} 2>&1
        """