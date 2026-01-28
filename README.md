# RNAFlow - RNA-seq Analysis Pipeline

RNAFlow 是一个基于 Snakemake 的全自动化 RNA-seq 分析流程。它实现了从**原始测序数据 (Raw Data)** 到**标准化生物信息报告 (Interactive Report)**，再到 **AI 智能结果解读** 的端到端闭环分析。
> **声明**：RNAFlow 现阶段仅在课题组内部使用，尚未正式对外开源。

## 📖 目录
- [核心特性](#-核心特性)
- [分析工作流](#-分析工作流)
- [系统架构](#-系统架构)
- [BioReport 报告系统](#-bioreport-报告系统)
- [目录结构](#-目录结构)
- [安装指南](#-安装指南)
- [配置指南](#-配置指南)
- [使用说明](#-使用说明)
- [开发计划](#-开发计划)
- [版本历史](#-版本历史)

## ✨ 核心特性

- **模块化设计 (Modular)**：分析代码、环境配置、参考基因组路径完全分离，通过 `config.yaml` 灵活调度。
- **智能数据识别 (Smart Recognition)**：自动识别层级目录 (`raw/Sample/L1_R1.fq`) 或平铺目录 (`raw/Sample_R1.fq`)。
- **AI 智能解读 (AI-Powered)**：集成生产级 AI 引擎（支持豆包、通义千问），自动对差异基因和富集结果进行生物学意义解读。
- **交互式报告 (Interactive)**：基于 Quarto 驱动，生成包含动态图表（Plotly）、过滤表格的 HTML 报告。
- **环境隔离 (Reproducible)**：通过 Conda/Mamba 自动管理所有工具链，确保分析的可复现性。
- **一键部署 (Cloud Ready)**：支持将生成的报告一键部署至 Nginx 服务器。
- **可扩展架构 (Extensible)**：模块化设计便于添加新的分析功能，支持定制化需求。
- **质量控制 (Quality Assurance)**：内置多层次质控流程，确保分析结果可靠性。

## 🛠 分析工作流

RNAFlow 涵盖了标准的转录组分析全过程：

1.  **QC & Cleaning**: FastQC 质控 -> fastp 过滤与去接头。
2.  **Contamination Check**: 检测物种污染（FastQ Screen）。
3.  **Mapping**: STAR 高性能比对 -> Qualimap/Samtools 统计。
4.  **Quantification**: RSEM 基因/转录本水平表达定量。
5.  **Advanced Analysis**:
    *   **DEG**: 基于 DESeq2 的差异表达分析。
    *   **Enrichment**: GO/KEGG 功能富集分析。
    *   **Splicing**: rMATS 可变剪接检测。
    *   **Fusion**: Gene Fusion 融合基因鉴定。
    *   **Variants**: GATK 单核苷酸变异检测。
    *   **Assembly**: StringTie 脚本组装。
6.  **Reporting & Delivery**: 自动汇总 MultiQC，生成 BioReport 交互式报告，并整理交付目录。

## 🏗️ 系统架构 (System Architecture)

```mermaid
graph TD
    %% =======================
    %% 1. Configuration Layer
    %% =======================
    subgraph Config_Layer [Configuration Layer]
        direction TB
        Conf_Main[config.yaml]
        Conf_Ref[reference.yaml]
        Conf_Env[envs/*.yaml]
        Input_Data[Raw FASTQ / Flat or Nested]
    end

    %% =======================
    %% 2. Core Workflow Layer (Snakemake)
    %% =======================
    subgraph Workflow_Layer [Core Workflow - Snakemake]
        direction TB
        
        %% Pre-processing
        node_QC[QC & Cleaning]
        node_Map[STAR Alignment]
        
        %% Quantification
        node_Quant[RSEM Quantification]
        
        %% Advanced Analysis Modules
        subgraph Modules [Analysis Modules]
            direction LR
            Mod_DEG[DEG & Enrichment]
            Mod_Var[GATK Variants]
            Mod_Spl[rMATS Splicing]
            Mod_Fus[Fusion Detection]
            Mod_Asm[StringTie Assembly]
        end
        
        %% Data Aggregation
        node_Agg[Merge & Stats]
    end

    %% =======================
    %% 3. Reporting Layer (BioReport)
    %% =======================
    subgraph Report_Layer [BioReport System]
        direction TB
        
        %% Architecture Pattern
        Action_Init[Initialize Workspace]
        Action_Inject[Inject Data & Config]
        Action_Render[Quarto Render]
        
        %% Template System
        Template[Template: RNA_Project]
        
        %% AI Sub-system
        subgraph AI_Engine [AI Intelligence Engine]
            direction TB
            AI_Router{Model Router}
            Model_Doubao[Volcengine / Doubao]
            Model_Qwen[Aliyun / Qwen]
            Token_Ctrl[Token Manager & Cost Calc]
        end
        
        Output_Site[Static HTML Website]
    end

    %% =======================
    %% Relationships
    %% =======================
    
    %% Config -> Workflow
    Input_Data --> node_QC
    Conf_Main --> Workflow_Layer
    Conf_Ref --> node_Map
    
    %% Workflow Internal
    node_QC --> node_Map
    node_Map --> node_Quant
    node_Map --> Modules
    node_Quant --> Mod_DEG
    Modules --> node_Agg
    
    %% Workflow -> Report
    node_Agg -- "JSON / CSV / Plots" --> Action_Inject
    Mod_DEG -- "Diff Genes Table" --> AI_Router
    Mod_Enrich -- "Pathway Terms" --> AI_Router
    
    %% Report Internal Logic
    Template --> Action_Init
    Action_Init --> Action_Inject
    Action_Inject --> Action_Render
    
    %% AI Integration
    AI_Router --> Token_Ctrl
    Token_Ctrl --> Model_Doubao
    Token_Ctrl --> Model_Qwen
    Model_Doubao -- "Natural Language Interpretation" --> Action_Inject
    Model_Qwen -- "Fallback Interpretation" --> Action_Inject
    
    Action_Render --> Output_Site

    %% =======================
    %% Styling
    %% =======================
    classDef config fill:#e1f5fe,stroke:#01579b,stroke-width:2px;
    classDef workflow fill:#f3e5f5,stroke:#4a148c,stroke-width:2px;
    classDef report fill:#e0f2f1,stroke:#004d40,stroke-width:2px;
    classDef ai fill:#fff3e0,stroke:#e65100,stroke-width:2px,stroke-dasharray: 5 5;

    class Conf_Main,Conf_Ref,Conf_Env,Input_Data config;
    class node_QC,node_Map,node_Quant,Mod_DEG,Mod_Var,Mod_Spl,Mod_Fus,Mod_Asm,node_Agg workflow;
    class Action_Init,Action_Inject,Action_Render,Template,Output_Site report;
    class AI_Router,Model_Doubao,Model_Qwen,Token_Ctrl,AI_Engine ai;
```

### 🔄 核心数据流说明
1.  **输入解析**: `Snakemake` 自动读取 `config.yaml` 并识别输入数据结构。
2.  **核心计算**: 通过 STAR + RSEM 获得表达矩阵，并行触发高级分析模块。
3.  **结果汇聚**: `15.deliver.smk` 将关键结果汇总到交付目录。
4.  **智能报告**: `BioReport` 系统提取分析结果并调用 AI 引擎进行生物学解读，最终生成 `Quarto HTML` 报告。

## 📊 BioReport 报告系统

位于 `report/` 目录下的 **BioReport** 是本流程的核心亮点：

> [!WARNING]
> **测试说明**：AI 智能解读模块目前仍处于内部测试阶段，尚未整合至最终生成的标准化报告中。

*   **架构理念**：采用 "Copy-Inject-Render" 模式，将分析结果动态注入 Quarto 模板。
*   **AI 引擎**：
    *   **多云架构**：支持火山引擎 (Doubao) 和阿里云 (Qwen)。
    *   **高可用**：支持 API 自动故障切换 (Fallback)。
    *   **成本控制**：内置 Token 统计与截断策略。
*   **交互体验**：报告包含响应式布局、侧边导航以及支持搜索的交互式数据表。

## 📂 项目组织建议 (Project Organization)

为了实现代码与数据的解耦，推荐采用以下三级目录结构来组织分析项目：

### 1. 顶层项目目录
这是项目的根，建议将原始数据、分析过程和最终交付分开：
```text
Project_Root/
├── 00.raw_data/             # 原始下机数据 (只读)
├── 01.workflow/             # 分析工作空间 (运行 Snakemake 的地方)
└── 02.data_deliver/         # 最终结果交付目录 (由流程自动整理生成)
```

### 2. 分析工作目录 (01.workflow)
该目录存放配置文件，并作为 Snakemake 运行的当前工作目录：
```text
01.workflow/
├── config.yaml              # 项目配置文件 (指定 reference_path 等)
├── samples.csv              # 样本信息表
├── contrasts.csv            # 差异分析对照表
├── 01.qc/                   # 质控中间结果
├── 02.mapping/              # 比对中间产物 (BAM等)
├── 03.count/                # 定量中间结果
├── 07.AS/                   # 可变剪接分析中间文件
├── logs/                    # 详细运行日志
└── benchmarks/              # 各步骤资源消耗统计
```

### 3. 结果交付目录 (02.data_deliver)
分析完成后，流程会自动将核心结果汇总至此，供最终交付：
```text
02.data_deliver/
├── 00_Raw_Data/             # 原始数据汇总
├── 01_QC/                   # 质控报告 (MultiQC等)
├── 02_Mapping/              # 比对统计报告
├── 03_Expression/           # 表达定量矩阵
├── 05_DEG/                  # 差异表达分析结果
├── 06_Enrichments/          # 功能富集分析图表
├── 07_AS/                   # 可变剪接分析结果
├── Summary/                 # 项目总体汇总统计
├── Analysis_Report/         # 核心产物：最终交互式网页报告入口
├── report_data/             # 网页报告支撑数据
└── delivery_manifest.json   # 交付清单与 MD5 校验
```

## 📂 仓库目录结构 (Codebase)

```text
RNAFlow/
├── snakefile                # Snakemake 主入口文件
├── config/                  # 配置文件目录 (运行参数、参考基因组)
├── rules/                   # 模块化规则定义 (00-15)
│   ├── 04.short_read_qc.smk # 质控
│   ├── 07.mapping.smk      # 比对
│   ├── 11.DEG_Enrichments.smk # 差异分析与富集
│   ├── 15.deliver.smk      # 结果整理
│   └── ...
├── envs/                    # Conda 环境定义文件 (YAML)
├── report/                  # BioReport 报告系统源码
│   ├── bioreport/           # 报告生成核心逻辑
│   ├── templates/           # Quarto 报告模板
│   └── ai/                  # AI 解读引擎
├── src/                     # 辅助脚本库 (Python/R)
│   ├── DEG/                 # 差异分析相关脚本
│   └── Enrichments/         # 富集分析封装
└── scripts/                 # 实用工具脚本
```

## 🚀 安装指南

1.  **克隆仓库**：
    > [!IMPORTANT] 
    > **声明**：RNAFlow 现阶段仅在课题组内部使用，尚未正式对外开源。
    ```bash
    git clone --recurse-submodules git@github.com:xsx123123/RNAFlow.git
    cd RNAFlow
    ```

2.  **环境准备**：
    安装 Snakemake 和 Mamba：
    ```bash
    conda install -c conda-forge -c bioconda snakemake mamba
    ```

3. The pipeline uses conda environments for dependencies, which will be automatically created during execution.

4. **(Recommended) Install Enhanced Logger Plugin**:
   To enable beautiful console output and structured logging (as seen in the Usage examples), install the included `rich-loguru` plugin:
   ```bash
   pip install -e src/src/logger_plugin/
   ```

## ⚙️ 配置指南 (Configuration)

推荐使用外部 YAML 配置文件来管理项目参数，以实现代码与配置的解耦。

### 1. 配置文件示例 (config.yaml)
```yaml
project_name: 'PRJNA1224991'   # 项目 ID
Genome_Version: "Lsat_Salinas_v11" # 基因组版本 (支持: Lsat_Salinas_v8, Lsat_Salinas_v11, ITAG4.1, GRCm39 等)
species: 'Lsat Salinas'        # 分析物种
client: 'Internal_Test'        # 客户 ID

# 原始数据路径 (支持列表，可包含多个目录)
raw_data_path:
  - /path/to/raw_data

# 关键信息表
sample_csv: /path/to/samples.csv    # 样本信息表 (格式见下文)
paired_csv: /path/to/contrasts.csv  # 样本配对/对照信息表 (格式见下文)

# 路径设置
workflow: /path/to/analysis_dir     # 数据分析过程目录 (工作空间)
data_deliver: /path/to/deliver_dir  # 最终结果交付目录

# 运行参数
execution_mode: local               # 运行模式: local 或 cluster
# queue_id: fat_x86                 # 集群队列名称 (仅 cluster 模式有效),如果不在集群运行请移除该配置

# 测序文库设置
Library_Types: fr-firststrand       # 链特异性类型 (fr-unstranded, fr-firststrand, fr-secondstrand)
                                    # 流程会自动检测并对比设置，若不符将发出警告

# 高级分析开关
call_variant: true                  # 是否进行变异检测 (GATK)
noval_Transcripts: true             # 是否进行新转录本组装 (StringTie)
rmats: true                         # 是否进行可变剪接分析 (rMATS)

# 可选配置
only_qc: true                       # 运行模式: qc_only (仅质控)
```

### 2. 样本信息表 (sample_csv)
CSV 格式，包含 `sample` (原始文件名关键字), `sample_name` (重命名后的名称), `group` (分组) 三列：
```csv
sample,sample_name,group
L1MKL2302060-CKX2_23_15_1,CKX2_1,CKX2
L1MKL2302061-CKX2_23_15_2,CKX2_2,CKX2
L1MKL2302062-CKX2_23_15_3,CKX2_3,CKX2
L1MKL2302063-Wo408_1,Wo408_1,Wo408
L1MKL2302064-Wo408_2,Wo408_2,Wo408
L1MKL2302065-Wo408_3,Wo408_3,Wo408
```

### 3. 样本配对信息表 (paired_csv)
用于差异分析 (DEG) 的对照设置，包含 `Control` 和 `Treat` 两列：
```csv
Control,Treat
Wo408,CKX2
```

### 4. 流程核心配置文件 (Internal Configs)
除了外部指定的项目配置文件，`config/` 目录下包含了流程运行的默认设置：
- **`config/config.yaml`**: 流程的基础全局配置。
- **`config/reference.yaml`**: 核心参考基因组配置文件。定义了各版本（V8, V11, GRCm39等）的 FASTA、GTF 及索引路径。
  - **流程迁移**：若在不同环境运行，需修改 `reference_path`（例如：`reference_path: /data/jzhang/reference/RNAFlow_reference`）。
  - **新增基因组**：如需支持新物种，请在此文件中按格式添加配置。
  - **自动检查**：流程启动后会自动对参考文件完整性进行 Check，确保分析可靠。
  - **FastQ Screen 数据库**：新增配置 `fastq_screen_db_path`，指向污染源数据库根目录（需包含 hg38, GRCm39, fastq_screen_database 等子目录）。迁移时只需拷贝该目录并在配置中更新路径即可，无需修改代码。
- **`config/run_parameter.yaml`**: 工具运行参数设置，包括各软件的具体命令行参数（如 STAR 的比对阈值、RSEM 的模型参数等）。
- **`config/cluster_config.yaml`**: 集群资源定义，规定了不同任务（Low, Medium, High resource）对应的线程和内存分配。

### 5. 集群配置 (可选)
如果 `execution_mode` 设置为 `cluster`，请确保已安装相关集群插件（如 `snakemake-executor-plugin-slurm`）。更细致的资源分配（线程、内存）可编辑 `config/cluster_config.yaml`。

## 💻 使用说明

### 标准分析流程
建议使用外部配置文件以保持项目整洁：

```bash
# 1. 预运行检查 (Dry Run)
snakemake -n --config analysisyaml=path/to/your_config.yaml

# 2. 执行分析 (使用 60 核心，启用 Conda)
snakemake --cores 60 --use-conda --conda-frontend mamba \
          --logger rich-loguru \
          --config analysisyaml=path/to/your_config.yaml
```

### 生成 AI 报告 (BioReport)

目前推荐使用封装好的 Docker 镜像来生成报告，以避免本地环境配置问题。

#### 使用 Docker 生成 (推荐)
> [!NOTE]
> **注意**：Docker 镜像目前仅供内部使用。如需获取镜像或了解更多信息，请联系开发者。

```bash
docker run -it --rm \
  --user $(id -u):$(id -g) \
  -v /path/to/analysis_data:/data:rw \
  -v /path/to/project_summary.json:/app/project_summary.json:rw \
  -v /path/to/output_report:/workspace:rw \
  bioreportrna:v0.0.5
```
**参数说明：**
- `-v ...:/data`: 挂载上游分析生成的数据目录。
- `-v ...:/app/project_summary.json`: 挂载项目汇总配置文件。
- `-v ...:/workspace`: 挂载报告输出目录。

#### 命令行方式生成
若已在本地配置好环境，也可进入 `report` 目录直接运行：
```bash
python report/bioreport/main.py --input results_dir --output report_dir --ai
```

## 📅 开发计划 (Roadmap)

### 云原生参考基因组管理 (Cloud-Native Reference Management)
采用 **BYOC (Bring Your Own Cloud)** 策略，赋能用户构建属于自己的生物数据中心，实现"无状态迁移" (Stateless Portability)。

1.  **Reference Factory (构建工厂)**:
    *   提供独立的 Snakemake 构建流程 (`build_reference.smk`)，用户可一键将 FASTA/GTF 转换为 STAR/RSEM 索引。
    *   **自动云端同步**：支持将构建产物自动推送到**用户配置的**对象存储桶（AWS S3 / Aliyun OSS / 自建 MinIO）。
    *   **配置自动化**：构建完成后自动生成包含 S3 路径的 `reference.yaml`，实现全组服务器共享一套索引。

2.  **S3 架构原生支持**:
    *   流程内置对 S3 协议的支持，利用 Snakemake 的 Remote Provider 机制实现 **自动缓存 (Auto-Caching)**。
    *   **成本可控**：用户完全掌控自己的存储与流量，支持内网部署 MinIO 以零成本实现高速分发。

### 高级差异分析模块 (Advanced Experimental Design)
为了支持更复杂的生物学实验设计（如时间序列分析、双因素交互作用），计划在下一版本中对 DEG 模块进行重构，不再局限于简单的两两比较 (Wald test)。

**拟定设计方案：**

1.  **配置增强 (`config.yaml`)**:
    引入 `statistical_model` 字段，支持自定义设计公式：
    ```yaml
    # 高级模式示例：双因素交互 (Genotype x Treatment)
    statistical_model:
      design_formula: "~ Genotype + Condition + Genotype:Condition"
      test_type: "LRT"  # Likelihood Ratio Test (用于多因素)
      reduced_formula: "~ Genotype + Condition" # LRT 需要的简化公式
    ```

2.  **对比矩阵升级**:
    现有的 `contrasts.csv` 将升级为更灵活的 `comparisons.csv`，允许用户直接指定 DESeq2 的提取参数：
    ```csv
    comparison_name,contrast_argument
    WT_Drought_vs_Water,c("Condition", "Drought", "Water")
    Genotype_Interaction,name="GenotypeMut.ConditionDrought"
    ```

### AI 引擎增强 (AI Engine Enhancement)
进一步提升 AI 在生物信息学分析中的应用能力：

1.  **多模态分析**：结合基因表达、变异、剪接等多种数据类型，提供综合性的生物学解释。
2.  **实时学习**：引入在线学习机制，使 AI 模型能够根据最新文献不断更新知识库。
3.  **个性化解读**：根据用户的专业背景和研究兴趣，定制化生成分析报告内容。

## 📈 版本历史

### RNAFlow_v0.1.7
- **Feature**: 增加`estimate_library_complexity`rule，用于评估文库复杂度。
- **Feature**: 增加`rmats_summary`功能，用于合并配对和单独样本的AS分析结果。
- **Improvement**: 使用`temp()`将分析过程`bam`文件标记为分析完成后移除，同时添加`bam2cram`rule,减少分析流程存储开销。

### RNAFlow_v0.1.6
- **Feature**: 模块化重构 `DataDeliver` 函数，提高代码可维护性。
- **Feature**: 增强配置验证机制，提升错误提示准确性。
- **Improvement**: 优化 AI 报告生成流程，支持更多输出格式。
- **Feature**: 深度集成 **BioReport v2** 报告系统。
- **Feature**: 增加规则 `14.Merge_qc` 和 `15.deliver`，实现全流程结果自动化整理。
- **Feature**: 新增 **Execution Mode** 切换功能 (`run_mode: qc_only`)，支持快速执行质控与比对，便于大规模数据初筛。
- **Improvement**: 更新 `11.DEG_Enrichments`，整合富集分析逻辑。
- **Optimization**: 完善 AI 解读引擎的流控与容错机制。

### RNAFlow_v0.1.5
- **Feature**: 实现智能输入数据识别，支持多种目录结构。
- **Improvement**: 集成 `rich-loguru` 提升终端输出体验。

---
**Author**: JZHANG | **Version**: RNAFlow_v0.1.6
