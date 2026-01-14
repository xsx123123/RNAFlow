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
    Rich-styled (modern minimalist): Check reference genome file paths.
    """
    console = Console()
    
    if not ref_dict:
        # Warning can also be a bit more modern
        msg = Text("⚠ Warning: Reference dictionary is empty!", style="bold yellow")
        console.print(Align.center(msg))
        return

    keys_to_check = ["index", "genome_fa", "genome_gtf", "genome_gff", "rsem_index_dir"]
    missing_entries = []

    # Keep status bar concise
    with console.status("[bold cyan]Scanning reference configuration...", spinner="dots2"):
        for genome_name, params in ref_dict.items():
            if not isinstance(params, dict):
                continue
            for key, path in params.items():
                if key in keys_to_check and path and not os.path.exists(path):
                    missing_entries.append((genome_name, key, path))

    if missing_entries:
        # --- 1. Top title ---
        # Use Rule to create a full-screen title line that is both prominent and not bloated
        console.print()
        console.rule("[bold red]🚨 CONFIGURATION ERROR[/]", style="red")
        console.print()

        # --- 2. Create modern table ---
        # box.SIMPLE_HEAD only keeps a line under the header, very clean
        # or box.SIMPLE keeps simple horizontal lines
        table = Table(
            box=box.SIMPLE_HEAD,
            show_header=True,
            header_style="bold red",
            collapse_padding=True,
            pad_edge=False,
            row_styles=["none", "dim"] # Alternate rows dimmed for hierarchy
        )
        
        # Define columns (all text centered)
        table.add_column("Genome Version", style="bold cyan", justify="center", width=20)
        table.add_column("Missing Key", style="yellow", justify="center", width=20)
        table.add_column("Target Path (Not Found)", style="white", justify="center") # Keep path white for visibility

        for genome, key, path in missing_entries:
            table.add_row(genome, key, path)

        # --- 3. Center display ---
        # Use Align.center to float the table in the middle of the terminal
        # Use Padding to add some breathing space above and below
        console.print(Align.center(Padding(table, (1, 2))))

        # --- 4. Bottom prompt ---
        console.print()
        console.print(Align.center("[grey50]Please verify the paths in [bold]config.yaml[/] and try again.[/]"))
        console.rule(style="red")
        console.print()
        
        sys.exit(1)
    else:
        # Success message: concise and powerful
        console.print(Align.center("#####   --------------- Validation Complete  ---------------   #####"),style="yellow")
        console.print()
        console.print(Align.center("[bold green]✔ System Check Passed[/]"), style="green")
        console.print(Align.center(f"[dim]Verified references for {len(ref_dict)} genomes[/]"))
        console.print()
        console.print(Align.center("#####   --------------- Validation Complete  ---------------   #####"),style="yellow")

def load_user_config(config, cmd_arg_name="user_yaml") -> None:
    """
    Parse the configuration file path passed from the command line and merge it into the current config.

    Args:
    config (dict): Snakemake's global config object
    cmd_arg_name (str): The key name after --config in command line, defaults to "user_yaml"
    """
    custom_path = config.get(cmd_arg_name)

    # If the user didn't pass this parameter, return directly and use the default configuration
    if not custom_path:
        return

    # 2. Check if the file exists
    if not os.path.exists(custom_path):
        # Red error message, easy to see in logs
        sys.exit(f"\n\033[91m[Config Error] Cannot find the specified user configuration file: {custom_path}\033[0m\nPlease check if the path is correct.\n")

    # 3. Load and merge configuration
    print(f"\033[92m[Config Info] Loading external project configuration: {custom_path}\033[0m")
    
    try:
        with open(custom_path, 'r') as f:
            custom_data = yaml.safe_load(f)
        
        if custom_data:
            # Core step: update_config will recursively merge dictionaries
            # Here, custom_data will override existing keys with the same name in config
            update_config(config, custom_data)
        else:
            print(f"[Config Warning] File {custom_path} is empty, skipping loading.")

    except Exception as e:
        sys.exit(f"\n[Config Error] Failed to parse YAML file: {e}\n")

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