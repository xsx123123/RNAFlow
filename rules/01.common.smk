#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# loading packages
import os
import glob
from loguru import logger
from pathlib import Path
from typing import Dict, Union
from rich import print as rich_print
# Target rule function
def DataDeliver(config:dict = None) -> list:
    """
    This function performs Bioinformation analysis on the input configuration
    and returns a list of results.
    """
    # short-read raw-data qc result
    data_deliver = ["01.qc/md5_check.tsv",
                    os.path.join('00.raw_data',config['convert_md5']),
                    os.path.join('00.raw_data',config['convert_md5'],"raw_data_md5.json")
                    ]
    # fastq-screen
    if config['parameter']['fastq_screen']['run']:
        data_deliver.extend(expand("01.qc/fastq_screen_r1/{sample}_R1_screen.txt",
                                          sample=samples.keys()))
        data_deliver.extend(expand("01.qc/fastq_screen_r2/{sample}_R2_screen.txt",
                                          sample=samples.keys()))
        data_deliver.append("01.qc/fastq_screen_multiqc_r1/multiqc_r1_fastq_screen_report.html")
        data_deliver.append("01.qc/fastq_screen_multiqc_r2/multiqc_r2_fastq_screen_report.html")
    # fastqc & multiqc
    data_deliver.append("01.qc/short_read_r1_multiqc/multiqc_r1_raw-data_report.html")
    data_deliver.append("01.qc/short_read_r2_multiqc/multiqc_r2_raw-data_report.html")        
    # short-read trim & clean result
    data_deliver.append("01.qc/multiqc_short_read_trim/multiqc_short_read_trim_report.html")
    # mapping
    data_deliver.extend(expand("02.mapping/STAR/sort_index/{sample}.sort.bam",
                                          sample=samples.keys()))
    data_deliver.extend(expand("02.mapping/STAR/sort_index/{sample}.sort.bam.bai",
                                          sample=samples.keys()))
    data_deliver.extend(expand("02.mapping/samtools_flagstat/{sample}_bam_flagstat.tsv",
                                          sample=samples.keys()))
    data_deliver.extend(expand("02.mapping/samtools_stats/{sample}_bam_stats.tsv",
                                          sample=samples.keys()))
    data_deliver.extend(expand("02.mapping/qualimap_report/{sample}/qualimapReport.html",
                                          sample=samples.keys()))
    data_deliver.extend(expand("02.mapping/qualimap_report/{sample}/genome_results.txt",
                                          sample=samples.keys()))
    # bamcoverage
    data_deliver.extend(expand(f"02.mapping/bamCoverage/{{sample}}_{config['parameter']['bamCoverage']['normalizeUsing']}.bw",
                                          sample=samples.keys()))
    
    # count
    data_deliver.extend(expand("03.count/rsem/{sample}.genes.results",
                                          sample=samples.keys()))
    data_deliver.extend(expand("03.count/rsem/{sample}.isoforms.results",
                                          sample=samples.keys()))

    if config['call_variant']:
        data_deliver.extend(expand("04.variant/gatk/{sample}/{sample}.final.pass.vcf",
                                          sample=samples.keys()))
        data_deliver.extend(expand("04.variant/gatk/{sample}/{sample}.final.pass.vcf.idx",
                                          sample=samples.keys()))
        data_deliver.extend(expand("04.variant/gatk_bcftools_stats_raw/{sample}.raw_variants.stats",
                                          sample=samples.keys()))
        data_deliver.extend(expand("04.variant/gatk_bcftools_stats_pass/{sample}.final.pass.stats",
                                          sample=samples.keys()))
        data_deliver.append('04.variant/multiqc_gatk_bcftools_stats_raw/multiqc_gatk_bcftools_stats_raw.html')
        data_deliver.append('04.variant/multiqc_gatk_bcftools_stats_pass/multiqc_gatk_bcftools_stats_pass.html')

    if config['noval_Transcripts']:
        data_deliver.append("05.assembly/filter/novel_transcripts.gtf")
        data_deliver.append("05.assembly/filter/final_all.gtf")

    if config['print_target']:
       rich_print(data_deliver)
    return  data_deliver

def get_sample_data_dir(sample_id: str = None, config: dict = None) -> str:
    """
    根据 sample_id 查找包含 fastq 文件的目录。
    
    逻辑更新：
    1. 优先查找是否存在以 sample_id 命名的【子目录】。
    2. 如果子目录不存在，则查找该目录下是否存在以 sample_id 开头的【文件】。
       如果存在文件，则返回该 base_dir。
    """
    
    # 确保 config 里有这个 key，防止报错
    if "raw_data_path" not in config:
        raise ValueError("Config dictionary missing 'raw_data_path' key.")

    # 遍历配置中的所有原始数据路径
    for base_dir in config["raw_data_path"]:
        
        # --- 情况 A: 也就是你之前的逻辑 (raw_data/SampleID/xxx.fq) ---
        sample_subdir = os.path.join(base_dir, sample_id)
        if os.path.isdir(sample_subdir):
            return sample_subdir
        
        # --- 情况 B: 也就是你现在的 ls 结果 (raw_data/SampleID.R1.fq) ---
        # 我们使用 glob 模糊匹配：查看该目录下是否有以 sample_id 开头的文件
        # pattern 类似于: /data/.../00.raw_data/L1MKK1806607-a1*
        pattern = os.path.join(base_dir, f"{sample_id}*")
        
        # 获取匹配的文件列表
        matching_files = glob.glob(pattern)
        
        # 只要找到了匹配的文件（并且是文件而不是文件夹），就说明数据在 base_dir 这一层
        if matching_files:
            # 简单的过滤：确保找到的是文件 (防止碰巧有一个叫 SampleID_tmp 的文件夹)
            # 只要有一个是文件，我们就认为找到了
            if any(os.path.isfile(f) for f in matching_files):
                return base_dir
                
    # 如果循环结束还没找到
    raise FileNotFoundError(f"无法在 {config['raw_data_path']} 中找到 {sample_id} 的数据目录或文件")

def get_all_input_dirs(sample_keys:str = None,
                       config:dict = config) -> list:
    """
    遍历所有样本 ID，调用 get_sample_data_dir，
    返回一个包含所有数据目录的列表。
    """
    dir_list = []
    for sample_id in sample_keys:
        dir_list.append(get_sample_data_dir(sample_id,config = config))
    print(dir_list)
    return list(set(dir_list))

def judge_bwa_index(config:dict = None) -> bool:
    """
    判断是否需要重新构建bwa索引
    """
    bwa_index = config['bwa_mem2']['index']
    bwa_index_files = [bwa_index + suffix for suffix in ['.0123', '.amb', '.ann', '.bwt.2bit.64', '.pac', '.alt']]
    
    return not all(os.path.exists(f) for f in bwa_index_files)

def judge_star_index(config: dict, Genome_Version: str) -> bool:
    """
    判断是否需要重新构建 STAR 索引
    Returns:
        True: 文件缺失，需要构建
        False: 文件完整，不需要构建
    """

    try:
        star_config = config['parameter']['star_index'][Genome_Version]
        index_dir = star_config['index']
    except KeyError:
        print(f"Error: Genome Version '{Genome_Version}' not found in config or structure incorrect.")
        sys.exit(1)

    if not os.path.isdir(index_dir):
        return True 

    required_files = [
        "chrLength.txt",
        "exonGeTrInfo.tab",
        "genomeParameters.txt",
        "sjdbInfo.txt",
        "chrNameLength.txt",
        "exonInfo.tab",
        "Log.out",
        "sjdbList.fromGTF.out.tab",
        "chrName.txt",
        "geneInfo.tab",
        "SA",
        "sjdbList.out.tab",
        "chrStart.txt",
       " Genome",
        "SAindex",
        "transcriptInfo.tab"
    ]
    
    full_paths = [os.path.join(index_dir, f) for f in required_files]

    missing_files = [f for f in full_paths if not os.path.exists(f)]
    
    if missing_files:
        return True
    
    return False

# --------------------- #
