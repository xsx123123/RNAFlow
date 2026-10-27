# RNAFlow → BioReport JSON 交付规范

规范版本：`2.1.0`。BioReport 同时接受既有 `2.0.0` 交付和新增元数据的 `2.1.0` 交付；2.1.0 在旧字段上只增不改。

推荐交付方式：**JSON 保存项目元信息、软件版本、结果路径和状态；CSV/TSV 保存完整分析数据。GO/KEGG 不写入内嵌 `terms`。**

配套文件：

- [完整 JSON 模板](../configs/report.rnaflow.example.json)：展示 2.1.0 的项目、平台和文件索引字段以及一个比较组的 GO/KEGG 上下调结构；真实交付必须替换平台占位值并展开全部比较组。
- [机器校验 Schema](../configs/rnaflow.delivery.schema.json)：独立的 Draft 2020-12 Schema，同时校验 2.0.0 和 2.1.0，可直接复制到 RNAFlow 仓库，无远程依赖。
- [本次真实项目的精简配置](../examples/X101SC26098749-Z01-J001_UPDATE/report.paths.json)：保留全部 6 个比较组、24 个结果状态，不含条目数组。

## 1. 目录与路径

建议目录如下；JSON 文件名可以继续叫 `project_summary.json`：

```text
report_data/
├── project_summary.json
└── data/
    ├── index/
    │   ├── sample.csv
    │   ├── contrasts.csv
    │   ├── merge_rsem_tpm.tsv
    │   ├── multiqc_qc_general_stats.txt
    │   └── multiqc_mapping_general_stats.txt
    ├── fastp_trim_report/…
    ├── fastq_screen_report/…
    ├── QualiMap/multiqc_data/…
    └── res/
        ├── DEG/
        └── Enrichments/
```

顶层显式填写 `"path_base": "."`。`input_files`、2.1.0 的 `files[].path` 和富集记录中的 `table/full_table`，都以 **JSON 所在目录** 为基准解析。

```json
{
  "schema_version": "2.1.0",
  "path_base": ".",
  "input_files": {
    "data_dir": "data",
    "sample_file": "data/index/sample.csv"
  }
}
```

这个片段只说明路径规则，不是完整可运行配置。`data_dir` 是数据目录记录，不会再拼到这些路径前面。使用 `/` 分隔目录；上游交付只使用包内相对路径，不写原机器绝对路径、URL、反斜杠或 `..`。移动整个交付目录后仍应可读取。

未声明 `path_base` 的旧配置仍按原来的 `data_dir` 相对路径规则解析。新交付统一显式声明 `path_base: "."`，避免混用两种规则。

## 2. 顶层字段

| 字段 | 类型 | 要求与用途 |
| --- | --- | --- |
| `schema_version` | string | 必填，旧交付为 `2.0.0`，新交付固定 `2.1.0`；表示 RNAFlow 交付契约版本，与软件版本、Workspace API 版本无关 |
| `path_base` | string | 必填，固定 `.` |
| `project` | object | 必填，项目元信息；2.1.0 增加必填 `user_id` |
| `input_files` | object | 必填，输入文件和目录路径 |
| `platform` | object | 2.1.0 必填，报告与任务平台元信息 |
| `files` | array | 2.1.0 必填，结果文件语义索引；与 `input_files`、`enrichment` 并存 |
| `software_versions` | array | 必填，至少一条真实软件版本记录 |
| `enrichment` | object | 必填，包含 `go` 和 `kegg`，未运行的库设置 `enabled: false` |
| `stats` | object | 可选，`total_samples` 和 `group_count` 为非负整数 |
| `analysis` | object | 可选，报告统计与展示参数 |
| `report` | object | 可选，输出格式、模块、标题等展示设置 |
| `ai` | object | 可选，推荐先设置 `enabled: false` 验证报告生成 |

上游应输出 `project`，不要继续输出 `project_meta`。当前运行时仍兼容旧 `project_meta`；上游严格 Schema 只接受本规范的新结构。2.1.0 不移除或改写 `stats`、`input_files`、`enrichment` 等已有字段；新增的 `files` 仅供平台索引和 AI 提供语义上下文。新规范中不放 `terms`、大矩阵或富集条目，旧版内嵌条目仅保留运行时兼容。

### 项目信息

```json
{
  "project": {
    "project_id": "X101SC26098749-Z01-J001",
    "user_id": "由任务上下文写入的平台用户 ID",
    "client": "jzhang",
    "species": "Solanum lycopersicum",
    "genome_version": "ITAG4.1",
    "pipeline_version": "0.2.0",
    "analysis_date": "2026-10-20"
  }
}
```

2.1.0 中上述字段全部必填且非空。`user_id` 必须由实际发起任务的上下文写入，用作报告归属与权限绑定键；不得由 BioReport 渲染参数手填，也不得使用示例占位值。`project_id` 用于项目标识、日志、溯源与报告命名；不是 `project_name`。`analysis_date` 是上游分析日期；`report_date` 可选，用于显式指定报告日期，二者不是同一含义。

### 平台元信息

```json
{
  "platform": {
    "report_id": "X101SC26098749-Z01-J001_20261024-153012",
    "task_id": "平台任务 ID",
    "flow_type": "rna_seq",
    "flow_version": "0.2.0",
    "title": "RNA-seq 差异表达分析报告 2026-10-24 #061",
    "status": "completed",
    "generated_at": "2026-10-24T15:30:12+08:00",
    "expire_at": null,
    "html_entry": "report.html"
  }
}
```

2.1.0 中 `platform` 的所有字段必填。`report_id` 必须符合 `<project_id>_<yyyymmdd-hhmmss>`，并与平台登记的报告目录名一致；`generated_at` 必须是带时区的 ISO 8601 时间；`expire_at` 是带时区的 ISO 8601 时间或 `null`；`html_entry` 是报告目录内的相对 HTML 入口路径。`task_id`、`flow_type`、`flow_version`、`title` 和 `status` 应反映真实任务，不得从模板值直接交付。

### 结果文件语义索引

```json
{
  "files": [
    {
      "path": "data/index/merge_rsem_tpm.tsv",
      "role": "expression_matrix_tpm",
      "description": "RSEM 合并后的 TPM 表达矩阵，行基因列样本。",
      "format": "tsv"
    },
    {
      "path": "data/res/DEG/Salt_A_vs_WTSalt_DEG.csv",
      "role": "deg_table",
      "description": "Salt_A vs WTSalt 差异分析结果表，包含 log2FoldChange 和原始 pvalue。",
      "format": "csv",
      "contrast": "Salt_A_vs_WTSalt"
    },
    {
      "path": "data/res/Enrichments/Salt_A_vs_WTSalt_GO_UP.csv",
      "role": "enrichment_table",
      "description": "Salt_A vs WTSalt GO 上调富集结果，cutoff=0.05。",
      "format": "csv",
      "contrast": "Salt_A_vs_WTSalt",
      "direction": "UP",
      "ontology": "GO"
    }
  ]
}
```

每条索引都必须有 `path`、`role`、`description` 和 `format`。`path` 使用相对报告目录的 `/` 分隔路径；禁止绝对路径、URL、反斜杠、`.`/`..` 路径段以及经符号链接逃出报告目录。`description` 使用一句话中文，说明文件内容和关键统计口径。2.1.0 首批 `role` 枚举为 `expression_matrix_tpm`、`expression_matrix_count`、`sample_metadata`、`contrast_definition`、`deg_table`、`enrichment_table`、`qc_stats`、`qc_report`、`figure`、`log`、`other`；新增角色须先扩展 Schema 词表。`deg_table` 必须附 `contrast`；`enrichment_table` 必须附 `contrast`、`direction`（`UP`/`DOWN`）和 `ontology`（`GO`/`KEGG`）。

`files` 与既有 `input_files` / `enrichment` 同时保留：旧字段继续驱动报告渲染，新索引用于平台检索与 AI 上下文。所有 `input_files` 中的文件路径、富集 `table/full_table` 路径，以及每个差异结果 CSV 都必须在索引中有对应条目；每条索引路径都必须存在且指向文件。Schema 校验字段和路径形式，`bioreport validate` 额外校验索引文件存在、目录边界与上述覆盖关系。

### 数据路径

完整 RNA 报告的上游交付需声明：

| 字段 | 文件/目录 | 数据要求 |
| --- | --- | --- |
| `data_dir` | 目录 | 推荐 `data` |
| `qc_file` | TSV 文件 | QC 汇总，包含 `Sample` 及实际 MultiQC 指标列 |
| `mapping_file` | TSV 文件 | 比对汇总，包含 `Sample` 及实际 MultiQC 指标列 |
| `tpm_file` | TSV 文件 | 第一列为基因 ID，其余列为样本 TPM；样本列与样本表匹配 |
| `sample_file` | CSV 文件 | 推荐列：`sample,sample_name,group`；样本标识唯一 |
| `contrasts_file` | CSV 文件 | 必需列：`Control,Treat`；比较名为 `Treat_vs_Control`，引用已存在分组 |
| `deg_dir` | 目录 | 各比较组的 `比较名_DEG.csv`，至少提供 `log2FoldChange,pvalue`；推荐保留 `padj,ENSEMBL,Symbol` |
| `fastp_stats_file` | TSV 文件 | fastp 汇总统计 |
| `fastp_report_dir` | 目录 | 包含或单层包装目录中包含 MultiQC 的 `multiqc_data.json` |
| `fastq_screen_r1_dir` | 目录 | R1 MultiQC 数据目录 |
| `fastq_screen_r2_dir` | 目录 | R2 MultiQC 数据目录 |
| `qualimap_dir` | 目录 | QualiMap/STAR 等 MultiQC 数据目录 |

使用显式 `enrichment.go/kegg` 后，不再要求额外配置 `input_files.enrichment_dir`；版本内嵌后，不再要求 `input_files.software_versions_file`。单独调用部分报告模块可以使用较少输入；这里的严格交付 Schema 面向完整 RNA 项目。

未配置显式 `enrichment` 块时，报告在 `enrichment_dir` 下按文件名自动发现：先匹配旧命名 `{比较名}_{UP|DOWN}.csv`；找不到再按数据库拆分命名 `{比较名}_{GO|KEGG}_{UP|DOWN}*.csv`（如 `Salt_A_vs_WTSalt_GO_UP.csv`、`Salt_A_vs_WTSalt_KEGG_UP_enrichments.csv`）发现，并按数据库分别展示；两者都无才标记为未提供。

## 3. 软件版本直接放在 JSON

```json
{
  "software_versions": [
    {"Software": "fastp", "Version": "1.0.1"},
    {"Software": "Samtools", "Version": "1.22.1"},
    {"Software": "FastQ Screen", "Version": "0.16.0"},
    {"Software": "MultiQC", "Version": "1.31"}
  ]
}
```

这些版本来自本次交付中能核验的记录；上游应汇总本次实际运行的软件，还包括可获得的 STAR、RSEM、DESeq2、clusterProfiler 等记录。不要把示例值当成真实版本，也不要补造未记录的版本。

- `Software`、`Version` 大小写与拼写固定，值均为非空字符串。版本数字也必须加引号。
- 软件名不能重复（不区分大小写）；多环境的不同版本应附清晰的环境标识。
- `Link` 可选，用于工具官网；建议仅填写 HTTP/HTTPS 链接。
- 版本表支持没有 `Link` 的记录。未提供的软件版本显示为未提供，不自动填入示例版本。
- 旧配置可继续使用外部 JSON/YAML 版本文件；同时存在两种来源时，报告读取内嵌 `software_versions`。新上游交付只用内嵌方式即可。

## 4. GO / KEGG 只引用结果文件

以下为推荐的精简结构，比较组名必须与 `contrasts.csv` 的 `Treat_vs_Control` 一致：

```json
{
  "enrichment": {
    "go": {
      "enabled": true,
      "method": "clusterProfiler::enricher",
      "parameters": {"cutoff": 0.05, "padj_th": 0.05, "lfc_th": 1},
      "contrasts": {
        "Salt_A_vs_WTSalt": {
          "UP": {
            "status": "available",
            "table": "data/res/Enrichments/Salt_A_vs_WTSalt_GO_UP.csv"
          },
          "DOWN": {
            "status": "available",
            "table": "data/res/Enrichments/Salt_A_vs_WTSalt_GO_DOWN.csv"
          }
        }
      }
    },
    "kegg": {
      "enabled": true,
      "method": "clusterProfiler::enrichKEGG",
      "parameters": {"cutoff": 0.05, "organism": "sly"},
      "contrasts": {
        "Salt_A_vs_WTSalt": {
          "UP": {
            "status": "available",
            "table": "data/res/Enrichments/Salt_A_vs_WTSalt_KEGG_UP_enrichments.csv",
            "full_table": "data/res/Enrichments/Salt_A_vs_WTSalt_KEGG_UP_enrichments_full.csv"
          },
          "DOWN": {
            "status": "available",
            "table": "data/res/Enrichments/Salt_A_vs_WTSalt_KEGG_DOWN_enrichments.csv"
          }
        }
      }
    }
  }
}
```

无需输出 `terms`，也无需把 GO 与 KEGG 合并 CSV。文件名不强制改成某种后缀，BioReport 按 `table` 指定的准确路径读取。HTML 分 GO/KEGG 展示，各自保留比较组和 UP/DOWN；PDF、摘要与 AI 结果也使用同一入口。

每个启用的数据库必须列出所有交付比较组，每组给出 `UP`、`DOWN` 两个状态。

| 字段 | 要求 |
| --- | --- |
| `enabled` | boolean；是否执行该数据库的分析 |
| `method` | 启用时必填，记录真实方法 |
| `parameters.cutoff` | 启用时必填，`0 < cutoff <= 1`，结果显著性阈值 |
| `parameters` 其他字段 | 可选，保留真实的 organism、基因筛选阈值等少量参数；不放大映射表 |
| `contrasts` | 启用时必填，键为比较名 |
| `status` | 每方向必填，取值见下表 |
| `table` | `available` 时必填，指向用于报告的 CSV；其他状态可省略或为 null |
| `full_table` | 可选，未筛选完整表的 CSV 路径；不自动作为绘图输入 |
| `term_count` | 可选；available 时为 table 的真实数据行数，no_results 时若填写必须为 0 |
| `messages` | 可选，字符串数组，说明空结果、未执行或失败原因 |

### 状态与空结果

| status | 含义 | 报告行为 |
| --- | --- | --- |
| `available` | 已提供可用结果表 | 从 table 读取、筛选、绘图及展示表格 |
| `no_results` | 已执行，按上游阈值无显著结果 | 显示无显著结果，不把占位行当真实条目 |
| `unavailable` | 本方向没有交付结果 | 显示未提供结果 |
| `disabled` | 本比较方向未启用 | 显示未启用分析 |
| `failed` | 上游执行失败 | 显示失败状态与说明 |

```json
{
  "status": "no_results",
  "term_count": 0,
  "full_table": "data/res/Enrichments/Salt_B_vs_WTSalt_KEGG_UP_enrichments_full.csv",
  "messages": ["No significant KEGG enrichment at adjusted P < 0.05"]
}
```

推荐空结果不生成含占位行的 table；可以保留 full_table。为兼容旧上游，若 no_results 仍提供占位 CSV，BioReport 以 status 为准，不计入条目、不绘图。凡声明非空 table/full_table 路径，都必须实际交付文件。

### 富集 CSV 契约

UTF-8 编码，英文逗号分隔，首行为列名，包含逗号或换行的文本按标准 CSV 引号转义。必需列：

| 列 | 类型/要求 |
| --- | --- |
| `Description` | 功能条目/通路名称 |
| `GeneRatio` | 如 `2/100` 的分数字符串，分母必须大于 0；也支持有限数值 |
| `Count` | 非负数，实际应为基因命中整数 |
| `p.adjust` | 数值，校正后 P，范围 0–1 |

推荐同时保留 `ID,BgRatio,pvalue,qvalue,geneID,RichFactor,FoldEnrichment,zScore` 等原始列。GO 若有 `ONTOLOGY` 可保留 BP/CC/MF；KEGG 若有 `category,subcategory` 可保留。不要按命名猜测缺失分类。

上游可把 table 定义为显著条目表，full_table 定义为全部检验条目表；若 table 本身含全部条目，报告仍按有效 cutoff 筛选。term_count 表示 table 行数，而不是报告 Top N 数量。

## 5. 展示参数与统计口径

```json
{
  "analysis": {
    "enrichment": {"top_n": 12},
    "deg": {"log2fc_threshold": 1, "pvalue_threshold": 0.05, "colors": {"up": "#e41749", "down": "#41b6e6", "ns": "#c7c7c7"}}
  },
  "report": {
    "type": "rna-seq",
    "layout": "single",
    "output_format": "html"
  },
  "ai": {"enabled": false}
}
```

`deg.colors` 自定义火山图上下调与非显著点配色（键大小写均可，值为 `#RRGGBB`）；缺省为出版级默认 `up #e41749 / down #41b6e6 / ns #c7c7c7`，中文与英文报告的图注色点会同步该配置。

富集 cutoff 的优先级：显式 `analysis.enrichment.p_cutoff` > 各数据库 `parameters.cutoff` > 旧格式默认 0.1。建议不写全局 p_cutoff，让 GO/KEGG 分别继承上游阈值。报告按 `p.adjust < cutoff`、稳定升序选取 Top N；如果上游采用 `<=`，边界值的含义需要明确统一。

`parameters.padj_th` 记录上游筛选富集输入基因的阈值；它不会把当前 DEG 火山图的显著性列切换为 padj。当前报告 DEG 仍使用原始 `pvalue` 和 `|log2FoldChange|`，这个差异不能通过改字段名隐藏。

默认输出 HTML；同时输出 PDF 可将 output_format 设为 `["html", "pdf"]`，保持 layout 为 single。

## 6. 上游校验

将配套 Schema 与输出 JSON 一起交给上游开发；Schema 不会读取 CSV。以下命令在 BioReport 仓库根目录运行：

```sh
python - <<'PY'
import json
from pathlib import Path
from jsonschema import Draft202012Validator, FormatChecker
schema = json.loads(Path('configs/rnaflow.delivery.schema.json').read_text())
data = json.loads(Path('configs/report.rnaflow.example.json').read_text())
Draft202012Validator(schema, format_checker=FormatChecker()).validate(data)
print('JSON contract valid')
PY

# 现有 2.0.0 交付兼容性检查
python -m bioreport validate -c examples/X101SC26098749-Z01-J001_UPDATE/report.paths.json

# RNAFlow 实际生成的 2.1.0 配置须位于以 platform.report_id 命名的目录
python -m bioreport validate -c "/path/to/<report_id>/report.paths.json"
```

Schema 检查字段类型、必填项、路径形式和状态规则；BioReport 再检查所选模块必需文件、富集表必需列、声明路径存在性和 term_count。样本集合、比较组完整性及参考版本等语义也应由上游保证。

当 `schema_version` 为 `2.1.0` 时，Schema 还会要求完整 `project`、`platform` 和 `files` 结构；`bioreport validate` 会进一步验证 `report_id` 格式、任务时间时区、文件索引在报告目录内、索引条目文件存在，以及 JSON 中的文件引用均被索引。缺少 `project.user_id`、平台字段、索引条目或存在路径逃逸时，校验失败并报告对应字段。2.0.0 保持原有必填字段和 `files` 映射兼容，不会被强制要求补充 2.1.0 字段。

本次真实项目的 report.paths.json 为非破坏性新增副本；保留原 project_summary.json。它仅收录交付记录中可确认的四个软件版本，其余版本需要 RNAFlow 在下一次交付时补充。

升级实施计划见 [BioReport JSON Schema 2.1.0 更新计划](info/26.10.25/BioReport_JSON_Schema_2.1.0_更新计划.md)。BioReport 仓库只负责消费与校验 2.1.0 契约；RNAFlow 交付端仍须从真实任务上下文写入 `user_id`、`task_id` 和平台绑定信息。
