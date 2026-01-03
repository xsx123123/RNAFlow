#!/usr/bin/snakemake
# -*- coding: utf-8 -*-
rule DEG:
    input:
        counts = "03.count/merge_rsem_counts.tsv",
    output:
        deg_dir = directory("06.DEG/DESEQ2"),
    conda:
        workflow.source_path("../envs/deg_deseq2.yaml"),
    log:
        "logs/06.DEG/stringtie/deseq2_benchmark.log",
    benchmark:
        "benchmarks/06.DEG/deseq2_benchmark.txt",
    params:
        samples = config['sample_csv'],
        paired = config['paired_csv'],
        PATH = config['parameter']['DEG']['PATH'],
        LFC = config['parameter']['DEG']['LFC'],
        PVAL = config['parameter']['DEG']['PVAL'],
    threads: 
        1
    shell:
        """
        Rscript {params.PATH} -c {input.counts} \
                -m {params.samples} \
                -p {params.paired} \
                -o {output.deg_dir} \
                --lfc={params.LFC} \
                --pval={params.PVAL} &> {log}
        """
