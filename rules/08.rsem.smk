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
        index_dir =  config["parameter"]['star_index'][config['Genome_Version']]['rsem_index_dir'],
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
        mkdir -p {params.index_dir} &&
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
        Transcriptome_bam = '02.mapping/STAR/{sample}/{sample}.Aligned.toTranscriptome.out.bam',
    output:
        genes_result = '03.count/rsem/{sample}.genes.results',
        isoforms_result = '03.count/rsem/{sample}.isoforms.results',
        cnt = '03.count/rsem/{sample}.stat/{sample}.cnt',
        model = '03.count/rsem/{sample}.stat/{sample}.model',
        theta = '03.count/rsem/{sample}.stat/{sample}.theta',
    conda:
        workflow.source_path("../envs/rsem.yaml"),
    message:
        "Running RSEM for BAM : {input.Transcriptome_bam}",
    log:
        "logs/02.mapping/rsem-calculate_{sample}.log",
    benchmark:
        "benchmarks/{sample}_rsem-calculate.txt",
    params:
        sample_name = lambda wildcards: samples[wildcards.sample]["sample_name"],
        rsem_index = config["parameter"]['star_index'][config['Genome_Version']]['rsem_index'],
        output_prefix = "03.count/rsem/{sample}",
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
                                {params.output_prefix} &>{log}
        """

rule rsem_multiqc:
    input:
        fastqc_files_r1 = expand("03.count/rsem/{sample}.stat/{sample}.cnt",\
                                  sample=samples.keys()),
    output:
        report = "03.count/multiqc_rsem_report.html",
    conda:
        workflow.source_path("../envs/multiqc.yaml"),
    message:
        "Running MultiQC to aggregate rsem reports",
    params:
        fastqc_reports = "03.count/rsem/",
        report_dir = "03.count/",
        report = "multiqc_rsem_report.html",
        title = "rsem_report",
    log:
        "logs/03.count/rsem_report.log",
    benchmark:
        "benchmarks/rsem_report_benchmark.txt",
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

rule merge_rsem:
    input:
        genes_result = expand('03.count/rsem/{sample}.genes.results',
                                sample=samples.keys()),
        isoforms_result = expand('03.count/rsem/{sample}.isoforms.results',
                                sample=samples.keys()),
    output:
        tpm = "03.count/merge_rsem_tpm.tsv",
        counts = "03.count/merge_rsem_counts.tsv",
        fpkm = "03.count/merge_rsem_fpkm.tsv",
    conda:
        workflow.source_path("../envs/python3.yaml"),
    message:
        "Running MultiQC to aggregate rsem reports",
    params:
        extension = config["parameter"]['merge_rsem']['extension'],
        input_dir = '03.count/rsem/',
        sample_csv = config['sample_csv'],
        merge_rsem = workflow.source_path(config["parameter"]['merge_rsem']['path']),
    log:
        "logs/03.count/merge_rsem.log",
    benchmark:
        "benchmarks/merge_rsem_benchmark.txt",
    threads: 1
    shell:
        """
        chmod +x {params.merge_rsem} && \
        {params.merge_rsem}  merge-from-dir \
                       --input-dir  {params.input_dir} \
                       --tpm {output.tpm} \
                       --counts {output.counts} \
                       --fpkm {output.fpkm}  \
                       --map {params.sample_csv} \
                       --extension {params.extension} &> {log}
        """

rule ultimate:
    input:
        tpm = "03.count/merge_rsem_tpm.tsv",
        counts = "03.count/merge_rsem_counts.tsv",
        fpkm = "03.count/merge_rsem_fpkm.tsv",
    output:
        ultimate = directory("03.count/rsem_ultimate/")
    conda:
        workflow.source_path("../envs/rsem_ultimate.yaml"),
    message:
        "Running rsem_ultimate",
    params:
        extension = workflow.source_path(config["parameter"]['qc_rsem_ultimate']['path']),
    log:
        "logs/03.count/qc_rsem_ultimate.log",
    benchmark:
        "benchmarks/qc_rsem_ultimate_benchmark.txt",
    threads: 1
    shell:
        """
        chmod +x {params.extension} && \
        {params.extension}  --tpm {input.tpm} \
                            --fpkm {input.fpkm} \
                            --counts {input.counts} \
                            --out_dir {output.ultimate} &> {log}
        """
# ------- rule ------- #