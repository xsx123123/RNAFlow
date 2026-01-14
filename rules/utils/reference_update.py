#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os

def resolve_reference_paths(config, targets, base_path=None):
    """
    解析并更新参考基因组的绝对路径。

    Args:
        config (dict): Snakemake 的配置字典
        targets: 目标基因组版本，可以是单个字符串 (e.g. "ITAG4.1")
                 也可以是字符串列表 (e.g. ["ITAG4.1", "Lsat_Salinas_v11"])
        base_path (str, optional): 参考基因组的根目录路径。
                                   如果不传，默认尝试从 config['reference_path'] 获取。
    """
    # Import the unified logger
    from snakemake_logger_plugin_rich_loguru import get_analysis_logger
    logger = get_analysis_logger()

    # 0. 确定根目录 (参数优先级 > config优先级)
    # 如果调用函数时传了 base_path，就用它；否则尝试从 config 里取
    root_dir = base_path or config.get("reference_path")

    if not root_dir:
        # 既没传参数，config 里也没有，那就没法拼了
        return

    # 1. 统一转为列表处理
    if isinstance(targets, str):
        genome_list = [targets]
    elif isinstance(targets, list):
        genome_list = targets
    else:
        logger.error(f"无法解析 targets 参数类型: {type(targets)}，跳过路径更新。")
        return

    # logger.info(f"正在批量更新参考基因组路径: {genome_list} (Base: {root_dir})")

    # 2. 循环处理列表中的每一个基因组版本
    star_index_config = config.get("STAR_index", {})

    for version in genome_list:
        ref_dict = star_index_config.get(version)

        # 如果这个版本在 STAR_index 里不存在，就跳过
        if not ref_dict:
            logger.warning(f"{version} 未在 STAR_index 中定义，跳过。")
            continue

        # 3. 更新路径
        count = 0
        for key, value in ref_dict.items():
            if isinstance(value, str):
                if not value.startswith(root_dir) and not value.startswith("/"):
                    full_path = os.path.join(root_dir, value)
                    ref_dict[key] = full_path
                    count += 1

        if count > 0:
            # logger.success(f"[{version}] 成功更新了 {count} 个文件路径")
            pass