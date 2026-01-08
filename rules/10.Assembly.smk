#!/usr/bin/snakemake
# -*- coding: utf-8 -*-

rule StringTie_Assembly:
    input:
        bam = "02.mapping/STAR/sort_index/{sample}.sort.bam",
        gtf = config['STAR_index'][config['Genome_Version']]['genome_gff'],
    output:
        gtf = "05.assembly/stringtie/{sample}.gtf"
    conda:
        workflow.source_path("../envs/stringtie.yaml"),
    log:
        "logs/05.assembly/stringtie/{sample}.log",
    benchmark:
        "benchmarks/05.assembly/stringtie/{sample}.txt",
    threads: 
        config['parameter']['threads']['stringtie'],
    shell:
        """
        stringtie {input.bam} \
            -G {input.gtf} \
            -o {output.gtf} \
            -p {threads} \
            -l {wildcards.sample} 2> {log}
        """

rule StringTie_Merge:
    input:
        gtfs = expand("05.assembly/stringtie/{sample}.gtf",
                      sample=samples.keys()),
        ref_gtf = config['STAR_index'][config['Genome_Version']]['genome_gff'],
    output:
        merged_gtf = "05.assembly/stringtie/merged.gtf",
        gtf_list = "05.assembly/stringtie/mergelist.txt",
    conda:
        workflow.source_path("../envs/stringtie.yaml"),
    log:
        "logs/05.assembly/stringtie/merge.log"
    benchmark:
        "benchmarks/05.assembly/stringtie/merge.txt"
    threads: 
        config['parameter']['threads']['stringtie'],
    params:
        min_len = config['parameter']['stringtie']['min_length'],
        min_cov = config['parameter']['stringtie']['min_cov'],
        min_fpkm = config['parameter']['stringtie']['min_fpkm'],
    shell:
        """
        (ls {input.gtfs} > {output.gtf_list} && \
        stringtie --merge \
            -p {threads} \
            -G {input.ref_gtf} \
            -o {output.merged_gtf} \
            -m {params.min_len} \
            -c {params.min_cov} \
            -F {params.min_fpkm} \
            {output.gtf_list}) 2> {log}
        """

rule GffCompare:
    input:
        merged_gtf = "05.assembly/stringtie/merged.gtf",
        ref_gtf = config['STAR_index'][config['Genome_Version']]['genome_gff'],
    output:
        annotated_gtf = "05.assembly/gffcompare/stringtie.annotated.gtf",
        stats = "05.assembly/gffcompare/stringtie.stats",
        tracking = "05.assembly/gffcompare/stringtie.tracking",
    conda:
        workflow.source_path("../envs/gffcompare.yaml"),
    log:
        "logs/05.assembly/gffcompare/gffcompare.log",
    benchmark:
        "benchmarks/05.assembly/gffcompare/gffcompare.txt",
    params:
        out_prefix = "05.assembly/gffcompare/stringtie",
    threads:
        1
    shell:
        """
        gffcompare -r {input.ref_gtf} \
                   -o {params.out_prefix} \
                   {input.merged_gtf} 2> {log}
        """

rule Filter_Novel_Transcripts:
    input:
        annotated_gtf = "05.assembly/gffcompare/stringtie.annotated.gtf",
    output:
        novel_gtf = "05.assembly/filter/novel_transcripts.gtf",
        final_gtf = "05.assembly/filter/final_Novel_Isoforms.gtf",
    log:
        "logs/05.assembly/filter/filter.log"
    threads: 1
    run:
        # 定义需要保留的类别
        # =: 完全匹配参考基因组
        # j: 新发现的异构体 (Novel Isoform)
        valid_codes = set(['=', 'j'])
        
        # 第一步：扫描一遍文件，记录下符合要求的 transcript_id
        valid_transcripts = set()
        
        with open(input.annotated_gtf, 'r') as f:
            for line in f:
                if line.startswith('#'): continue
                parts = line.strip().split('\t')
                if len(parts) < 9: continue
                
                # 只检查 feature 为 "transcript" 的行来获取 class_code
                if parts[2] == 'transcript':
                    attr_str = parts[8]
                    
                    # 提取 class_code
                    # 格式通常为 class_code "=";
                    if 'class_code' in attr_str:
                        # 简单的字符串查找
                        try:
                            code_start = attr_str.find('class_code "') + 12
                            code = attr_str[code_start] # 获取引号后的一个字符
                            
                            if code in valid_codes:
                                # 提取 transcript_id
                                # 格式 transcript_id "ID";
                                tid_start = attr_str.find('transcript_id "') + 15
                                tid_end = attr_str.find('"', tid_start)
                                tid = attr_str[tid_start:tid_end]
                                valid_transcripts.add(tid)
                        except:
                            continue

        # 第二步：再次扫描，输出所有属于 valid_transcripts 的行 (transcript 和 exon)
        with open(input.annotated_gtf, 'r') as fin, \
             open(output.final_gtf, 'w') as f_final, \
             open(output.novel_gtf, 'w') as f_novel:
            
            for line in fin:
                if line.startswith('#'): continue
                parts = line.strip().split('\t')
                if len(parts) < 9: continue
                
                attr_str = parts[8]
                
                # 每一行肯定都有 transcript_id，提取出来检查是否在白名单里
                if 'transcript_id "' in attr_str:
                    tid_start = attr_str.find('transcript_id "') + 15
                    tid_end = attr_str.find('"', tid_start)
                    tid = attr_str[tid_start:tid_end]
                    
                    if tid in valid_transcripts:
                        # 写入 final_gtf
                        f_final.write(line)
                        
                        # 如果需要 novel_gtf，这里简单判断一下（稍微粗糙点，但够用）
                        # 注意：exon 行没有 class_code，所以这里很难准确分出 novel exon
                        # 建议：novel_gtf 仅用于人工查看 transcript 行，或者用更复杂的逻辑
                        # 这里为了简单，只把带有 class_code "j" 的 transcript 行写入 novel_gtf 方便你查看
                        if parts[2] == 'transcript' and 'class_code "j"' in attr_str:
                            f_novel.write(line)
# ------- rule ------- #