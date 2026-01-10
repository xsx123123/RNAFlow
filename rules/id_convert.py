#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import pandas as pd
from pathlib import Path
from rich import print as rprint
from typing import List, Dict, Optional

def _validate_df(df: pd.DataFrame, required_cols: List[str], index_col: str) -> None:
    """
    [内部函数] 校验 DataFrame 的完整性和唯一性
    """
    # Import the unified logger
    from snakemake_logger_plugin_rich_loguru import get_analysis_logger
    logger = get_analysis_logger()

    # 1. 校验必填列是否存在
    missing_cols = [col for col in required_cols if col not in df.columns]
    if missing_cols:
        error_msg = (
            f"❌ 样本表格式错误！\n"
            f"   缺失列: [bold red]{missing_cols}[/bold red]\n"
            f"   必需列: {required_cols}"
        )
        rprint(error_msg) # 使用 rich 打印高亮错误
        logger.error(f"Sample sheet missing columns: {missing_cols}")
        sys.exit(1)

    # 2. 校验索引列 (Sample ID) 是否有重复
    if df[index_col].duplicated().any():
        duplicated_ids = df[df[index_col].duplicated()][index_col].unique().tolist()
        error_msg = (
            f"❌ 样本ID不唯一！检测到重复样本名 (Sample ID):\n"
            f"   [bold red]{duplicated_ids}[/bold red]"
        )
        rprint(error_msg)
        logger.error(f"Duplicate sample IDs found: {duplicated_ids}")
        sys.exit(1)

    # 3. 校验是否有空值 (NaN)
    # 仅检查必填列中的空值
    if df[required_cols].isnull().any().any():
        nan_rows = df[df[required_cols].isnull().any(axis=1)][index_col].tolist()
        logger.warning(f"⚠️ 警告: 以下样本在必填列中存在空值 (NaN/Empty): {nan_rows}")
        # 这里可以选择是报错退出还是仅警告，目前设为警告


def load_samples(csv_path, required_cols=None, index_col="sample"):
    """
    读取 CSV，并【强制】自动生成固定的 BAM 路径。
    不会检查 BAM 文件是否存在。
    """
    # 1. 默认必填列 (不需要 bam，因为我们下面会自动生成)
    if required_cols is None:
        required_cols = [index_col, "group"]

    file_path = Path(csv_path)
    if not file_path.exists():
        print(f"❌ Error: 找不到样本表文件: {file_path}", file=sys.stderr)
        sys.exit(1)

    try:
        # 2. 读取并清洗数据
        df = pd.read_csv(file_path, dtype=str, comment='#')
        df.columns = df.columns.str.strip()
        df = df.apply(lambda x: x.str.strip() if x.dtype == "object" else x)

        # 3. 校验必填列
        missing = [c for c in required_cols if c not in df.columns]
        if missing:
            print(f"❌ Error: 样本表缺失列: {missing}", file=sys.stderr)
            sys.exit(1)

        # 4. 校验 ID 唯一性
        if df[index_col].duplicated().any():
            print(f"❌ Error: 样本 ID 重复", file=sys.stderr)
            sys.exit(1)

        # =========================================================
        # 【核心修改】 自动构建固定 BAM 路径
        # =========================================================
        # 这里只生成路径字符串，【绝对不检查】文件是否存在
        # os.path.abspath 只是处理路径格式，不涉及 IO 操作，是安全的
        df['bam'] = df[index_col].apply(
            lambda x: f"02.mapping/STAR/sort_index/{x}.sort.bam"
        )

        # 5. 转为字典
        return df.set_index(index_col, drop=False).to_dict(orient="index")

    except Exception as e:
        print(f"❌ Error: load_samples 解析失败: {e}", file=sys.stderr)
        sys.exit(1)


def load_contrasts(csv_path, samples_dict):
    """
    解析对比表，并根据 samples_dict 匹配对应的 BAM 文件路径。
    """
    file_path = Path(csv_path)
    if not file_path.exists():
        print(f"❌ Error: 找不到对比表文件: {file_path}", file=sys.stderr)
        sys.exit(1)

    try:
        # 1. 读取并清洗
        df = pd.read_csv(file_path, dtype=str, comment='#')
        df.columns = df.columns.str.strip()
        df = df.apply(lambda x: x.str.strip() if x.dtype == "object" else x)

        if "Control" not in df.columns or "Treat" not in df.columns:
            print(f"❌ Error: contrasts.csv 必须包含 'Control' 和 'Treat' 列", file=sys.stderr)
            sys.exit(1)

        all_contrasts = []
        contrast_map = {}

        # 2. 遍历每一行对比
        for _, row in df.iterrows():
            ctrl_grp = row['Control']
            treat_grp = row['Treat']
            c_name = f"{ctrl_grp}_vs_{treat_grp}"
            
            # 3. 从 samples_dict 中筛选 BAM
            # 因为 load_samples 已经保证了每行都有 'bam' 键，这里可以直接取
            bams_ctrl = [
                info['bam'] for info in samples_dict.values() 
                if info['group'] == ctrl_grp
            ]
            bams_treat = [
                info['bam'] for info in samples_dict.values() 
                if info['group'] == treat_grp
            ]

            # 4. 仅检查是否找到了样本（逻辑检查），不检查文件物理存在
            if not bams_ctrl:
                print(f"⚠️ Warning: 组别 '{ctrl_grp}' 没有任何样本，跳过 {c_name}", file=sys.stderr)
                continue
            if not bams_treat:
                print(f"⚠️ Warning: 组别 '{treat_grp}' 没有任何样本，跳过 {c_name}", file=sys.stderr)
                continue

            all_contrasts.append(c_name)
            contrast_map[c_name] = {
                "b1": bams_ctrl,
                "b2": bams_treat
            }
            
        return all_contrasts, contrast_map

    except Exception as e:
        print(f"❌ Error: load_contrasts 解析失败: {e}", file=sys.stderr)
        sys.exit(1)

# 测试代码 (只有直接运行此脚本时才会执行)
if __name__ == "__main__":
    # 创建一个伪造的 csv 用于测试
    import io
    csv_content = """sample, sample_name, group, fq1
    s1, sample_1, control, s1_1.fq.gz
    s2, sample_2, treatment, s2_1.fq.gz
    """
    # 模拟读取
    print("--- 开始测试 ---")
    try:
        pass 
    except Exception as e:
        print(e)