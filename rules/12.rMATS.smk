#!/usr/bin/snakemake
# -*- coding: utf-8 -*-
def get_contrast_bams(wildcards):
    """
    根据 wildcards.contrast 从字典中取回 {'b1': [...], 'b2': [...]}
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

rule infer_experiment:
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

rule rmats_run:
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

rule merge_rmats:
    input:
        summary = expand("07.AS/rmats_pair/{contrast}/summary.txt", contrast=all_contrasts),
        SE_MATS_JC = expand("07.AS/rmats_pair/{contrast}/SE.MATS.JC.txt", contrast=all_contrasts),
    output:
        detail = "07.AS/rmats_pair/rmats_detail.txt",
        sumarry = "07.AS/rmats_pair/rmats_summary.txt",
    resources:
        **rule_resource(config, 'high_resource',  skip_queue_on_local=True,logger = logger),
    params:
        rmats_dir = '07.AS/rmats_pair/'
        path = workflow.source_path(config['parameter']['rmats_summary']['path']),
    threads: 
        config['parameter']['threads']['rmats']
    conda:
        workflow.source_path("../envs/python3.yaml")
    log:
        "logs/07.AS/rmats_pair/rmats_{contrast}.log"
    benchmark:
        "benchmarks/rmats_pair_{contrast}.txt"
    shell:
        """
        chmod +x {params.path}
        python3 {params.path} -i {params.rmats_dir}  --mode summary  -o  {output.sumarry} &>{log}
        python3 {params.path} -i {params.rmats_dir}  --mode details  -o  {output.detail} &>{log}
        """
    
rule rmats_single_run:
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

rule merge_rmats_single:
    input:
        summary = "07.AS/rmats_single/{sample}/summary.txt",
        se = "07.AS/rmats_single/{sample}/SE.MATS.JC.txt",
    output:
        detail = "07.AS/rmats_single/rmats_detail.txt",
        sumarry = "07.AS/rmats_single/rmats_summary.txt",
    resources:
        **rule_resource(config, 'high_resource',  skip_queue_on_local=True,logger = logger),
    params:
        rmats_dir = '07.AS/rmats_single/'
        path = workflow.source_path(config['parameter']['rmats_summary']['path']),
    threads: 
        config['parameter']['threads']['rmats']
    conda:
        workflow.source_path("../envs/python3.yaml")
    log:
        "logs/07.AS/rmats_single/rmats_{sample}.log"
    benchmark:
        "benchmarks/rmats_single_{sample}.txt"
    shell:
        """
        chmod +x {params.path}
        python3 {params.path} -i {params.rmats_dir}  --mode summary  -o  {output.sumarry} &> {log}
        python3 {params.path} -i {params.rmats_dir}  --mode details  -o  {output.detail} &> {log}
        """
# ----- rule ----- #