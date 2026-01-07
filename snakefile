#!/usr/bin/env python3
# *---utf-8---*
# Version: RNAFlow_v0.1
# Author : JZHANG

# ------- snakemake version check ------- #
from snakemake.utils import min_version, validate
# 从本地 rules 模块导入自定义辅助函数 (样本解析、路径校验等)
from rules.id_convert import load_samples, _validate_df, load_contrasts
from rules.validate import check_reference_paths

# 锁定 Snakemake 最低版本，确保新特性可用
min_version("9.9.0")

# --------- main snakefile --------- #
# 加载全局配置文件 (注意：config.yaml 中的参数会覆盖 config/config.yaml 中的同名参数)
configfile: "config/config.yaml"
configfile: "config/reference.yaml"
configfile: "config/run_parameter.yaml"
configfile: "config.yaml"

# 1. 验证配置文件结构是否符合 Schema 定义
# 2. 预先检查参考基因组相关文件路径是否存在 (避免跑了一半报错)
validate(config, "schema/config.schema.yaml") 
check_reference_paths(config["STAR_index"])

# --------- workspaces --------- #
# 指定流程运行的根目录 (所有输出文件将基于此路径)
workdir: config["workflow"]

# ----   input sample info   ---- #
# 解析样本元数据 CSV，提取样本名及分组
samples = load_samples(config["sample_csv"], required_cols=["sample", "sample_name", "group"])
# 解析配对比较信息 (Contrasts)
ALL_CONTRASTS, CONTRAST_MAP = load_contrasts(config["paired_csv"], samples)

# --------- snakemake rule --------- #
# 模块化导入：按分析步骤引入子规则文件
include: 'rules/00.log.smk'               # 日志记录模块
include: 'rules/01.common.smk'            # 通用函数与通配符约束
include: 'rules/03.file_convert_md5.smk'  # 格式转换与 MD5 校验
include: 'rules/04.short_read_qc.smk'     # 原始数据质控 (QC)
include: 'rules/05.Contamination_check.smk' # 污染筛查
include: 'rules/06.short_read_clean.smk'  # 数据清洗 (去接头/低质量)
include: 'rules/07.mapping.smk'           # 序列比对 (STAR)
include: 'rules/08.rsem.smk'              # 表达量定量 (RSEM)
include: 'rules/09.call_variant.smk'      # 变异检测流程
include: 'rules/10.Assembly.smk'          # 转录本组装
include: 'rules/11.DEG.smk'               # 差异表达分析
include: 'rules/12.rMATS.smk'             # 可变剪接分析

# ---- check genome version  ---- #
# 运行时的额外检查：确认参考基因组版本信息并记录日志
check_gene_version(config=config, logger=logger)

# --------- target rule --------- #
# 终点规则：驱动整个流程，收集 DataDeliver 函数定义的所有最终交付文件
rule all:
    input:
        DataDeliver(config=config)