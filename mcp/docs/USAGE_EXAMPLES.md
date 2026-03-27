# RNAFlow MCP 使用示例

## 快速开始 - 推荐方式

### 方式一：使用 setup_complete_project 一键设置（最简单）

```python
# 一站式设置 - 自动创建目录结构、配置文件、样本表
setup_complete_project(
    project_root="/data/jzhang/project/Temp/rna_skills_analysis",
    project_name="lettuce_rnaseq_qc",
    genome_version="Lsat_Salinas_v8",
    species="Lactuca sativa",
    analysis_mode="qc_only",  # 或 "standard" 或 "complete"
    client="Research_Lab",
    library_types="fr-firststrand"
)
```

这会自动创建：
- `/data/jzhang/project/Temp/rna_skills_analysis/00.raw_data/`
- `/data/jzhang/project/Temp/rna_skills_analysis/01.workflow/`
- `/data/jzhang/project/Temp/rna_skills_analysis/02.data_deliver/`
- `config.yaml`
- `samples.csv` (模板)
- `contrasts.csv` (模板)

### 方式二：分步设置

```python
# Step 1: 创建目录结构
create_project_structure("/data/jzhang/project/Temp/rna_skills_analysis")

# Step 2: 获取配置模板
get_config_template("qc_only")

# Step 3: 生成完整配置
# (需要先创建 ProjectConfig 对象，或使用 setup_complete_project)
```

## 工具名称对照

| 新工具名 (蛇形) | 旧工具名 (驼峰) |
|-----------------|-----------------|
| `generate_config_file` | `rnaflowGenerateConfigFile` |
| `create_project_structure` | `createProjectStructure` |
| `setup_complete_project` | `setupCompleteProject` |
| `create_sample_csv` | `createSampleCsv` |
| `create_contrasts_csv` | `createContrastsCsv` |

两种命名方式都支持！

## 分析模式说明

| 模式 | 说明 |
|------|------|
| `qc_only` | 仅做质量控制（最快） |
| `standard` | 标准 DEG 分析（推荐） |
| `complete` | 完整分析（包含变异检测、可变剪接等） |

## 目录结构

```
project_root/
├── 00.raw_data/        # 放置 FASTQ 文件
├── 01.workflow/        # 配置文件、样本表
│   ├── config.yaml
│   ├── samples.csv
│   └── contrasts.csv
└── 02.data_deliver/    # 分析结果输出
```
