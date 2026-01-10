#!/usr/bin/snakemake
# -*- coding: utf-8 -*-
rule gene_dist:
    input:
        tpm = "03.count/merge_rsem_tpm.tsv",
        fpkm = "03.count/merge_rsem_fpkm.tsv",
    output:
        dist_pdf = '06.DEG/Gene_Expression/Gene_Expression_Distribution.pdf',
        dist_png = '06.DEG/Gene_Expression/Gene_Expression_Distribution.png',
    resources:
        **rule_resource(config, 'low_resource', queue_name=config['queue_id'], skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/deg_deseq2.yaml"),
    message:
        "Running Gene Expression Distribution",
    params:
        extension = workflow.source_path(config["parameter"]['Distribution']['path']),
        width = config["parameter"]['Distribution']['width'],
        height = config["parameter"]['Distribution']['height'],
        output = '06.DEG/Gene_Expression/',
        samples = config['sample_csv'],
    log:
        "logs/06.DEG/Gene_Expression_Distribution.log",
    benchmark:
        "benchmarks/Gene_Expression_Distribution.txt",
    threads: 1
    shell:
        """
        chmod +x {params.extension} && \
        {params.extension}  -t {input.tpm} \
                            -f {input.fpkm} \
                            -m {params.samples} \
                            -o {params.output} \
                            --width {params.width} \
                            --height {params.height} &> {log}
        """

rule gene_heatmap_tpm:
    input:
        tpm = "03.count/merge_rsem_tpm.tsv",
        fpkm = "03.count/merge_rsem_fpkm.tsv",
    output:
        dist_pdf = '06.DEG/Heatmap_tpm/Heatmap_TopVar.pdf',
        dist_png = '06.DEG/Heatmap_tpm/Heatmap_TopVar.png',
    resources:
        **rule_resource(config, 'low_resource', queue_name=config['queue_id'], skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/deg_deseq2.yaml"),
    message:
        "Running Gene Heatmap",
    params:
        extension = workflow.source_path(config["parameter"]['Heatmap']['path']),
        output = '06.DEG/Heatmap_tpm/',
        samples = config['sample_csv'],
    log:
        "logs/06.DEG/Gene_Heatmap_tpm.log",
    benchmark:
        "benchmarks/Gene_Heatmap_tpm.txt",
    threads: 1
    shell:
        """
        chmod +x {params.extension} && \
        {params.extension}  -i {input.tpm} \
                            -m {params.samples} \
                            -o {params.output}  &> {log}
        """

rule gene_heatmap_fpkm:
    input:
        tpm = "03.count/merge_rsem_tpm.tsv",
        fpkm = "03.count/merge_rsem_fpkm.tsv",
    output:
        dist_pdf = '06.DEG/Heatmap_fpkm/Heatmap_TopVar.pdf',
        dist_png = '06.DEG/Heatmap_fpkm/Heatmap_TopVar.png',
    resources:
        **rule_resource(config, 'low_resource', queue_name=config['queue_id'], skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/deg_deseq2.yaml"),
    message:
        "Running Gene Heatmap",
    params:
        extension = workflow.source_path(config["parameter"]['Heatmap']['path']),
        output = '06.DEG/Heatmap_fpkm/',
        samples = config['sample_csv'],
    log:
        "logs/06.DEG/Gene_Heatmap_fpkm.log",
    benchmark:
        "benchmarks/Gene_Heatmap_fpkm.txt",
    threads: 1
    shell:
        """
        chmod +x {params.extension} && \
        {params.extension}  -i {input.fpkm} \
                            -m {params.samples} \
                            -o {params.output}  &> {log}
        """

rule DEG:
    input:
        counts = "03.count/merge_rsem_counts.tsv",
    output:
        output = '06.DEG/DESEQ2/All_Contrast_DEG_Statistics.csv',
        deg_dir = directory("06.DEG/DESEQ2"),
    resources:
        **rule_resource(config, 'low_resource', queue_name=config['queue_id'], skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/deg_deseq2.yaml"),
    log:
        "logs/06.DEG/stringtie/deseq2_benchmark.log",
    benchmark:
        "benchmarks/06.DEG/deseq2_benchmark.txt",
    params:
        samples = config['sample_csv'],
        paired = config['paired_csv'],
        PATH = workflow.source_path(config['parameter']['DEG']['PATH']),
        LFC = config['parameter']['DEG']['LFC'],
        PVAL = config['parameter']['DEG']['PVAL'],
    threads: 
        1
    shell:
        """
        chmod +x {params.PATH} && \
        Rscript {params.PATH} -c {input.counts} \
                -m {params.samples} \
                -p {params.paired} \
                -o {output.deg_dir} \
                --lfc={params.LFC} \
                --pval={params.PVAL} &> {log}
        """

rule Enrichments:
    input:
        DEG_info = "06.DEG/DESEQ2/All_Contrast_DEG_Statistics.csv",
    output:
        Enrichments_dir = directory("07.Enrichments/"),
    resources:
        **rule_resource(config, 'low_resource', queue_name=config['queue_id'], skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/go_enrich_r.yaml"),
    log:
        "logs/07.Enrichments/go_enrich.log",
    params:
        obo = config['STAR_index']['GO']['obo'],
        go_annotation = config['STAR_index'][config['Genome_Version']]['go_annotation'],
        gene_col = config['parameter']['Enrichments']['gene_col'],
        r_script = workflow.source_path(config['parameter']['Enrichments']['PATH']),
        wrapper = workflow.source_path(config['parameter']['Enrichments']['PATH_py']),
        gene_regex = config['parameter']['Enrichments']['gene_regex'],
        deg_dir = "06.DEG/DESEQ2",
        cutoff = config['parameter']['Enrichments'].get('cutoff', 0.05)
    shell:
        """
        python {params.wrapper} \
            --rscript {params.r_script} \
            --deg_info {input.DEG_info} \
            --deg_dir {params.deg_dir} \
            -o {params.obo} \
            -a {params.go_annotation} \
            -d {output.Enrichments_dir} \
            --gene_col {params.gene_col} \
            --gene_regex '{params.gene_regex}' \
            --cutoff {params.cutoff} > {log} 2>&1
        """
# ------- rule ------- #
