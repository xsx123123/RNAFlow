# RNAFlow - RNA-seq 分析流程

RNAFlow 是一个基于 Snakemake 的综合性 RNA-seq 数据分析流程。它提供了从原始数据质量控制到表达量定量、变异检测和转录本组装的完整工作流程。

## 目录
- [概述](#概述)
- [流程工作流](#流程工作流)
- [目录结构](#目录结构)
- [安装](#安装)
- [配置](#配置)
- [使用方法](#使用方法)
- [依赖项](#依赖项)
- [输出](#输出)

## 概述

RNAFlow 旨在使用 STAR 进行比对、RSEM 进行定量，并使用其他工具进行质量控制、变异检测和转录本组装来分析 RNA-seq 数据。该流程将代码与分析数据分离，将工作流程定义保存在流程目录中，同时在单独的分析目录中处理数据。

**版本：** RNAFlow_v0.1  
**作者：** JZHANG

## 流程工作流

RNAFlow 流程包括以下步骤：

1. **日志设置**：初始化日志记录和工作流程管理
2. **通用设置**：设置样本信息和通用参数
3. **ID 转换**：根据需要转换样本 ID
4. **文件转换和 MD5 检查**：验证文件完整性并创建符号链接
5. **质量控制**：
   - 使用 FastQC 进行原始数据质量评估
   - 生成 MultiQC 报告
6. **污染检查**：检查样本污染
7. **数据清理**：
   - 使用 fastp 进行接头修剪
   - 质量过滤
8. **读段比对**：
   - 构建 STAR 参考索引
   - 使用 STAR 进行比对
   - 对 BAM 文件进行排序和索引
   - 使用 Qualimap、Samtools 进行质量评估
9. **表达量定量**：
   - 构建 RSEM 参考索引
   - 使用 RSEM 进行基因和转录本表达量定量
10. **变异检测**：从 RNA-seq 数据中检测变异（可选）
11. **转录本组装**：使用 StringTie 组装新转录本（可选）

## 目录结构

```
RNAFlow/
├── snakefile                    # 主 Snakemake 工作流程文件
├── config.yaml                  # 主配置文件
├── README.md                    # 本文件
├── config/                      # 配置目录
│   └── config.yaml              # 详细参数配置
├── envs/                        # Conda 环境定义
│   ├── bcftools.yaml
│   ├── bwa2.yaml
│   ├── deeptools.yaml
│   ├── fastp.yaml
│   ├── fastqc.yaml
│   ├── gatk.yaml
│   ├── multiqc.yaml
│   ├── picard.yaml
│   ├── qualimap.yaml
│   ├── rsem.yaml
│   ├── star.yml
│   └── stringtie.yaml
└── rules/                       # 规则定义
    ├── 00.log.smk              # 日志设置
    ├── 01.common.smk           # 通用函数和样本设置
    ├── 02.id_convert.smk       # 样本 ID 转换
    ├── 03.file_convert_md5.smk # 文件完整性检查和链接
    ├── 04.short_read_qc.smk    # 使用 FastQC/MultiQC 进行质量控制
    ├── 05.Contamination_check.smk # 污染检测
    ├── 06.short_read_clean.smk # 使用 fastp 进行数据清理
    ├── 07.mapping.smk          # 使用 STAR 进行比对
    ├── 08.rsem.smk             # 使用 RSEM 进行表达量定量
    ├── 09.call_variant.smk     # 变异检测
    └── 10.Assembly.smk         # 转录本组装
```

## 安装

1. 克隆仓库：
```bash
git clone <repository-url>
cd RNAFlow
```

2. 确保已安装支持 conda 的 Snakemake：
```bash
# 通过 conda 安装 snakemake
conda install -c conda-forge -c bioconda snakemake
# 或通过 pip 安装
pip install snakemake
```

3. 该流程使用 conda 环境管理依赖项，这些依赖项将在执行期间自动创建。

## 配置

该流程使用两个配置文件：

### 主配置文件 (`config.yaml`)
位于根目录，该文件指定：
- 项目名称
- 参考基因组版本（Lsat_Salinas_v8 或 Lsat_Salinas_v11）
- 输入数据路径
- 样本信息文件
- 工作流程和输出目录

### 详细配置 (`config/config.yaml`)
位于 config/ 目录，该文件包含：
- 软件路径和参数
- 参考基因组位置
- 不同工具的线程数
- 工具特定参数（STAR、RSEM、GATK 等）
- 质量控制阈值

### 必需的输入文件
- 包含样本信息的 CSV 文件
- FASTQ 格式的原始测序数据
- 参考基因组文件（FASTA、GTF/GFF）

## 使用方法

### 运行流程

使用 60 个核心运行流程：

```bash
snakemake --cores=60 -p --conda-frontend mamba --use-conda --rerun-triggers mtime
```

### 命令选项说明：
- `--cores=60`：使用最多 60 个 CPU 核心
- `-p`：执行时打印 shell 命令
- `--conda-frontend mamba`：使用 mamba 进行更快的环境管理
- `--use-conda`：自动管理 conda 环境
- `--rerun-triggers mtime`：当输入文件修改时间更改时重新运行规则

### 运行流程的特定部分

您可以通过指定特定输出文件来运行单个步骤：

```bash
# 仅运行质量控制步骤
snakemake --cores 10 01.qc/short_read_qc_r1/sample_R1_fastqc.html

# 运行比对步骤
snakemake --cores 16 02.mapping/STAR/sample/Aligned.sortedByCoord.out.bam
```

## 依赖项

RNAFlow 使用通过 conda 环境管理的几个生物信息学工具：

- **FastQC**：原始测序数据的质量控制
- **MultiQC**：质量控制结果的聚合
- **fastp**：接头修剪和质量过滤
- **STAR**：RNA-seq 数据的剪接比对
- **RSEM**：基因和转录本表达量定量
- **Samtools**：SAM/BAM 文件操作
- **Qualimap**：BAM 比对文件的质量控制
- **deepTools**：深度测序数据分析（bigWig 生成）
- **GATK**：变异检测（可选）
- **StringTie**：转录本组装（可选）

所有依赖项都以 conda 环境 YAML 文件的形式定义在 `envs/` 目录中。

## 输出

该流程在指定的数据交付目录中生成输出：

### 质量控制
- `01.qc/`：FastQC 报告、MultiQC 报告、修剪后的数据
- `01.qc/short_read_qc_r1/`：R1 读段质量报告
- `01.qc/short_read_qc_r2/`：R2 读段质量报告
- `01.qc/short_read_trim/`：修剪后的 FASTQ 文件

### 比对
- `02.mapping/`：STAR 比对结果、BAM 文件、比对统计
- `02.mapping/STAR/`：排序后的 BAM 文件和比对日志
- `02.mapping/qualimap_report/`：Qualimap 质量报告
- `02.mapping/samtools_flagstat/`：Samtools 标志统计
- `02.mapping/bamCoverage/`：BigWig 覆盖度文件

### 表达量定量
- `03.count/rsem/`：RSEM 基因和转录本表达量结果

### 变异检测（如果启用）
- `04.variant_calling/`：变异检测结果（VCF 文件）

### 转录本组装（如果启用）
- `05.assembly/`：StringTie 组装结果

## 参考基因组

该流程支持多个参考基因组版本：
- Lactuca_sativa V11 (Lsat_Salinas_v11)
- Lactuca_sativa V8 (Lsat_Salinas_v8)

参考基因组文件（FASTA、GTF、GFF）必须位于配置文件中指定的路径。

## 故障排除

### 常见问题
1. **缺少依赖项**：确保 conda/mamba 可用并正确配置
2. **磁盘空间不足**：该流程生成大型中间文件
3. **内存问题**：某些步骤（STAR 比对、RSEM）需要大量内存
4. **文件权限**：确保流程对输入/输出目录具有读/写访问权限

### 日志文件
在 `logs/` 目录中检查日志文件以获取详细的错误信息：
- `logs/01.qc/`：质量控制日志
- `logs/02.mapping/`：比对日志
- `logs/03.count/`：定量日志

## 自定义

可以通过以下方式自定义流程：
- 修改配置文件以更改参数
- 修改 `rules/` 目录中的单个规则文件
- 在主 `snakefile` 中添加或删除步骤

## 引用

如果您在研究中使用 RNAFlow，请引用此流程。

## 支持

如有问题或疑虑，请联系作者或向仓库提交问题。