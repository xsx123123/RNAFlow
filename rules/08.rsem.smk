#!/usr/bin/snakemake
# -*- coding: utf-8 -*-
rule build_rsem_index:
    input:
        genome_fa = config["parameter"]['star_index'][config['Genome_Version']]['genome_fa'],
        genome_gtf = config["parameter"]['star_index'][config['Genome_Version']]['genome_gtf']
    output:
        chrlist = config["parameter"]['star_index'][config['Genome_Version']]['rsem_index'] + '.chrlist',
        grp = config["parameter"]['star_index'][config['Genome_Version']]['rsem_index'] + '.grp',
        idx_fa = config["parameter"]['star_index'][config['Genome_Version']]['rsem_index'] + '.idx.fa',
        n2g_idx_fa = config["parameter"]['star_index'][config['Genome_Version']]['rsem_index'] + '.n2g.idx.fa',
    conda:
        workflow.source_path("../envs/rsem.yaml"),
    log:
        "logs/02.mapping/rsem_index.log"
    message:
        "Building rsem index for {input.genome_gtf}"
    params:
        rsem_index = config["parameter"]['star_index'][config['Genome_Version']]['rsem_index'],
    benchmark:
        "benchmarks/rsem_index_benchmark.txt"
    threads:
        config['parameter']['threads']['RSEM_INDEX']
    shell:
        """
        rsem-prepare-reference --gtf {input.genome_gtf} \
                       --star \
                       -p {threads} \
                       {input.genome_fa} \
                       {params.rsem_index}  2>{log}
        """

rule RSEM:
    input:
        chrlist = config["parameter"]['star_index'][config['Genome_Version']]['rsem_index'] + '.chrlist',
        grp = config["parameter"]['star_index'][config['Genome_Version']]['rsem_index'] + '.grp',
        idx_fa = config["parameter"]['star_index'][config['Genome_Version']]['rsem_index'] + '.idx.fa',
        n2g_idx_fa = config["parameter"]['star_index'][config['Genome_Version']]['rsem_index'] + '.n2g.idx.fa',
        Transcriptome_bam = '02.mapping/STAR/temp/{sample}.Aligned.toTranscriptome.out.bam',
    output:
        qualimap_report_html = '03.count/rsem/{sample}.genes.results',
        qualimap_report_txt = '03.count/rsem/{sample}.isoforms.results',
    conda:
        workflow.source_path("../envs/rsem.yaml"),
    message:
        "Running RSEM for BAM : {input.Transcriptome_bam}",
    log:
        "logs/02.mapping/rsem-calculate_{sample}.log",
    benchmark:
        "benchmarks/{sample}_rsem-calculate.txt",
    params:
        output_prefix = "03.count/rsem/{sample}",
        rsem_index = config["parameter"]['star_index'][config['Genome_Version']]['rsem_index'],
    threads: 
        config['parameter']["threads"]["rsem-calculate"],
    shell:
        """
        rsem-calculate-expression --bam \
                                --no-bam-output \
                                --estimate-rspd \
                                --calc-pme \
                                --seed 12345 \
                                -p {threads} \
                                --paired-end \
                                {input.Transcriptome_bam} \
                                {params.rsem_index} \
                                {params.output_prefix} 2>{log}
        """