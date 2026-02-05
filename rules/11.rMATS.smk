#!/usr/bin/snakemake
# -*- coding: utf-8 -*-
"""
RNAFlow Pipeline - Alternative Splicing Analysis Module

This module implements comprehensive alternative splicing (AS) analysis using rMATS
(replicate Multivariate Analysis of Transcript Splicing), a powerful tool for
detecting and quantifying differential alternative splicing events from RNA-seq data.

Key Components:
- Library strandness detection: Determines library preparation protocol
- rmats_run: Paired-sample differential splicing analysis between experimental conditions
- rmats_single_run: Single-sample splicing event detection for individual samples
- Result merging and summarization: Aggregates results across contrasts and samples

The pipeline supports detection of five major types of alternative splicing events:
- Skipped Exon (SE)
- Mutually Exclusive Exons (MXE)
- Alternative 5' Splice Site (A5SS)
- Alternative 3' Splice Site (A3SS)
- Retained Intron (RI)

Both paired (differential) and single-sample analyses are supported, enabling comprehensive
characterization of splicing patterns in the transcriptome.
"""

def get_contrast_bams(wildcards):
    """
    根据 wildcards.contrast 从字典中取回 {'b1': [...], 'b2': [...]}

    This helper function retrieves the BAM file lists for two experimental groups
    based on the contrast identifier. It uses the global CONTRAST_MAP dictionary
    which maps contrast names to sample groupings defined in the pipeline configuration.

    Args:
        wildcards: Snakemake wildcards object containing the 'contrast' identifier

    Returns:
        dict: Dictionary with 'b1' and 'b2' keys containing lists of BAM file paths
              for the two comparison groups

    Raises:
        ValueError: If the specified contrast is not found in CONTRAST_MAP
    """
    if wildcards.contrast not in CONTRAST_MAP:
        raise ValueError(f"Unknown contrast: {wildcards.contrast}")
    return CONTRAST_MAP[wildcards.contrast]

# rule gtf2bed12:
#    input:
#        gtf = config['STAR_index'][config['Genome_Version']]['genome_gtf'],
#    output:
#        bed12 = config['STAR_index'][config['Genome_Version']]['bed12'],
#    threads:
#        1
#    conda:
#        workflow.source_path("../envs/rseqc.yaml"),
#    log:
#        "logs/07.AS/rseqc/gtt2bed12.log"
#    benchmark:
#        "benchmarks/gtt2bed12.txt"
#    shell:
#        """
#        gtfToGenePred {input.gtf} /dev/stdout | genePredToBed \
#                      /dev/stdin {output.bed12} > {log} 2>&1
#        """

rule CIRCexplorer2_run:
    """
    Description: 
        Identify and annotate circular RNAs (circRNAs) using STAR chimeric alignment results.
    
    Workflow:
        1. Clean: Remove headers and metadata from STAR output to ensure compatibility with CIRCexplorer2.
        2. Parse: Extract back-spliced junctions from the cleaned file.
        3. Relocate: Move the output BED file to the specified directory (handling CIRCexplorer2's fixed output behavior).
        4. Annotate: Annotate circRNAs with gene models to identify host genes and types.
    """
    input:
        Chimeric = '02.mapping/STAR/{sample}/{sample}.Chimeric.out.junction',
    output:
        Chimeric_clean = temp('02.mapping/STAR/{sample}/{sample}.Chimeric.clean.junction'),
        back_spliced_junction = '02.mapping/CIRCexplorer2/{sample}/back_spliced_junction.bed',
        circularRNA = '02.mapping/CIRCexplorer2/{sample}/circularRNA_known.txt',
    resources:
        **rule_resource(config, 'low_resource', skip_queue_on_local=True, logger=logger),
    threads:
        1
    conda:
        workflow.source_path("../envs/circexplorer2.yaml"),
    log:
        "logs/02.mapping/CIRCexplorer2/{sample}.log",
    benchmark:
        "benchmarks/CIRCexplorer2_{sample}.txt",
    params:
        ref_all = config['STAR_index'][config['Genome_Version']]['ref_all'],
        genome = config['STAR_index'][config['Genome_Version']]['genome_fa'],
    shell:
        """
        (
        grep -v 'junction_type' {input.Chimeric} | grep -v '#' > {output.Chimeric_clean}

        CIRCexplorer2 parse -t STAR {output.Chimeric_clean} 

        if [ -f "back_spliced_junction.bed" ]; then
            mv back_spliced_junction.bed {output.back_spliced_junction}
        fi

        CIRCexplorer2 annotate -r {params.ref_all} \
                               -g {params.genome} \
                               -b {output.back_spliced_junction} \
                               -o {output.circularRNA} 
        
        ) > {log} 2>&1
        """

rule infer_experiment:
    """
    Determine RNA-seq library strandness using RSeQC's infer_experiment tool.

    Library strandness is crucial for accurate alternative splicing analysis as it
    affects how reads are interpreted relative to gene orientation. This rule uses
    RSeQC's infer_experiment.py to analyze the alignment patterns of reads against
    known gene annotations to determine whether the library is:
    - Unstranded (fr-unstranded)
    - Stranded forward (fr-firststrand)
    - Stranded reverse (fr-secondstrand)

    The BED12 reference file contains gene structure information in BED format,
    which is used as the annotation reference for strandness determination.

    Output is a summary text file containing the inferred library type and supporting
    statistics for each sample.
    """
    input:
        bed12 = config['STAR_index'][config['Genome_Version']]['bed12'],
        bam = '02.mapping/STAR/sort_index/{sample}.sort.bam',
    output:
        library = "07.AS/qc/strandness/{sample}.summary.txt",
    resources:
        **rule_resource(config, 'low_resource',  skip_queue_on_local=True,logger = logger),
    threads:
        1
    conda:
        workflow.source_path("../envs/rseqc.yaml"),
    log:
        "logs/07.rmats/rseqc/infer_experiment_{sample}.log",
    benchmark:
        "benchmarks/infer_experiment_{sample}.txt",
    shell:
        """
        infer_experiment.py -r {input.bed12} -i {input.bam} > {output.library} 2> {log}
        """

rule merge_strandness_results:
    """
    Aggregate strandness detection results from all samples into a single file.

    This rule combines the individual strandness summary files from all samples
    into one comprehensive file that can be used by downstream rMATS analysis.
    The merged file maintains sample-specific information while providing a unified
    view of library preparation protocols across the entire experiment.

    This aggregation is essential for the custom library type detection script
    that determines the appropriate --libType parameter for rMATS based on the
    experimental design and actual library characteristics.
    """
    input:
        expand("07.AS/qc/strandness/{sample}.summary.txt", sample=samples.keys()),
    output:
        "07.AS/qc/all_samples_strandness.txt",
    resources:
        **rule_resource(config, 'low_resource',  skip_queue_on_local=True,logger = logger),
    threads:
        1
    shell:
        """
        grep -H "" {input} > {output}
        """

rule junction_annotation:
    """
    RSeQC: Junction Annotation
    
    This module compares detected splice junctions to reference gene model.
    Splicing annotation is performed in two levels: splice event level and splice junction level.
    It helps to identify:
    - Annotated junctions (known)
    - Partial novel junctions
    - Complete novel junctions
    """
    input:
        bam = '02.mapping/STAR/sort_index/{sample}.sort.bam',
        bai = '02.mapping/STAR/sort_index/{sample}.sort.bam.bai',
        bed =  config['STAR_index'][config['Genome_Version']]['bed12'],
    output:
        splice_events =  "02.mapping/junction_annotation/{sample}.splice_events.pdf",
        splice_junction =  "02.mapping/junction_annotation/{sample}.splice_junction.pdf",
        junction = "02.mapping/junction_annotation/{sample}.junction.bed", 
        junction_Interact = "02.mapping/junction_annotation/{sample}.junction.Interact.bed", 
        junction_plot =  "02.mapping/junction_annotation/{sample}.junction_plot.r",
        junction_xls =  "02.mapping/junction_annotation/{sample}.junction.xls",
        log = '02.mapping/junction_annotation/{sample}.junction_annotation.txt',
    resources:
        **rule_resource(config, 'medium_resource', skip_queue_on_local=True, logger=logger),
    conda:
        workflow.source_path("../envs/rseqc.yaml"),
    message:
        "Calculating junction_annotation for {wildcards.sample}"
    benchmark:
        "benchmarks/{sample}_junction_annotation.txt"
    params:
        output = "02.mapping/junction_annotation/{sample}"
    threads: 
        1
    shell:
        """
        junction_annotation.py -i {input.bam} \
                               -r {input.bed} \
                               -o {params.output} > {output.log}
        """

rule rmats_run:
    """
    Perform differential alternative splicing analysis between experimental conditions using rMATS.

    This rule executes rMATS in paired mode to detect statistically significant differences
    in alternative splicing patterns between two experimental groups (e.g., treatment vs control).
    rMATS uses a hierarchical model to account for biological replicates and provides
    robust statistical testing for differential splicing events.

    Key features:
    - Supports all five major AS event types (SE, MXE, A5SS, A3SS, RI)
    - Implements replicate-aware statistical modeling
    - Automatically detects library strandness from QC results
    - Generates comprehensive output including effect sizes (ΔPSI) and p-values

    The rule uses a custom library type detection script that analyzes the aggregated
    strandness results to determine the appropriate --libType parameter for rMATS,
    ensuring accurate analysis regardless of the actual library preparation protocol used.

    Outputs include detailed results for each AS event type, summary statistics,
    and library type detection logs for quality assurance.
    """
    input:
        unpack(get_contrast_bams),
        gtf = config['STAR_index'][config['Genome_Version']]['genome_gtf'],
        lib_qc = "07.AS/qc/all_samples_strandness.txt",
    output:
        summary = "07.AS/rmats_pair/{contrast}/summary.txt",
        SE_MATS_JC = "07.AS/rmats_pair/{contrast}/SE.MATS.JC.txt",
        lib_check_log = "07.AS/rmats_pair/{contrast}/libType_check.log",
    resources:
        **rule_resource(config, 'high_resource',  skip_queue_on_local=True,logger = logger),
    params:
        od = "07.AS/rmats_pair/{contrast}",
        tmp = "07.AS/rmats_pair/{contrast}/tmp",
        libType = config['Library_Types'],
        readLength = config['parameter']['rmats']['readLength'],
        check_libtype = workflow.source_path(config['software']['check_libtype']),
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
        # get library type
        chmod +x {params.check_libtype} && \
        DETECTED_LIB=$(python3 {params.check_libtype} \
            {input.lib_qc} \
            "{params.libType}" \
            {output.lib_check_log})

        # run ramts
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
            --libType $DETECTED_LIB \
            --task both \
            --nthread {threads} \
            > {log} 2>&1
        """

rule merge_rmats_summary:
    """
    Aggregate and summarize differential splicing results across all experimental contrasts.

    This rule collects rMATS results from all pairwise comparisons (contrasts) and
    generates comprehensive summary files that provide an overview of alternative
    splicing patterns across the entire experiment.

    Two output modes are generated:
    - Summary mode: High-level statistics and overview of splicing events across contrasts
    - Details mode: Comprehensive listing of all detected splicing events with their
      statistical significance, effect sizes, and genomic coordinates

    These aggregated results facilitate cross-contrast comparisons and help identify
    consistent splicing patterns or condition-specific alternative splicing events.
    """
    input:
        summary = expand("07.AS/rmats_pair/{contrast}/summary.txt", contrast=ALL_CONTRASTS),
        SE_MATS_JC = expand("07.AS/rmats_pair/{contrast}/SE.MATS.JC.txt", contrast=ALL_CONTRASTS),
    output:
        detail = "07.AS/rmats_pair/rmats_detail.txt",
        sumarry = "07.AS/rmats_pair/rmats_summary.txt",
    resources:
        **rule_resource(config, 'high_resource',  skip_queue_on_local=True,logger = logger),
    params:
        rmats_dir = '07.AS/rmats_pair/',
        path = workflow.source_path(config['parameter']['rmats_summary']['path']),
    threads:
        config['parameter']['threads']['rmats']
    conda:
        workflow.source_path("../envs/python3.yaml")
    log:
        "logs/07.AS/rmats_pair/rmats_detail_summary.log"
    benchmark:
        "benchmarks/rmats_pair_detail_summary.txt"
    shell:
        """
        chmod +x {params.path}
        python3 {params.path} -i {params.rmats_dir}  --mode summary  -o  {output.sumarry} &>{log}
        python3 {params.path} -i {params.rmats_dir}  --mode details  -o  {output.detail} &>{log}
        """

rule rmats_single_run:
    """
    Perform single-sample alternative splicing event detection using rMATS.

    While the paired analysis focuses on differential splicing between conditions,
    this rule detects all alternative splicing events present in individual samples.
    This is valuable for:
    - Characterizing the complete splicing landscape of each sample
    - Identifying sample-specific splicing events
    - Providing baseline splicing profiles for quality control
    - Supporting downstream analyses that require per-sample splicing catalogs

    The rule uses rMATS in single-sample mode (--statoff flag disables statistical
    testing since there are no replicates for comparison) and automatically detects
    the appropriate library type from the aggregated strandness results.

    Output includes comprehensive splicing event detection for all five AS types
    along with summary statistics for each sample.
    """
    input:
        bam = "02.mapping/STAR/sort_index/{sample}.sort.bam",
        gtf = config['STAR_index'][config['Genome_Version']]['genome_gtf'],
        lib_qc = "07.AS/qc/all_samples_strandness.txt",
    output:
        se = "07.AS/rmats_single/{sample}/SE.MATS.JC.txt",
        mx = "07.AS/rmats_single/{sample}/MXE.MATS.JC.txt",
        summary = "07.AS/rmats_single/{sample}/summary.txt",
        lib_check_log = "07.AS/rmats_single/{sample}/libType_check.log",
    resources:
        **rule_resource(config, 'high_resource',  skip_queue_on_local=True,logger = logger),
    params:
        od = "07.AS/rmats_single/{sample}",
        tmp = "07.AS/rmats_single/{sample}/tmp",
        libType = config['Library_Types'],
        check_libtype = workflow.source_path(config['software']['check_libtype']),
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
        # get library type
        chmod +x {params.check_libtype} && \
        DETECTED_LIB=$(python3 {params.check_libtype} \
            {input.lib_qc} \
            "{params.libType}" \
            {output.lib_check_log})

        # run ramts
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
            --libType $DETECTED_LIB \
            --statoff \
            --nthread {threads} \
            > {log} 2>&1
        """

rule merge_rmats_single_summary:
    """
    Aggregate single-sample splicing detection results across all samples.

    This rule combines the individual splicing event catalogs from all samples
    into comprehensive summary files that provide a complete view of alternative
    splicing across the entire dataset.

    Similar to the paired analysis aggregation, this rule generates:
    - Summary mode: Overview statistics of splicing events across all samples
    - Details mode: Complete listing of all detected splicing events with their
      genomic coordinates, junction counts, and sample-specific information

    These aggregated single-sample results complement the differential analysis
    by providing context about the overall splicing complexity and helping to
    distinguish truly novel events from technical artifacts.
    """
    input:
        summary = expand("07.AS/rmats_single/{sample}/summary.txt",sample=samples.keys()),
        se = expand("07.AS/rmats_single/{sample}/SE.MATS.JC.txt",sample=samples.keys()),
    output:
        detail = "07.AS/rmats_single/rmats_detail.txt",
        sumarry = "07.AS/rmats_single/rmats_summary.txt",
    resources:
        **rule_resource(config, 'high_resource',  skip_queue_on_local=True,logger = logger),
    params:
        rmats_dir = '07.AS/rmats_single/',
        path = workflow.source_path(config['parameter']['rmats_summary']['path']),
    threads:
        config['parameter']['threads']['rmats']
    conda:
        workflow.source_path("../envs/python3.yaml")
    log:
        "logs/07.AS/rmats_single/rmats_detail_summary.log"
    benchmark:
        "benchmarks/rmats_single_detail_summary.txt"
    shell:
        """
        chmod +x {params.path}
        python3 {params.path} -i {params.rmats_dir}  --mode summary  -o  {output.sumarry} &> {log}
        python3 {params.path} -i {params.rmats_dir}  --mode details  -o  {output.detail} &> {log}
        """
# ----- rule ----- #