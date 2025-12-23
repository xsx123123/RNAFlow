#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# loading packages
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
    data_deliver = ["../01.qc/md5_check.tsv",
                    os.path.join('../00.raw_data',config['convert_md5']),
                    os.path.join('../00.raw_data',config['convert_md5'],"raw_data_md5.json")
                    ]
    # fastq-screen
    if config['fastq_screen']['run']:
        data_deliver.extend(expand("../01.qc/fastq_screen_r1/{sample}_R1_screen.txt",
                                          sample=samples.keys()))
        data_deliver.extend(expand("../01.qc/fastq_screen_r2/{sample}_R2_screen.txt",
                                          sample=samples.keys()))
        data_deliver.append("../01.qc/fastq_screen_multiqc_r1/multiqc_r1_fastq_screen_report.html")
        data_deliver.append("../01.qc/fastq_screen_multiqc_r2/multiqc_r2_fastq_screen_report.html")
    # fastqc & multiqc
    data_deliver.append("../01.qc/short_read_r1_multiqc/multiqc_r1_raw-data_report.html")
    data_deliver.append("../01.qc/short_read_r2_multiqc/multiqc_r2_raw-data_report.html")        
    # short-read trim & clean result
    data_deliver.append("../01.qc/multiqc_short_read_trim/multiqc_short_read_trim_report.html")
    if config['print_target']:
       rich_print(data_deliver)
    return  data_deliver

def get_sample_data_dir(sample_id:str = None,
                        config:dict = None) -> str:
    """
    根据 *具体的* sample_id (e.g., "Sample_A"),
    查找 *包含* fastq 文件的 *目录*。
    
    注意：我修改了它，使其不再依赖 wildcards，
    而是直接接收 sample_id 字符串。
    """
    
    for base_dir in config["raw_data_path"]:
        sample_dir = os.path.join(base_dir, sample_id)
        if os.path.isdir(sample_dir):
            return sample_dir
                
    raise FileNotFoundError(f"无法在 {config['raw_data_path']} 中找到 {sample_id} 的数据目录")

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

# --------------------- #
