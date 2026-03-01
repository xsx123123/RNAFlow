#!/usr/bin/snakemake
# -*- coding: utf-8 -*-
"""
RNAFlow Pipeline - Differential Expression Analysis and Functional Enrichment Module

This module performs comprehensive differential gene expression (DEG) analysis using
DESeq2 and subsequent functional enrichment analysis to identify biologically meaningful
patterns in the RNA-seq data.

Key Components:
- gene_dist: Quality control and exploratory analysis of gene expression distributions
- gene_heatmap_tpm/fpkm: Visualization of expression patterns across samples
- DEG: Statistical differential expression analysis using DESeq2
- Enrichments: Gene Ontology (GO) and pathway enrichment analysis

The pipeline enables identification of significantly differentially expressed genes
between experimental conditions and provides biological context through functional
enrichment analysis, helping researchers understand the underlying biological processes,
molecular functions, and cellular components affected by their experimental conditions.
"""

rule gene_dist:
    """
    Generate quality control plots for gene expression distribution analysis.

    This rule creates visualization plots showing the distribution of gene expression
    values across all samples using both TPM and FPKM normalized expression matrices.
    These plots serve as essential quality control metrics to:
    - Assess overall expression distribution patterns
    - Identify potential outliers or batch effects
    - Validate normalization effectiveness
    - Ensure data quality before differential expression analysis

    The output includes both PDF (for publication-quality figures) and PNG (for quick
    inspection) formats of the distribution plots, providing flexibility for different
    use cases.
    """
    input:
        tpm = "03.count/merge_rsem_tpm.tsv",
        fpkm = "03.count/merge_rsem_fpkm.tsv",
    output:
        dist_pdf = '06.DEG/Gene_Expression/Gene_Expression_Distribution.pdf',
        dist_png = '06.DEG/Gene_Expression/Gene_Expression_Distribution.png',
    resources:
        **rule_resource(config, 'low_resource',  skip_queue_on_local=True,logger = logger),
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
    """
    Generate heatmap visualization of top variable genes using TPM expression values.

    This rule creates a clustered heatmap showing the expression patterns of the most
    variable genes across all samples using TPM-normalized data. Heatmaps are powerful
    visual tools for:
    - Identifying sample clustering patterns and potential batch effects
    - Visualizing co-expression patterns among genes
    - Detecting outlier samples that may need further investigation
    - Understanding overall expression relationships between samples

    The heatmap focuses on the most variable genes to highlight the strongest expression
    differences, making it easier to interpret complex expression patterns.
    """
    input:
        tpm = "03.count/merge_rsem_tpm.tsv",
        fpkm = "03.count/merge_rsem_fpkm.tsv",
    output:
        dist_pdf = '06.DEG/Heatmap_tpm/Heatmap_TopVar.pdf',
        dist_png = '06.DEG/Heatmap_tpm/Heatmap_TopVar.png',
    resources:
        **rule_resource(config, 'low_resource',  skip_queue_on_local=True,logger = logger),
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
    """
    Generate heatmap visualization of top variable genes using FPKM expression values.

    Similar to the TPM heatmap, this rule creates a clustered heatmap using FPKM-
    normalized expression data. Having both TPM and FPKM heatmaps allows for:
    - Cross-validation of expression patterns between different normalization methods
    - Comparison with legacy datasets that may have used FPKM normalization
    - Robustness assessment of observed clustering patterns

    While TPM is generally preferred for cross-sample comparisons, FPKM heatmaps
    provide additional perspective and can be useful for specific analytical contexts.
    """
    input:
        tpm = "03.count/merge_rsem_tpm.tsv",
        fpkm = "03.count/merge_rsem_fpkm.tsv",
    output:
        dist_pdf = '06.DEG/Heatmap_fpkm/Heatmap_TopVar.pdf',
        dist_png = '06.DEG/Heatmap_fpkm/Heatmap_TopVar.png',
    resources:
        **rule_resource(config, 'low_resource',  skip_queue_on_local=True,logger = logger),
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
    """
    Perform statistical differential expression analysis using DESeq2.

    This rule implements DESeq2, a widely-used R package for differential gene
    expression analysis that uses negative binomial generalized linear models to
    identify statistically significant differences in gene expression between
    experimental conditions.

    Key features of DESeq2 analysis:
    - Handles biological replicates appropriately
    - Models count data using negative binomial distribution
    - Implements shrinkage estimation for fold changes
    - Provides multiple testing correction (Benjamini-Hochberg)
    - Supports complex experimental designs including paired samples

    Parameters:
    - LFC (Log2 Fold Change): Minimum fold change threshold for significance
    - PVAL: Adjusted p-value threshold for significance
    - paired: Sample pairing information for paired experimental designs

    The output includes comprehensive statistics for all contrasts in the experiment,
    including log2 fold changes, p-values, adjusted p-values, and base means.
    """
    input:
        counts = "03.count/merge_rsem_counts.tsv",
    output:
        output = '06.DEG/DESEQ2/All_Contrast_DEG_Statistics.csv',
        deg_dir = directory("06.DEG/DESEQ2"),
    resources:
        **rule_resource(config, 'low_resource',  skip_queue_on_local=True,logger = logger),
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
    """
    Perform Gene Ontology (GO) and pathway enrichment analysis on differentially expressed genes.

    This rule conducts functional enrichment analysis to identify overrepresented biological
    terms, molecular functions, and cellular components among the differentially expressed
    genes identified by DESeq2. The analysis helps translate statistical results into
    biological insights by answering: "What biological processes are affected by my
    experimental conditions?"

    The enrichment analysis uses:
    - Gene Ontology (GO) database for functional annotation
    - Statistical overrepresentation analysis (hypergeometric test or Fisher's exact test)
    - Multiple testing correction to control false discovery rate
    - Custom gene ID mapping based on reference genome annotation

    Key parameters:
    - gene_col: Column name containing gene identifiers in DEG results
    - gene_regex: Regular expression pattern for extracting gene IDs
    - cutoff: Significance threshold for enriched terms (default: 0.05)
    - obo: GO ontology file for term definitions and relationships
    - go_annotation: Genome-specific GO annotation file

    The output is organized in a dedicated directory containing enrichment results
    for all contrasts, including enriched terms, p-values, gene lists, and visualization
    files for downstream interpretation and reporting.
    """
    input:
        DEG_info = "06.DEG/DESEQ2/All_Contrast_DEG_Statistics.csv",
    output:
        Enrichments_dir = directory("07.Enrichments/"),
    resources:
        **rule_resource(config, 'low_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/go_enrich_r.yaml"),
    log:
        "logs/07.Enrichments/go_enrich.log",
    params:
        obo = config['STAR_index']['GO']['obo'],
        go_annotation = config['STAR_index'][config['Genome_Version']]['go_annotation'],
        gene_col = config['deg_enrich_wrapper'][config['Genome_Version']]['gene_col'],
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
            --gene_col '{params.gene_col}' \
            --gene_regex '{params.gene_regex}' \
            --cutoff {params.cutoff} > {log} 2>&1
        """