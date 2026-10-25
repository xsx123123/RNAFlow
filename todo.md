# RNAFlow 仓库优化清单

> 生成时间: 2026-05-15
> 最近核对: 2026-10-25
> 状态说明: `[x]` 已根据当前仓库状态核实完成；`[ ]` 未完成或未验证；`[~]` 部分完成。

## 📊 核对结论（2026-10-22）

### ✅ 已完成

| 条目 | 证据 |
|------|------|
| `report` 子模块清理 | `git -C report status --short` 为空，修改已提交；`report/.gitignore` 已跟踪 |
| `skills/path_config.yaml` 路径 | 改为自动推导（`RNAFLOW_ROOT: ""`），模板路径为 `skills/examples/...`，无双斜杠 |
| `config/reference.yaml` 迁移提示 | 文件头已加入 Migration Note，并保留路径注释 |
| `mcp/mcp_config.yaml` 硬编码路径 | `conda_path` / `snakemake_path` 已改为空值占位并给出示例 |
| 文档 logger 版本 | README、中文 README、installation、skills 文档统一为 `>=0.3.0`（PyPI 最新版本） |
| `container_env.yaml` 忽略规则 | `container_env` 为子模块，其内部 `.gitignore` 第 71 行已忽略该文件 |
| KEGG 双路径接通 | `deg_enrich_wrapper.py` 转发 `organism` / `term2gene` / `term2name`；`kegg_enricher.r` 支持对应 CLI 参数 |
| KEGG 显式数据来源 | `config/reference.yaml` 的 `deg_enrich_wrapper` 已配置 `enabled`、`organism`、`id_map`、`term2gene`、`term2name` |
| README 拆分 | 长内容已迁移到 `docs/`（architecture、installation、configuration、usage、container_builder、reference_builder、ai_skills、mcp_server、version_history），README 由 987 行缩减到 168 行 |

### 🟡 部分完成

| 条目 | 说明 |
|------|------|
| KEGG 富集背景 | 当前 `universe = unique(id_map$ncbi)` 仍是整张注释映射表，**未限定为通过 DEG 筛选的基因**，与计划要求不一致 |
| KEGG 文档/摘要同步 | `docs/project_summary_json.md` 仍写“wrapper 没传入 term2gene/term2name”；`docs/KEGG_enrichment.md` 顶部仍标示实现与描述有差异 |
| KEGG 端到端验证 | 未在当前代码版本上重新跑真实数据；文档中的验证数字早于当前实现，不能直接作为验收依据 |
| README 中英文同步 | 版本号已同步；英文 README 已拆分，`docs/README_zh.md` 仍是单体长文档 |
| 测试覆盖 | 新增 `tests/test_parallel_analysis.py`、`tests/test_enrichment_plots.py/.R`，但仍无 Snakemake 规则测试、report 模块测试，MCP 仍只有 2 个脚本式测试 |

### ⬜ 未完成

- `src` 子模块落后 `origin/main` 3 个提交（不是清单原先记录的 9 个），其中包含 GO 合并冲突修复和 KEGG `_full` 表调整。
- `requirements.txt` 仍含大量 `file:///home/conda/...` 本地路径依赖；`snakemake-logger-plugin-snkmt` 与 `snkmt` 仍同时存在。
- 代码质量项：`sys.exit()`、注释代码、日志方式混用、宽泛异常捕获均未处理。
- 编码声明未统一；主仓库仍无 `ruff`/`black` 配置。
- `skills/INSTALL.md` 仍使用 `/home/zj/...` 真实路径示例。
- P3 新功能（GSVA、TF 调控、解卷积、LncRNA、云原生参考管理）未落地；WGCNA 仅在 `src/skills/wgcna/` 提供独立 skill/脚本，尚未接入主流程。

---

## 🦀 Rust 化计划（2026-10-25 核对）

> 依据 2026-10-25 全仓盘点（对照 FlowFrame v2.0 规范 + `src` 子模块工具调研）。
> 取舍原则：只 Rust 化**重 IO/重解析、逻辑确定、不依赖 R/Python 生态库**的步骤；DESeq2/edgeR/clusterProfiler/ggplot2/sklearn 等生态依赖一律保留 R/Python。
> 涉及 `src` 子模块的条目需先在 JZ_Tools 提交，再更新主仓库子模块指针。

### 现有 Rust 工具与接线状态

| 工具 | 版本 | 接线 | 备注 |
|------|------|------|------|
| `seq_preprocessor` | 0.2.0 | ✅ rules/02 | FASTQ 标准化重命名；流程未传 `--library-type`，工具按默认 `auto` 猜测命名模式 |
| `json_md5_verifier` | 0.2.0 | ✅ rules/02 | MD5 校验（rayon 并行），输出 `01.qc/md5_check.tsv` |
| `data_deliver` | 0.6.0 | ✅ rules/13 | pyo3 + maturin 打包为 pip 包 `rnaflow-cli`，本地交付 + TOS 云上传 |
| `filter_pe` | 0.3.0 | ❌ 未消费 | ATAC 专用（rust-htslib BAM 过滤），与 RNAFlow 主流程无关 |

配套收敛项：

- [ ] **去掉 `rnaflow-cli` 的 Python fallback 或改为 fail-fast**
  - 现状: `src/src/data-deliver/RNAFlow_Deliver_Tool/python/RNAFlow_Deliver/modules/deliver.py:18-34`，`data_deliver_rs` import 失败时静默退化为纯 Python 拷贝 + Python MD5，性能塌陷且无告警
  - 依据: FlowFrame 规范 §4.2「唯一实现，不保留 Python fallback」

- [ ] **data_deliver 双 crate 收敛为一个**
  - 现状: `src/src/data-deliver/data_deliver/`（纯 lib）与 `src/src/data-deliver/RNAFlow_Deliver_Tool/`（bin + pyo3 + maturin，超集）同名同版本 0.6.0，双拷贝维护
  - 建议: 保留 RNAFlow_Deliver_Tool 超集，删除独立 lib 目录

- [ ] **删除废弃 Python MD5 实现**
  - 现状: `src/src/md5/check_md5.py`（133 行，主流程未接线）、`src/skills/md5/scripts/verify_manifest.py`（47 行）
  - 功能已被 `json_md5_verifier` 覆盖，直接删除

- [ ] **交付工具更名 `flow-deliver`**（规范 §6.4 / §13.3）
  - 现状: pip 包与 console script 均为 `rnaflow-cli`，RNAFlow 品牌耦合；跨流程复用语义不符

### 第一梯队 — 每次全量运行都跑，IO/解析密集（优先做）

- [ ] **merge_rsem → Rust**
  - 现状: `src/src/gene_matrix/merge_rsem.py`（206 行，pandas）。逐样本读 RSEM `genes/isoforms.results`，按 gene_id 对齐合并 counts/TPM/FPKM 三矩阵 TSV，是全流程最大的纯表格合并点
  - 建议: 流式归并实现，crate 放 `src/src/gene_matrix/`，经 `Compile_release` 发布；接线点 `config/run_parameter.yaml` merge_rsem 路径 + `rules/07.rsem.smk` merge_rsem 规则
  - 验收: 与 pandas 版在真实数据上输出 diff 为空，并记录耗时基线

- [ ] **merge_rmats_summary → Rust**
  - 现状: `src/src/rMATS/merge_rmats_summary.py`（118 行，pandas）。合并 12 类 JC/rMATS 事件表 + FDR/PSI/min_reads 阈值过滤
  - 接线点: `run_parameter.yaml` merge_rmats + `rules/11.rMATS.smk` 两个 merge 规则

- [ ] **Filter_Novel_Transcripts 抽成 Rust 工具**
  - 现状: `rules/09.Assembly.smk:197-243` rule `run:` 块内嵌 Python，GTF 两遍扫描按 class_code `=`/`j` 拆分 annotated/novel；GTF 为 GB 级文件，单线程逐行处理
  - 建议: 独立 crate（如 `gtf_filter`），rule 改 shell 调用，输入输出路径不变；顺带消掉 rule 内嵌代码

- [ ] **annotation_to_enrichment → Rust**
  - 现状: `src/src/Enrichments/annotation_to_enrichment.py`（175 行，纯标准库）。eggNOG 注释 → GO assoc + KEGG term2gene/term2name；eggNOG 注释文件 GB 级
  - 备注: 唯一网络调用（KEGG pathway 命名）已有离线 TSV 路径，Rust 版直接走离线文件

### 第二梯队 — 小而便宜，接线点现成

- [ ] **check_libtype → Rust**
  - 现状: `src/src/library_type/check_libtype.py`（82 行）。解析 RSeQC infer_experiment 汇总 → fr-firststrand/secondstrand/unstranded
  - 接线点: `config/config.yaml` software 段已有条目，`rules/11.rMATS.smk` 两个规则调用；替换后可消掉 11 步的 `python3` 依赖

- [ ] **project_summary 构建器 → Rust CLI**
  - 现状: `rules/utils/project_summary.py`（210 行，纯标准库），在 14.Report 的 run 块内 import 调用，已有 `schema/project_summary.schema.json` 校验
  - 收益: 主要是一致性与复用（报告容器 / MCP / 其他 Flow 直接调用同一二进制），性能其次；迁移时需保留 jsonschema 校验语义

### 第三梯队 — 低频但大文件（参考数据准备，随参考构建脚本一并做）

- [ ] **GTF/GFF 工具族统一为一个 Rust 工具**
  - 现状: `src/src/DEG/gtf2tsv.py`、`src/src/GFFconvert/gff2tsv.py`、`src/src/ATACTools/tools/gtf2tss.py`、`src/src/ATACTools/gtf2tssbed.sh`（awk）四处重复实现

- [ ] **GAF/OBO 解析族 → Rust**
  - 现状: `src/src/GAF2GO/gaf2go.py`（247 行）、`obo2go.py`（148 行）、`src/src/GO_Annotation/MGI_gaf_parser.py`；GAF/OBO 为 GB 级逐行解析
  - 备注: `uniprot_gaf_converter_v2.py` 含 REST ID 映射语义，先拆离线部分再迁

### 明确不 Rust 化（生态依赖，保留现状）

| 脚本 | 依赖 |
|------|------|
| `run_deseq2.r` / `run_edger.r` | DESeq2 / edgeR |
| `go_enricher.r` / `kegg_enricher.r` | clusterProfiler + ontologyIndex |
| `run_dist.r` / `run_pheatmap.r` / `qc_rsem_ultimate.py` | ggplot2 / pheatmap / plotnine + sklearn |
| `run_deg_parallel.py` / `deg_enrich_wrapper.py` | 仅 R 进程调度器，Rust 化收益低 |
| STAR/RSEM/fastp/GATK/rMATS/Arriba 等第三方工具本体 | — |

实施顺序建议：先做「配套收敛项」（半天级），再按一 → 二 → 三梯队逐个迁移；每个工具迁移后先 dry-run 回归（规范 §12.2），真实数据输出 diff 一致后再切换接线。

---

## 📋 报告命令溯源计划（2026-10-25 核对）

> 目标：把流程每一步的实际命令（shell 模板）嵌入 `project_summary.json`，网页报告按模块展示每个分析步骤的命令，实现"结果 ↔ 命令"的可溯源交付。
> 可行性已验证：Snakemake 9.19.0 下 `workflow.rules` 迭代的每个规则对象直接暴露 `.shellcmd`（原始模板，含 `{input}`/`{wildcards}` 占位符）与 `.log`，**无需手工维护命令副本，与 rule 定义零漂移**。

### 方案要点

- 命令来源：snakefile 层 include 完 01–12 后内省收集（不复制、不进 manifest 双份维护）：

  ```python
  WORKFLOW_STEPS = [
      {"rule": r.name, "command": r.shellcmd,
       "log": str(r.log[0]) if r.log else None}
      for r in workflow.rules
      if r.name not in ("all", "all_target") and r.shellcmd
  ]
  ```

- 元数据来源：`rules/manifests/*.manifest.yaml` 已有每个 rule 的 `title/summary/wildcards/conda/resources_tier/ports`，按 rule name 与 shellcmd 合并成完整步骤描述。
- 接线点：`generate_docker_json`（`rules/14.Report.smk:11-56`）与 snakefile 同进程，经 `params` 传入 run 块即可。

### 待办清单

- [ ] **schema 升 2.1.0**
  - `schema/project_summary.schema.json` 顶层 `additionalProperties: false`，必须新增 `workflow` 定义并升 `schema_version`，否则校验直接失败
- [ ] **snakefile 内省 + manifest 合并**
  - 新增 `WORKFLOW_STEPS` 收集；`rules/utils/project_summary.py` 增加 `workflow` 段构建函数（与 manifest 元数据按 rule name 合并）
- [ ] **模块开关过滤**
  - 复用 `_resolve_enabled_modules()` 只嵌入本次启用的模块；`only_qc: true` 时如实只展示 QC 链路
- [ ] **run 块规则回落处理**
  - `Filter_Novel_Transcripts`、`generate_docker_json` 无 `shellcmd`，回落到 manifest summary 或标注 `python`；内置 `all` 规则过滤
- [ ] **报告端展示**
  - 报告容器端（`rnaflow_report.py` 为 `.get()` 宽松读取，加字段不会崩）新增"流程步骤"页签，按模块分组、代码块渲染命令模板
- [ ] **端到端验证**
  - dry-run 校验 schema；真实数据运行后确认 JSON 中命令与 `pipeline_version` 绑定、模块开关过滤正确

### 二期可选（渲染级命令）

- 真实样本名/路径的已渲染命令需要 job 级信息；当前 logger 插件是文本解析式（`__init__.py` 靠 `"Finished jobid:" in msg` 匹配），无结构化 job 对象
- 前置：JZ_Tools 插件升级为事件式（`job_started` 事件含 `job.shellcmd`）；或在报告前端用 manifest 的 input/output pattern 做简单替换渲染

### 附带收益

- 交付 JSON 自带"这套结果用什么命令跑出来的"，与 `pipeline_version` 绑定，补全 delivery_manifest 审计链；一期只嵌模板命令，天然不含真实路径/密钥，体积约几十 KB

---

## 今日计划：KEGG 双路径分析（2026-10-21）

计划实施时间：今天下午或晚上。状态：核心代码已实现，背景与文档验收未完成。

- [x] 接通 KEGG 官方注释与项目自定义注释两条路径，显式配置数据来源；官方注释适用于覆盖且 ID 匹配可靠的物种，自定义注释支持 gene→pathway 或 gene→KO→pathway。
- [x] 打通 wrapper、R CLI 与 TERM2GENE/TERM2NAME；自定义路径不强制要求 organism，官方数据保存固定快照与来源信息。
- [ ] 修正富集背景，限定为本次差异检验中符合筛选资格且具有通路注释的基因；统一基因计数，处理 ID 歧义并输出映射覆盖统计。
      - 现状：`kegg_enricher.r` 中 `universe = unique(id_map$ncbi)` 使用完整 id_map，未与 `eligible` 基因取交集。
- [ ] 同步主流程、独立 skill、结果命名、项目摘要及使用文档，明确区分无显著结果与映射/执行失败。
      - 现状：`docs/project_summary_json.md` 与 `docs/KEGG_enrichment.md` 仍有过期描述。
- [ ] 验证两条路径的端到端运行、超几何检验与 BH 校正、背景及重复计数、异常分支，以及固定快照断网复现。
      - 现状：本次核对未运行真实数据；历史验证结果不覆盖当前代码。

调查与实施依据：[KEGG 模块调查与双路径建议](docs/KEGG_module_investigation_2026-10-21.md)。

---

## 🔴 P0 - 高优先级（影响功能/稳定性）

### 1. 子模块状态问题
- [ ] **src 子模块落后 3 个提交**
  - 当前状态: `## main...origin/main [behind 3]`
  - 待合入: `432fc81`（去掉 KEGG `_full` 表）、`8979a61`（修复 `go_enricher.r` 冲突标记）、`6900bd8`（KO ID 通路名解析）
  - 建议: `cd src && git pull origin main`，随后在父仓库更新子模块指针

- [x] **report 子模块有大量未提交的修改**
  - 当前状态: 工作区干净，修改已提交；`.gitignore` 已跟踪

### 2. 文档版本不一致
- [x] **snakemake_logger_plugin_rich_loguru 版本号不匹配**
  - 已统一: README、中文 README、installation、skills 文档均指向 `>=0.3.0`
  - 说明: 版本历史中的 `0.1.4` 是历史记录，保留不改

### 3. 硬编码路径问题
- [x] **skills/path_config.yaml 路径不一致**
  - 已改为自动推导，`RNAFLOW_ROOT: ""`，模板使用相对路径

- [x] **config/reference.yaml 硬编码路径**
  - 已加入 Migration Note，明确提示迁移时修改 `reference_path` / `fastq_screen_db_path`

- [x] **mcp/mcp_config.yaml 硬编码路径**
  - `conda_path` / `snakemake_path` 已改为空占位，并给出示例

---

## 🟡 P1 - 中优先级（代码质量/维护性）

### 4. 代码质量改进
- [ ] **统一错误处理方式**
  - 现状: `rules/utils/` 仍有多处 `sys.exit(1)`
  - 文件: `rules/utils/common.py:211`, `rules/utils/validate.py:88,115,132`, `rules/utils/id_convert.py` 多处
  - 建议: 模块代码抛自定义异常，仅在 CLI 入口 `sys.exit()`

- [ ] **移除或清理注释掉的代码**
  - 现状: `rules/06.mapping.smk:190` 起仍有整段注释掉的 `estimate_library_complexity` 规则

- [ ] **统一日志输出方式**
  - 现状: `rules/utils/` 仍混用 `print()`、`rich.print`、`console.print()`（约 32 处）
  - 建议: 统一使用 `snakemake_logger_plugin_rich_loguru` 的 logger

- [ ] **异常处理过于宽泛**
  - 现状: `report/docker/RNA/templates/scripts/` 多处 `except Exception`，部分未记录日志
  - 建议: 至少记录 warning，不要静默吞掉异常

### 5. .gitignore 完善
- [x] **report 子模块缺少 .gitignore**
  - 已存在并覆盖 `output/`、`__pycache__/`、`*.log`、`.quarto/`、`_freeze/` 等

- [x] **主仓库 .gitignore 补充**
  - `container_env/container_env.yaml` 已在子模块 `.gitignore` 第 71 行忽略；该文件不属于主仓库索引

### 6. 依赖管理优化
- [ ] **requirements.txt 中大量本地路径依赖**
  - 现状: 78 处 `file:///home/conda/...` 或 `file:///opt/conda/...`
  - 建议: 拆分运行时/开发依赖，并用 `conda env export --no-builds` 生成可移植列表

- [ ] **清理旧版本依赖**
  - 现状: `snakemake-logger-plugin-snkmt==0.1.4` 与 `snkmt==0.2.1` 仍同时存在
  - 建议: 确认是否还需要 `snkmt`，不需要则移除

### 7. 配置文件规范
- [x] **skills/path_config.yaml 路径格式问题**
  - 双斜杠已消除，模板路径为 `skills/examples/...`

- [x] **container_env/container_env.yaml 包含本地数据**
  - 已在 `container_env` 子模块内忽略，不再进入版本控制

---

## 🟢 P2 - 低优先级（功能增强/测试）

### 8. 测试覆盖
- [ ] **增加 mcp 测试覆盖**
  - 现状: `mcp/test/` 仍只有 2 个脚本式测试
  - 建议: 为 `run_rnaflow_tool`、`create_project_structure_tool` 等核心工具添加单元测试

- [ ] **添加 rules/ 的测试**
  - 现状: 已有 `tests/test_enrichment_plots.py/.R`、`tests/test_parallel_analysis.py`，但无 Snakemake 规则测试
  - 建议: 使用 `snakemake --lint`，或引入 `pytest` + `snakemake` 测试框架

- [ ] **添加 report 模块测试**
  - 现状: `report/` 子模块仍无正式测试
  - 建议: 为 `consolidate_rna_seq_data.py`、`setup_report.py` 等添加测试

### 9. 代码风格
- [ ] **统一文件编码声明**
  - 现状: `snakefile` 使用 `# *---utf-8---*`，`build_reference/snakefile` 使用 `# -*- coding: utf-8 -*-`
  - 建议: 统一为标准写法

- [ ] **Python 代码风格检查**
  - 现状: 主仓库无 `pyproject.toml` / `ruff.toml` / `.ruff.toml`
  - 建议: 引入 `ruff` 或 `black`，复用 `container_env/pyproject.toml` 的配置思路

### 10. 文档改进
- [ ] **README.md 和 docs/README_zh.md 同步**
  - 现状: 版本号与 logger 版本已同步；英文 README 已拆分，中文版仍是单体文档
  - 建议: 后续按同一结构拆分中文文档，或明确中文版为完整单页

- [ ] **skills/INSTALL.md 路径示例更新**
  - 现状: 仍使用 `/home/zj/pipeline/RNAFlow`
  - 建议: 统一为 `<RNAFLOW_ROOT>` 占位符

---

## 🚀 P3 - 新功能（参考路线图）

### v0.2.0 规划功能
- [ ] **WGCNA (加权基因共表达网络分析)**
  - 现状: `src/skills/wgcna/` 已有独立 skill 和 R 脚本，但未接入主流程
  - 待办: 模块聚类、表型关联分析、Cytoscape 网络导出

- [ ] **GSVA (基因集变异分析)**
  - 计算每个样本的通路活性评分
  - 支持通路差异分析和可视化（热图/相关性）

- [ ] **TF 调控网络预测**
  - 整合 PlantRegMap / PlantTFDB（植物）
  - 预测差异基因上游转录因子调控逻辑

- [ ] **细胞类型解卷积**
  - 引入 CIBERSORTx / MuSiC 算法
  - 使用单细胞参考集解析组织样本中的细胞类型比例

- [ ] **LncRNA 预测与分析**
  - 整合 CPAT / CPC2 / LncFinder 识别新 LncRNA
  - 构建 LncRNA-mRNA 共表达网络

- [ ] **云原生参考基因组管理**
  - 支持自动同步参考基因组到 S3/OSS/MinIO
  - 实现 "BYOC (Bring Your Own Cloud)" 策略

---

## 📋 快速修复清单（可在单次提交中完成）

1. [x] 更新所有文档中的 `snakemake_logger_plugin_rich_loguru` 版本号（现为 `>=0.3.0`）
2. [x] 修复 `skills/path_config.yaml` 中的路径（改为自动推导）
3. [x] 修复 `skills/path_config.yaml` 中的双斜杠 `//`
4. [ ] 清理 `rules/06.mapping.smk` 中注释掉的代码
5. [x] 为 `report/` 子模块添加 `.gitignore`
6. [x] 将 `container_env/container_env.yaml` 加入忽略规则（子模块 `.gitignore`）
7. [ ] 统一 `snakefile` 和 `build_reference/snakefile` 的文件头编码声明
8. [x] 提交 `report` 子模块的修改并更新主仓库引用
9. [ ] 更新 `src` 子模块到最新版本

---

## 📝 本次实际变更（2026-10-22）

- 拆分 README：新增 `docs/architecture.md`、`installation.md`、`configuration.md`、`usage.md`、`container_builder.md`、`reference_builder.md`、`ai_skills.md`、`mcp_server.md`、`version_history.md`；README 保留概览、核心特性、分析流程、快速开始、文档索引和版本策略。
- 修正拆分中发现的过期内容：规则编号（`03.short_read_qc`、`06.mapping`、`10.DEG_Enrichments`、`13.deliver`）和 logger 插件版本（`>=0.3.0`）。
- 保留 `docs/README_zh.md` 为中文完整文档，尚未按英文结构拆分。

## 📝 本次实际变更（2026-10-25）

- 新增「📋 报告命令溯源计划（2026-10-25 核对）」章节：project_summary.json 嵌入流程命令（workflow.rules 内省 shellcmd + manifest 元数据合并）的方案、待办清单（schema 升 2.1.0、开关过滤、run 块回落、报告端展示）与二期渲染级命令的可选路线。
- 新增「🦀 Rust 化计划（2026-10-25 核对）」章节：现有 Rust 工具接线盘点（seq_preprocessor / json_md5_verifier / data_deliver / filter_pe）+ 三梯队迁移候选（第一梯队：merge_rsem、merge_rmats_summary、Filter_Novel_Transcripts、annotation_to_enrichment；第二梯队：check_libtype、project_summary；第三梯队：GTF/GAF/OBO 工具族）+ 明确不 Rust 化清单 + 配套收敛项（rnaflow-cli fallback、双 crate、废弃 MD5 脚本、flow-deliver 更名）。
- 更新头部「最近核对」日期至 2026-10-25。
