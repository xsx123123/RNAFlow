#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import yaml
from typing import Dict, Any, List
from snakemake.utils import update_config
from rich.console import Console
from rich.table import Table
from rich.text import Text
from rich import box
from rich.align import Align
from rich.padding import Padding

def check_reference_paths(ref_dict):
    """
    Rich 美化版（现代极简风）：检查参考基因组文件路径。
    """
    console = Console()
    
    if not ref_dict:
        # 警告也可以稍微现代一点
        msg = Text("⚠ Warning: Reference dictionary is empty!", style="bold yellow")
        console.print(Align.center(msg))
        return

    keys_to_check = ["index", "genome_fa", "genome_gtf", "genome_gff", "rsem_index_dir"]
    missing_entries = []

    # 状态栏保持简洁
    with console.status("[bold cyan]Scanning reference configuration...", spinner="dots2"):
        for genome_name, params in ref_dict.items():
            if not isinstance(params, dict):
                continue
            for key, path in params.items():
                if key in keys_to_check and path and not os.path.exists(path):
                    missing_entries.append((genome_name, key, path))

    if missing_entries:
        # --- 1. 顶部标题 ---
        # 使用 Rule 创建一个横穿屏幕的标题线，既醒目又不臃肿
        console.print()
        console.rule("[bold red]🚨 CONFIGURATION ERROR[/]", style="red")
        console.print()

        # --- 2. 创建现代表格 ---
        # box.SIMPLE_HEAD 只保留表头下的一条线，非常干净
        # 或者 box.SIMPLE 保留简单的横线
        table = Table(
            box=box.SIMPLE_HEAD, 
            show_header=True,
            header_style="bold red",
            collapse_padding=True,
            pad_edge=False,
            row_styles=["none", "dim"] # 隔行变暗，增加层次感
        )
        
        # 定义列 (文字全部居中)
        table.add_column("Genome Version", style="bold cyan", justify="center", width=20)
        table.add_column("Missing Key", style="yellow", justify="center", width=20)
        table.add_column("Target Path (Not Found)", style="white", justify="center") # 路径保持白色，醒目

        for genome, key, path in missing_entries:
            table.add_row(genome, key, path)

        # --- 3. 整体居中展示 ---
        # 使用 Align.center 让表格悬浮在终端中间
        # 使用 Padding 增加一点上下呼吸感
        console.print(Align.center(Padding(table, (1, 2))))

        # --- 4. 底部提示 ---
        console.print()
        console.print(Align.center("[grey50]Please verify the paths in [bold]config.yaml[/] and try again.[/]"))
        console.rule(style="red")
        console.print()
        
        sys.exit(1)
    else:
        # 成功提示：简洁有力
        console.print(Align.center("#####   --------------- Validation Complete  ---------------   #####"),style="yellow")
        console.print()
        console.print(Align.center("[bold green]✔ System Check Passed[/]"), style="green")
        console.print(Align.center(f"[dim]Verified references for {len(ref_dict)} genomes[/]"))
        console.print()
        console.print(Align.center("#####   --------------- Validation Complete  ---------------   #####"),style="yellow")

def load_user_config(config, cmd_arg_name="user_yaml") -> None:
    """
    解析命令行传递的配置文件路径，并将其合并到当前 config 中。
    
    参数:
    config (dict): Snakemake 的全局 config 对象
    cmd_arg_name (str): 命令行 --config 后面的键名，默认为 "user_yaml"
    """
    custom_path = config.get(cmd_arg_name)

    # 如果用户没传这个参数，直接返回，使用默认配置
    if not custom_path:
        return

    # 2. 检查文件是否存在
    if not os.path.exists(custom_path):
        # 红色报错信息，方便在日志中看到
        sys.exit(f"\n\033[91m[Config Error] 找不到指定的用户配置文件: {custom_path}\033[0m\n请检查路径是否正确。\n")

    # 3. 加载并合并配置
    print(f"\033[92m[Config Info] 正在加载外部项目配置: {custom_path}\033[0m")
    
    try:
        with open(custom_path, 'r') as f:
            custom_data = yaml.safe_load(f)
        
        if custom_data:
            # 核心步骤：update_config 会递归合并字典
            # 这里的 custom_data 会覆盖 config 中已有的同名 Key
            update_config(config, custom_data)
        else:
            print(f"[Config Warning] 文件 {custom_path} 内容为空，跳过加载。")

    except Exception as e:
        sys.exit(f"\n[Config Error] 解析 YAML 文件失败: {e}\n")

def validate_genome_version(config: Dict[str, Any], logger = None) -> str:
    """
    Validates if the specified 'Genome_Version' in config is supported.

    Args:
        config (dict): Configuration dictionary containing 'Genome_Version'
                       and 'can_use_genome_version'.
        logger (logging.Logger): Logger instance.

    Returns:
        str: The validated genome version string (clean and ready to use).

    Raises:
        ValueError: If config is invalid or version is not supported.
    """
    # Use the provided logger or get the unified logger
    if logger is None:
        from snakemake_logger_plugin_rich_loguru import get_analysis_logger
        logger = get_analysis_logger()

    # 1. 基础对象检查
    if not config:
        raise ValueError("Config dictionary cannot be empty.")

    # 2. 安全获取参数
    raw_version = config.get('Genome_Version')
    allowed_list = config.get('can_use_genome_version')

    # 3. 检查配置项是否存在
    if not raw_version or not allowed_list:
        msg = "Config missing required keys: 'Genome_Version' or 'can_use_genome_version'."
        logger.error(msg)
        raise ValueError(msg)

    # 4. 确保 allowed_list 是列表类型 (防御性编程)
    if not isinstance(allowed_list, list):
        msg = f"'can_use_genome_version' must be a list, got {type(allowed_list)}."
        logger.error(msg)
        raise TypeError(msg)

    # 5. 数据清洗与标准化 (关键优化点)
    # 去除首尾空格，并不区分大小写比较 (可选，视具体需求定)
    clean_version = str(raw_version).strip()

    # 核心校验逻辑
    if clean_version in allowed_list:
        logger.info(f"Genome version verified: '{clean_version}' is supported.")
        return clean_version
    else:
        # 错误信息更友好，列出支持的列表
        msg = (f"Unsupported genome version: '{clean_version}'. "
               f"Supported versions are: {allowed_list}")
        logger.error(msg)
        raise ValueError(msg)