import os
import sys
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
        console.print()
        console.print(Align.center("[bold green]✔ System Check Passed[/]"), style="green")
        console.print(Align.center(f"[dim]Verified references for {len(ref_dict)} genomes[/]"))
        console.print()