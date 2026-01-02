#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import pandas as pd
from pathlib import Path
from loguru import logger
from rich import print as rprint
from typing import List, Dict, Optional

def _validate_df(df: pd.DataFrame, required_cols: List[str], index_col: str) -> None:
    """
    [内部函数] 校验 DataFrame 的完整性和唯一性
    """
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

def load_samples(
    csv_path: str, 
    required_cols: Optional[List[str]] = None, 
    index_col: str = "sample"
) -> Dict:
    """
    加载并清洗样本CSV文件，返回供 Snakemake 使用的字典。
    
    Args:
        csv_path (str): CSV文件路径
        required_cols (list): 必须存在的列名列表
        index_col (str): 用作字典 Key 的列名（通常是样本ID）
        
    Returns:
        dict: {sample_id: {col1: val1, col2: val2, ...}}
    """
    
    # 默认必填列
    if required_cols is None:
        required_cols = ["sample", "sample_name", "group"]
    
    # 确保 index_col 在 required_cols 里
    if index_col not in required_cols:
        required_cols.append(index_col)

    file_path = Path(csv_path)
    
    if not file_path.exists():
        logger.critical(f"❌ 找不到样本文件: {file_path.absolute()}")
        sys.exit(1)

    try:
        # 1. 读取数据
        # dtype=str 非常重要：防止纯数字的样本名（如 "001"）被解析为整数 1
        df = pd.read_csv(file_path, dtype=str)
        
        # 2. 数据清洗
        # 去除列名的首尾空格
        df.columns = df.columns.str.strip()
        
        # 去除所有字符串内容的首尾空格 (防止 "group " != "group")
        df = df.apply(lambda x: x.str.strip() if x.dtype == "object" else x)

        # 3. 执行校验
        _validate_df(df, required_cols, index_col)
        
        # 4. 转换为字典
        # orient="index" 结构: {'sample_A': {'sample': 'sample_A', 'group': 'Ctrl'}, ...}
        # drop=False 保留 sample 列在 value 中，方便后续提取
        samples_dict = df.set_index(index_col, drop=False).to_dict(orient="index")
        
        logger.success(f"✅ 成功加载样本表: {file_path} (共 {len(samples_dict)} 个样本)")
        
        # 调试模式下可以把这一行解注释
        # rprint(samples_dict)
        
        return samples_dict

    except pd.errors.EmptyDataError:
        logger.critical(f"❌ 样本文件为空: {file_path}")
        sys.exit(1)
    except Exception as e:
        logger.critical(f"❌ 解析样本表时发生未捕获异常: {e}")
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