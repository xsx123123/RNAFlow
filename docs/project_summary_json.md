# 项目结果 JSON v2

`project_summary.json` 是供外部仓库使用的结果交换文件，不再只是旧 Quarto 报告的路径配置。不修改 `report` 子仓库，也不依赖 HTML 渲染。

## 生成与交付

默认配置：

```yaml
project_summary: true
report: false
```

正常运行流程会在数据交付完成后生成：

```text
{data_deliver}/report_data/
├── project_summary.json
└── data/
    ├── index/
    └── res/
        ├── DEG/
        └── Enrichments/
```

也可以使用原来的 `generate_docker_json` Snakemake 目标单独生成，规则名保留以兼容已有命令。该目标仍会先完成分析和数据交付，但不会启动 Docker、Apptainer、Singularity 或 Quarto。`project_summary: false` 只从默认目标中关闭 JSON 导出；显式指定规则目标仍可执行。导出依赖交付规则，即使 `deliver: false` 也会通过依赖生成所需交付数据。

旧 HTML 规则保留但默认关闭；本次不适配其消费者。旧配置显式设置 `report: true` 仍会选择旧渲染规则，迁移到外部报告时请设为 `false`。

## 顶层结构

| 字段 | 含义 |
| --- | --- |
| `schema_version` | 固定为 `2.1.0`，外部消费者据此识别新契约 |
| `path_base` | 固定为 `.`，路径相对 JSON 所在目录解析 |
| `project` | 项目 ID、平台用户 ID、客户、物种、参考版本、流程版本和分析日期 |
| `platform` | 报告与任务平台元信息，全部字段必填（见下两节） |
| `files` | 结果文件语义索引，覆盖 `input_files` 文件、DEG CSV 与富集 `table` / `full_table` |
| `software_versions` | 内嵌的真实软件版本记录，至少一条 |
| `stats` | 样本数和分组数 |
| `input_files` | QC、表达矩阵、样本表、比较表、DEG 等交付文件的约定路径 |
| `enrichment.go` | GO 方法、参数、按比较组和方向组织的实际结果 |
| `enrichment.kegg` | KEGG 方法、参数、按比较组和方向组织的实际结果 |

不再提供含混的 `input_files.enrichment_dir`。各富集结果通过独立的 `table` / `full_table` 定位。所有路径使用 `data/...` 相对路径，不写死宿主机路径或容器 `/data` 路径。将 JSON 和相邻 `data/` 一起移动后仍可解析。`input_files` 是交付布局约定，不保证所有可选模块的文件均存在；富集表则会实际检查文件。

## 平台与任务绑定（2.1.0 新增）

`schema_version` 为 `2.1.0` 时，`project` 与 `platform` 的字段全部必填且非空：

- `project.user_id`：平台用户 ID，必须由实际发起任务的上下文写入，用作报告归属与权限绑定键；不得使用示例占位值。
- `platform.task_id`：平台任务 ID，同样来自真实任务上下文。
- `platform.report_id`：由导出规则按 `<project_id>_<yyyymmdd-hhmmss>` 自动生成，与平台登记的报告目录名一致。
- `platform.flow_type` 固定 `rna_seq`，`flow_version` 取配置中的 `pipeline_version`；`title` 默认按生成日期自动命名，`status` 默认为 `completed`（导出仅在交付完成后执行），`generated_at` 为带时区的 ISO 8601 时间，`expire_at` 可为 `null`，这四项可在配置中覆盖；`html_entry` 默认为 `report.html`。

任务上下文通过分析 yaml 或 `--config` 注入：

```yaml
platform:
  user_id: "平台用户 ID"
  task_id: "平台任务 ID"
  # 可选覆盖：title / status / expire_at / html_entry
```

缺少 `platform.user_id` 或 `platform.task_id` 时导出直接报错，不会输出带占位值的交付。

## 结果文件语义索引（2.1.0 新增）

`files` 数组为平台检索与 AI 上下文提供语义化文件索引，每条包含 `path`、`role`、`description`、`format`：

- `path` 相对 JSON 所在目录，只收录实际存在的文件；目录型 `input_files`（如 `fastp_report_dir`、`qualimap_dir`）不进入索引。
- `role` 取自固定词表：`expression_matrix_tpm`、`expression_matrix_count`、`sample_metadata`、`contrast_definition`、`deg_table`、`enrichment_table`、`qc_stats`、`qc_report`、`figure`、`log`、`other`。
- `deg_table` 必须附带 `contrast`；`enrichment_table` 必须附带 `contrast`、`direction`（UP/DOWN）与 `ontology`（GO/KEGG）。
- 索引覆盖：`input_files` 中的全部文件路径、`data/res/DEG/*_DEG.csv` 每个差异结果 CSV，以及每个启用的富集 `table` / `full_table`。

## 富集结果

以下是截取示例，不是完整 JSON 文档：

```json
{
  "schema_version": "2.0.0",
  "path_base": ".",
  "enrichment": {
    "go": {
      "enabled": true,
      "method": "clusterProfiler::enricher",
      "parameters": {
        "gene_col": "ENSEMBL",
        "padj_th": 0.05,
        "lfc_th": 1,
        "cutoff": 0.05,
        "gene_regex": "gene:/"
      },
      "contrasts": {
        "Salt_vs_AC": {
          "UP": {
            "status": "available",
            "table": "data/res/Enrichments/Salt_vs_AC_GO_UP.csv",
            "term_count": 1,
            "messages": []
          },
          "DOWN": {"status": "no_results", "term_count": 0, "messages": ["No significant enrichment found"]}
        }
      }
    },
    "kegg": {
      "enabled": true,
      "method": "clusterProfiler::enrichKEGG",
      "parameters": {
        "gene_col": "ENSEMBL", "padj_th": 0.05, "lfc_th": 1, "cutoff": 0.05,
        "organism": "sly", "id_mapping": "id_map", "min_gs": 10, "max_gs": null, "plot": false
      },
      "contrasts": {
        "Salt_vs_AC": {
          "UP": {
            "status": "available",
            "table": "data/res/Enrichments/Salt_vs_AC_KEGG_UP_enrichments.csv",
            "full_table": "data/res/Enrichments/Salt_vs_AC_KEGG_UP_enrichments_full.csv",
            "term_count": 1,
            "messages": []
          },
          "DOWN": {"status": "unavailable", "term_count": 0, "messages": ["Expected result not found: data/res/Enrichments/Salt_vs_AC_KEGG_DOWN_enrichments.csv"]}
        }
      }
    }
  }
}
```

- 比较组来自流程的 `ALL_CONTRASTS`，不会只选第一个比较组，也不会扫描并混入无关旧比较组。比较名统一为 `Treat_vs_Control`，与 DEG 输出一致；`contrasts.csv` 的 `Control` / `Treat` 分别指定对照组和处理组。
- 新输出的 GO 主表为 `{contrast}_GO_{UP|DOWN}.csv`；KEGG 主表为 `{contrast}_KEGG_{UP|DOWN}_enrichments.csv`，全量表为 `{contrast}_KEGG_{UP|DOWN}_enrichments_full.csv`。文件名直接标明数据库。
- JSON 优先读取新命名；新主表不存在时兼容旧的 `{contrast}_{UP|DOWN}.csv`（GO）和 `{contrast}_{UP|DOWN}_enrichments.csv`（KEGG），并在 `messages` 中标记 `Legacy filename`。全量表只匹配所选主表的命名，不混用新旧结果。不回退到已删除 examples 副本的 `_KEGG_UP.csv` 命名。
- JSON 不内嵌 `terms`；完整数据保留在 `table` / `full_table` 指向的 CSV 文件中。
- `term_count` 是源 `table` 的实际非占位数据行数，不是报告 Top N 数量。
- `ID=None` 或 `Count=0` 的占位行不计入 `term_count`，原因保留在 `messages`。
- KEGG `full_table` 只提供未筛选完整表的路径，不重复嵌入测试行。
- `enabled` 同时考虑 `deg` / `only_qc` 和 KEGG 物种开关。关闭模块时忽略残留 CSV，状态为 `disabled`。
- 参数记录当前执行链实际使用的值。当前 KEGG wrapper 没传入 `term2gene/term2name`，因此 JSON 不声称使用了本地离线通路注释；`max_gs: null` 表示主脚本默认不限制，`plot: false` 表示流程未传 `--plot`。

### 方向状态

| `status` | 含义 |
| --- | --- |
| `available` | 主表存在且至少有一条非占位结果 |
| `no_results` | 表存在，但没有非占位结果，不代表文件缺失 |
| `unavailable` | 已启用但未交付该方向结果 |
| `disabled` | 本次配置未启用，不读取旧文件 |
| `failed` | 上游执行失败，并在 `messages` 中说明原因 |

CSV 列缺失、行损坏或非法数值会导致导出失败，不会静默输出成功状态。JSON 导出会通过 `schema/project_summary.schema.json` 校验。`allow_nan=False` 保证输出标准 JSON。

## 外部仓库接入

1. 校验 `schema_version`，使用 `schema/project_summary.schema.json` 验证。
2. 分别遍历 `enrichment.go.contrasts` 和 `enrichment.kegg.contrasts`。
3. 每个比较组读取 `UP` / `DOWN`，先判断 `status`，再从 `table` 读取结果表。
4. 下载主表或全量表时，以 JSON 所在目录拼接 `table` / `full_table`。

这是破坏性版本升级：旧 `/data/...` 路径和统一 `enrichment_dir` 消费逻辑不再适用。此次只定义并导出契约，不更新内置报告或外部仓库。
