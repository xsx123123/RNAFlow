#!/usr/bin/snakemake
# -*- coding: utf-8 -*-
import os
# ----- rule ----- #
rule short_read_fastp:
    input:
        md5_check = "01.qc/md5_check.tsv",
        link_r1_dir =  os.path.join("00.raw_data",
                                      config['convert_md5'],
                                      "{sample}/{sample}_R1.fq.gz"),
        link_r2_dir =  os.path.join("00.raw_data",
                                      config['convert_md5'],
                                      "{sample}/{sample}_R2.fq.gz"),
    output:
        r1_trimmed = "01.qc/short_read_trim/{sample}.R1.trimed.fq.gz",
        r2_trimmed = "01.qc/short_read_trim/{sample}.R2.trimed.fq.gz",
        html_report = "01.qc/short_read_trim/{sample}.trimed.html",
        json_report = "01.qc/short_read_trim/{sample}.trimed.json",
    resources:
        **rule_resource(config, 'high_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/fastp.yaml"),
    log:
        "logs/01.short_read_trim/{sample}.trimed.log",
    message:
        "Running Fastp on {wildcards.sample} r1 and {wildcards.sample} r2",
    benchmark:
        "benchmarks/{sample}_fastp_benchmark.txt",
    params:
        length_required = config['parameter']["trim"]["length_required"],
        quality_threshold = config['parameter']["trim"]["quality_threshold"],
        adapter_fasta = workflow.source_path(config['parameter']["trim"]["adapter_fasta"]),
    threads: 
        config['parameter']["threads"]["fastp"],
    shell:
        """
        fastp -i {input.link_r1_dir} -I {input.link_r2_dir} \
              -o {output.r1_trimmed} -O {output.r2_trimmed} \
              --thread {threads} \
              --length_required  {params.length_required} \
              --qualified_quality_phred {params.quality_threshold} \
              --adapter_fasta {params.adapter_fasta} \
              -g -V \
              -h {output.html_report} \
              -j {output.json_report} &> {log}
        """

rule multiqc_trim:
    input:
        md5_check = "01.qc/md5_check.tsv",
        r1_trimmed = expand("01.qc/short_read_trim/{sample}.R1.trimed.fq.gz",
                            sample=samples.keys()),
        r2_trimmed = expand("01.qc/short_read_trim/{sample}.R2.trimed.fq.gz",
                            sample=samples.keys()),
        fastp_report = expand("01.qc/short_read_trim/{sample}.trimed.html",
                              sample=samples.keys()),
    output:
        report = '01.qc/multiqc_short_read_trim/multiqc_short_read_trim_report.html',
    resources:
        **rule_resource(config, 'low_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/multiqc.yaml"),
    message:
        "Running MultiQC to aggregate fastp reports",
    benchmark:
        "benchmarks/multiqc_fastp_benchmark.txt",
    params:
        fastqc_reports = "01.qc/short_read_trim/",
        report_dir = "01.qc/multiqc_short_read_trim/",
        report = "multiqc_short_read_trim_report.html",
        title = "short_read_trim-multiqc-report",
    log:
        "logs/01.short_read_trim/multiqc_trim.log",
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
# ----- rule ----- #