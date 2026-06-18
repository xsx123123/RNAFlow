# RNAFlow：一款面向 AI 时代的工业级 RNA-seq 全流程分析流水线

> **RNA-seq 分析还在手动写脚本、拼命令、整理 Excel 表格？当样本量上百、交付周期紧张时，传统"脚本作坊"模式还能撑多久？**

对于企业级生信团队、临床基因组学实验室和大型课题组而言，RNA-seq 分析的核心痛点早已不是"能不能跑完"，而是：

- **标准化**：如何保证每次分析参数一致、结果可复现？
- **规模化**：如何从 10 个样本无缝扩展到 100+ 样本的集群调度？
- **智能化**：谁来把差异基因列表翻译成老板/客户能看懂的生物学结论？
- **交付效率**：下游报告能否自动生成，而不是深夜手动粘贴图表？

**RNAFlow** 正是为解决这些工业化痛点而设计的开源 RNA-seq 分析流水线。基于 **Snakemake** workflow 引擎，实现从 **原始数据** → **标准分析** → **自动报告** → **AI 解读** 的全闭环。支持单机一键启动、集群弹性扩展，更可通过 **自然语言** 驱动 AI 助手完成项目配置与任务管理。

---

## 核心功能

### 1️⃣ 全链路闭环：一键从 FASTQ 到交付报告

覆盖 RNA-seq 标准分析全生命周期，所有模块通过配置文件开关一键启停：

| 阶段 | 工具链 | 输出 |
|------|--------|------|
| **质控清洗** | FastQC + fastp + FastQ Screen | 质控报告、清洗后数据、污染筛查 |
| **高精度比对** | STAR (Two-Pass) | 比对 BAM、剪接位点、嵌合信号 |
| **表达定量** | RSEM | 基因/转录本 TPM、FPKM、Counts |
| **差异表达** | DESeq2 | 差异基因列表、火山图、热图 |
| **功能富集** | clusterProfiler | GO/KEGG 富集结果与可视化 |
| **高级分析** | rMATS / Arriba / GATK / StringTie | 可变剪接、融合基因、SNP/Indel、新转录本 |
| **结果交付** | BioReport + AI 解读 | 交互式 HTML 报告 + 自然语言结论 |

```yaml
# config.yaml：true / false 一键开关，灵活适配项目需求
deg: true                    # 差异表达分析
call_variant: true           # 变异检测
rmats: true                  # 可变剪接
detect_novel_transcripts: true   # 新转录本组装
report: true                 # 自动生成 HTML 报告
gene_fusion: true            # 融合基因
```

### 2️⃣ AI 原生架构：MCP Server + AI Skills + 智能报告

RNAFlow 不仅是流水线，更是**为 AI 时代设计的智能分析基础设施**。

#### 🤖 MCP Server：让 AI 助手直接操控流水线

基于 **Model Context Protocol (MCP)** 协议，RNAFlow 提供生产级 MCP Server，AI 编程助手（Claude Code、Codex 等）可直接调用：

- **基因组配置查询**：实时查询系统支持的基因组版本（Lsat_Salinas_v8/v11、ITAG4.1、GRCm39 等）及参考文件路径
- **智能配置生成**：根据用户提供的样本路径，自动生成 `config.yaml`、`samples.csv`、`contrasts.csv`
- **资源监控预警**：执行前自动检测 CPU、内存、磁盘空间，防止任务中途因资源不足失败
- **运行任务管理**：基于 SQLite 数据库记录每次运行信息，支持历史查询与冲突检测
- **异步执行**：AI 助手提交 Snakemake 任务后即返回，后台静默执行不阻塞交互

```bash
# AI 助手通过 MCP 自动完成配置后，一条命令启动分析
snakemake --cores=60 --use-conda \
    --logger rich-loguru \
    --config analysisyaml=config.yaml
```

#### 🧠 AI Skills：自然语言驱动 RNA-seq 分析

为 Claude Code 和 Codex 量身定制的 Skill 包，安装后可通过对话完成复杂操作：

```
用户："帮我用 RNAFlow 分析 /data/project/ 下的数据，基因组用 Lsat_Salinas_v11，只做 QC。"
AI："已检测到 24 个样本，自动生成配置文件... 环境检查通过，是否启动分析？"
```

Skill 包包含完整的工作流指令、路径配置和增强型启动脚本（自动检测 Conda / Snakemake 环境，带用户确认机制），将 RNA-seq 分析门槛降至"说一句话"。

#### 📊 BioReport：分析完成即报告就绪

告别手动整理图表和复制粘贴！

- **自动聚合**：分析完成后自动收集 MultiQC、DESeq2、rMATS、GATK 等所有模块结果
- **Quarto 驱动**：生成包含 Plotly 动态图表、交互式数据表格的专业 HTML 报告
- **AI 智能解读**：接入豆包、通义千问等大模型，自动将差异基因和富集通路转化为生物学洞察
- **交付即用**：响应式布局、侧边导航、分组展示，可直接用于组会汇报或客户交付

```bash
# 报告随分析流程自动触发，无需手动干预
# 最终交付目录结构
02.data_deliver/
├── 01_QC/                  # MultiQC 质控汇总
├── 03_Expression/          # 表达矩阵
├── 05_DEG/                 # 差异表达结果
├── 06_Enrichments/         # 富集分析图表
├── Analysis_Report/        # 🌟 BioReport 交互式报告入口
│   └── index.html
└── delivery_manifest.json  # 交付清单 + MD5 校验
```

### 3️⃣ 工业级稳定性：为生产环境而生

- **环境完全隔离**：全部 20+ 个工具链由 Conda/Mamba 自动管理，代码与环境绑定，实现跨服务器"无痛迁移"
- **全流程 MD5 校验**：从原始数据输入到交付目录，完整性校验贯穿始终，数据可审计、可追溯
- **断点续算**：依托 Snakemake 的任务调度，任意步骤中断后可从断点精准恢复，已完成任务绝不重复计算
- **实时监控**：集成 Loki + Grafana，结构化日志实时推送，集群任务状态可视化
- **集群弹性扩展**：完美适配 Slurm、PBS 等调度系统，百级样本队列分析稳定运行

### 4️⃣ STAR 比对参数工程化调优

针对真核转录组特征深度优化，兼顾灵敏度与精确度：

| 参数 | 配置 | 效果 |
|------|------|------|
| `--twopassMode Basic` | 开启 | 双通道比对，junction 识别精度大幅提升 |
| `--outFilterMismatchNoverLmax 0.04` | 4% 错配率 | 相比默认 30%，显著降低假阳性比对 |
| `--alignMatesGapMax 1000000` | 1Mb 间隔 | 支持长内含子跨越 |
| `--chimSegmentMin 12` | 12bp 片段 | 开启融合基因/嵌合信号检测 |
| `--quantMode TranscriptomeSAM` | 开启 | 直接输出转录组 BAM，无缝对接 RSEM |

参数经过真实项目打磨，无需反复调试，开箱即获高质量比对结果。

### 5️⃣ 容器化与 DevOps 友好

- **Conda → Docker 一键转换**：`build_image.py` 自动将环境文件编译为容器镜像，支持批量构建和推送
- **Git Submodule 共享**：容器构建器以子模块形式设计，可在 RNAFlow、ATACFlow 等多条组学流水线间复用
- **参考基因组独立构建**：索引构建与主流程解耦，一次构建、到处部署

---

## 快速上手

### 标准分析流程

```bash
# 1. 克隆仓库（含子模块）
git clone --recurse-submodules git@github.com:xsx123123/RNAFlow.git
cd RNAFlow

# 2. 安装依赖
conda install -c conda-forge -c bioconda snakemake mamba
pip install snakemake_logger_plugin_rich_loguru==0.1.4

# 3. 准备配置文件（或让 AI 助手通过 MCP 自动生成）
# config.yaml / samples.csv / contrasts.csv

# 4. 试运行检查
snakemake -n --config analysisyaml=/path/to/config.yaml

# 5. 启动全流程分析
snakemake --cores=60 \
    --use-conda --conda-frontend=mamba \
    --rerun-triggers mtime \
    --logger rich-loguru \
    --config analysisyaml=/path/to/config.yaml
```

### AI Skills 安装（可选，推荐）

```bash
cd skills

# 自动检测并安装到 Claude Code / Codex
./install_skills.sh

# 安装后可通过自然语言交互：
# "帮我配置 RNAFlow 并运行 QC 分析"
# "用 Lettuce v11 基因组做一次完整的差异表达分析"
```

### MCP Server 启动（可选）

```bash
cd mcp
uv sync          # 使用 uv 管理依赖
./start.sh test  # 测试运行
```

---

## 适用场景

| 用户群体 | 典型应用场景 |
|----------|--------------|
| **企业级 CRO/生信团队** | 标准化交付、批量分析、自动化报告输出 |
| **临床基因组学实验室** | 肿瘤转录组、药物响应队列的稳定分析 |
| **高校课题组** | 从原始数据到毕业论文图表的一站式解决方案 |
| **生物信息平台运维** | 基于 Snakemake + 集群的大规模并行任务调度 |
| **AI 辅助开发用户** | 通过自然语言驱动分析，零门槛完成 RNA-seq 项目 |

---

## 项目信息

> **GitHub**：https://github.com/xsx123123/RNAFlow  
> **License**：MIT（完全开源，可自由商用）

RNAFlow 持续迭代中，当前版本 `v0.1.9+`，MCP Server `v0.2.0`。欢迎 Star、Fork 或提交 Issue 参与共建。

如果你正在寻找一款**无需手动拼脚本、支持 AI 交互、可即刻投入生产环境**的 RNA-seq 分析流水线，RNAFlow 值得一试。

---

**#生物信息学 #RNAseq #Snakemake #开源工具 #NGS #自动化流水线 #工业级 #MCP #AI助手 #智能报告**

> 你的实验室目前如何管理批量 RNA-seq 分析？有没有试过让 AI 助手直接帮你配置生信流水线？欢迎在评论区交流。
