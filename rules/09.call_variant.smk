#!/usr/bin/snakemake
# -*- coding: utf-8 -*-

def get_java_opts(wildcards, input, resources):
    mem_gb = max(int(resources.mem_mb / 1024) - 4, 2)
    return f"-Xmx{mem_gb}g -XX:+UseParallelGC -XX:ParallelGCThreads=4"

rule CreateRefIndex:
    input:
        fasta = config['parameter']['star_index'][config['Genome_Version']]['genome_fa'],
    output:
        dict = os.path.splitext(config['parameter']['star_index'][config['Genome_Version']]['genome_fa'])[0] + ".dict",
        fai = config['parameter']['star_index'][config['Genome_Version']]['genome_fa'] + ".fai",
    conda:
        workflow.source_path("../envs/gatk.yaml")
    log:
        "logs/00.prepare/create_ref_index.log"
    shell:
        """
        gatk CreateSequenceDictionary -R {input.fasta} -O {output.dict} > {log} 2>&1
        
        samtools faidx {input.fasta} >> {log} 2>&1
        """

rule AddOrReplaceReadGroups:
    input:
        bam = '02.mapping/STAR/sort_index/{sample}.sort.bam',
        bai = '02.mapping/STAR/sort_index/{sample}.sort.bam.bai',
    output:
        bam = temp('04.variant/gatk/{sample}/{sample}.rg.bam'),
        bai = temp('04.variant/gatk/{sample}/{sample}.rg.bai')
    conda:
        workflow.source_path("../envs/gatk.yaml")
    log:
        "logs/04.variant/gatk/AddRG/{sample}.log"
    benchmark:
        "benchmarks/04.variant/gatk/AddRG/{sample}.txt"
    resources:
        mem_mb = 16384 
    threads: 1
    params:
        java_opts = get_java_opts
    shell:
        """
        gatk --java-options "{params.java_opts}" AddOrReplaceReadGroups \
             -I {input.bam} \
             -O {output.bam} \
             -SO coordinate \
             -ID 1 -LB lib1 \
             -PL illumina -PU unit1 \
             -SM {wildcards.sample} \
             --CREATE_INDEX true 2> {log}
        """

rule MarkDuplicates:
    input:
        bam = '04.variant/gatk/{sample}/{sample}.rg.bam',
    output:
        bam = temp('04.variant/gatk/{sample}/{sample}.rg.dedup.bam'),
        metrics = '04.variant/gatk_MarkDuplicates/{sample}.rg.dedup.metrics.txt',
    conda:
        workflow.source_path("../envs/gatk.yaml")
    log:
        "logs/04.variant/gatk/MarkDup/{sample}.log"
    benchmark:
        "benchmarks/04.variant/gatk/MarkDup/{sample}.txt"
    resources:
        mem_mb = 40960 
    threads: 2
    params:
        java_opts = get_java_opts
    shell:
        """
        gatk --java-options "{params.java_opts}" MarkDuplicates \
             -I {input.bam} \
             -O {output.bam} \
             -M {output.metrics} \
             --CREATE_INDEX true \
             --MAX_RECORDS_IN_RAM 5000000 \
             --SORTING_COLLECTION_SIZE_RATIO 0.5 2> {log}
        """

rule SplitNCigarReads:
    input:
        bam = '04.variant/gatk/{sample}/{sample}.rg.dedup.bam',
        ref_dict = os.path.splitext(config['parameter']['star_index'][config['Genome_Version']]['genome_fa'])[0] + ".dict",
        ref_fai = config['parameter']['star_index'][config['Genome_Version']]['genome_fa'] + ".fai",
    output:
        bam = '04.variant/gatk/{sample}/{sample}.rg.dedup.split.bam',
        bai = '04.variant/gatk/{sample}/{sample}.rg.dedup.split.bai',
    conda:
        workflow.source_path("../envs/gatk.yaml")
    log:
        "logs/04.variant/gatk/SplitN/{sample}.log"
    benchmark:
        "benchmarks/04.variant/gatk/SplitN/{sample}.txt"
    resources:
        mem_mb = 20480 
    threads: 4
    params:
        fasta = config['parameter']['star_index'][config['Genome_Version']]['genome_fa'],
        java_opts = get_java_opts
    shell:
        """
        gatk --java-options "{params.java_opts}" SplitNCigarReads \
             -R {params.fasta} \
             -I {input.bam} \
             -O {output.bam} 2> {log}
        """

rule HaplotypeCaller:
    input:
        bam = '04.variant/gatk/{sample}/{sample}.rg.dedup.split.bam',
        bai = '04.variant/gatk/{sample}/{sample}.rg.dedup.split.bai',
        ref_dict = os.path.splitext(config['parameter']['star_index'][config['Genome_Version']]['genome_fa'])[0] + ".dict",
        ref_fai = config['parameter']['star_index'][config['Genome_Version']]['genome_fa'] + ".fai",
    output:
        vcf = '04.variant/gatk/{sample}/{sample}.raw_variants.vcf',
        idx = '04.variant/gatk/{sample}/{sample}.raw_variants.vcf.idx'
    conda:
        workflow.source_path("../envs/gatk.yaml")
    log:
        "logs/04.variant/gatk/HC/{sample}.log"
    benchmark:
        "benchmarks/04.variant/gatk/HC/{sample}.txt"
    resources:
        mem_mb = 32768
    threads: 
        config['parameter']['threads']['gatk']
    params:
        fasta = config['parameter']['star_index'][config['Genome_Version']]['genome_fa'],
        ploidy = config['parameter']['star_index'][config['Genome_Version']]['ploidy'],
        java_opts = get_java_opts
    shell:
        """
        gatk --java-options "{params.java_opts}" HaplotypeCaller \
             -R {params.fasta} \
             -I {input.bam} \
             -O {output.vcf} \
             -ploidy {params.ploidy} \
             --dont-use-soft-clipped-bases \
             --standard-min-confidence-threshold-for-calling 20 \
             --native-pair-hmm-threads {threads} 2> {log}
        """

rule VariantFiltration:
    input:
        vcf = '04.variant/gatk/{sample}/{sample}.raw_variants.vcf',
        idx = '04.variant/gatk/{sample}/{sample}.raw_variants.vcf.idx',
        ref_dict = os.path.splitext(config['parameter']['star_index'][config['Genome_Version']]['genome_fa'])[0] + ".dict",
        ref_fai = config['parameter']['star_index'][config['Genome_Version']]['genome_fa'] + ".fai",
    output:
        vcf = '04.variant/gatk/{sample}/{sample}.filtered.vcf',
        idx = '04.variant/gatk/{sample}/{sample}.filtered.vcf.idx'
    conda:
        workflow.source_path("../envs/gatk.yaml")
    log:
        "logs/04.variant/gatk/Filter/{sample}.log"
    benchmark:
        "benchmarks/04.variant/gatk/Filter/{sample}.txt"
    resources:
        mem_mb = 8192
    threads: 1
    params:
        fasta = config['parameter']['star_index'][config['Genome_Version']]['genome_fa'],
        java_opts = get_java_opts,
        win = config['parameter']['gatk']['filter']['rna_seq']['window_size'],
        clus = config['parameter']['gatk']['filter']['rna_seq']['cluster_size'],
        fs = config['parameter']['gatk']['filter']['rna_seq']['fs_threshold'],
        qd = config['parameter']['gatk']['filter']['rna_seq']['qd_threshold'],
    shell:
        """
        gatk --java-options "{params.java_opts}" VariantFiltration \
             -R {params.fasta} \
             -V {input.vcf} \
             -O {output.vcf} \
             --window {params.win} \
             --cluster {params.clus} \
             --filter-name "FS{params.fs}" --filter-expression "FS > {params.fs}" \
             --filter-name "QD{params.qd}" --filter-expression "QD < {params.qd}" 2> {log}
        """

rule SelectVariants:
    input:
        vcf = '04.variant/gatk/{sample}/{sample}.filtered.vcf',
        ref_dict = os.path.splitext(config['parameter']['star_index'][config['Genome_Version']]['genome_fa'])[0] + ".dict",
        ref_fai = config['parameter']['star_index'][config['Genome_Version']]['genome_fa'] + ".fai",
    output:
        vcf = '04.variant/gatk/{sample}/{sample}.final.pass.vcf',
        idx = '04.variant/gatk/{sample}/{sample}.final.pass.vcf.idx'
    conda:
        workflow.source_path("../envs/gatk.yaml")
    log:
        "logs/04.variant/gatk/Select/{sample}.log"
    benchmark:
        "benchmarks/04.variant/gatk/Select/{sample}.txt"
    resources:
        mem_mb = 8192
    threads: 1
    params:
        fasta = config['parameter']['star_index'][config['Genome_Version']]['genome_fa'],
        java_opts = get_java_opts
    shell:
        """
        gatk --java-options "{params.java_opts}" SelectVariants \
             -R {params.fasta} \
             -V {input.vcf} \
             --exclude-filtered \
             -O {output.vcf} 2> {log}
        """

rule bcftools_stats_raw:
    input:
        vcf = '04.variant/gatk/{sample}/{sample}.raw_variants.vcf',
        idx = '04.variant/gatk/{sample}/{sample}.raw_variants.vcf.idx',
    output:
        stats = '04.variant/gatk_bcftools_stats_raw/{sample}.raw_variants.stats'
    conda:
        workflow.source_path("../envs/bcftools.yaml"),
    params:
        fasta = config['parameter']['star_index'][config['Genome_Version']]['genome_fa'],
    log:
        "logs/04.variant/gatk/bcftools_stats/{sample}.log"
    benchmark:
        "benchmarks/04.variant/gatk/bcftools_stats/{sample}.txt"
    resources:
        mem_mb = 8192
    threads: 
        5
    shell:
        """
        bcftools stats --threads {threads} \
                       --fasta-ref {params.fasta} \
                        {input.vcf} > {output.stats} 2>{log}
        """


rule bcftools_stats_pass:
    input:
        vcf = '04.variant/gatk/{sample}/{sample}.final.pass.vcf',
        idx = '04.variant/gatk/{sample}/{sample}.final.pass.vcf.idx'
    output:
        stats = '04.variant/gatk_bcftools_stats_pass/{sample}.final.pass.stats'
    conda:
        workflow.source_path("../envs/bcftools.yaml"),
    params:
        fasta = config['parameter']['star_index'][config['Genome_Version']]['genome_fa'],
    log:
        "logs/04.variant/gatk/bcftools_stats/{sample}.log"
    benchmark:
        "benchmarks/04.variant/gatk/bcftools_stats/{sample}.txt"
    resources:
        mem_mb = 8192
    threads: 
        5
    shell:
        """
        bcftools stats --threads {threads} \
                       --fasta-ref {params.fasta} \
                        {input.vcf} > {output.stats} 2>{log}
        """

rule multiqc_bcftools_stats_raw:
    input:
        stats = expand("04.variant/gatk_bcftools_stats_raw/{sample}.raw_variants.stats",
                            sample=samples.keys()),
    output:
        report = '04.variant/multiqc_gatk_bcftools_stats_raw/multiqc_gatk_bcftools_stats_raw.html',
    conda:
        workflow.source_path("../envs/multiqc.yaml"),
    message:
        "Running MultiQC to aggregate gatk reports",
    benchmark:
        "benchmarks/multiqc_gatk_bcftools_stats_raw.txt",
    params:
        fastqc_reports = "04.variant/gatk_bcftools_stats_raw/",
        report_dir = "04.variant/multiqc_gatk_bcftools_stats_raw/",
        report = "multiqc_gatk_bcftools_stats_raw.html",
        title = "multiqc_gatk_bcftools_stats_raw",
    log:
        "logs/04.variant/multiqc_gatk_bcftools_stats_raw.log",
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

rule multiqc_bcftools_stats_pass:
    input:
        stats = expand("04.variant/gatk_bcftools_stats_pass/{sample}.final.pass.stats",
                            sample=samples.keys()),
    output:
        report = '04.variant/multiqc_gatk_bcftools_stats_pass/multiqc_gatk_bcftools_stats_pass.html',
    conda:
        workflow.source_path("../envs/multiqc.yaml"),
    message:
        "Running MultiQC to aggregate gatk reports",
    benchmark:
        "benchmarks/multiqc_gatk_bcftools_stats_pass.txt",
    params:
        fastqc_reports = "04.variant/gatk_bcftools_stats_pass/",
        report_dir = "04.variant/multiqc_gatk_bcftools_stats_pass/",
        report = "multiqc_gatk_bcftools_stats_pass.html",
        title = "multiqc_gatk_bcftools_stats_pass",
    log:
        "logs/04.variant/multiqc_gatk_bcftools_stats_pass.log",
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
# ------- rule ------- #