# RNAFlow 对齐 FlowFrame 架构审核文档

## 变更范围

- 分支：`refactor/rnaflow-flowframe-alignment`
- 参考规范：`FlowFrame/Flow_framework.md` 与 `flow-framework/references/flow_framework_spec.md`
- 目标：在不改变 RNA-seq 具体分析工具链的前提下，完成 FlowFrame v2.0 要求的通用入口、配置、目标生成、依赖和交付报告接线。
- 说明：本分支未提交 commit，便于审核后手动合并。

## 已完成修改

### 1. 目标生成层

- 在 `rules/utils/common.py` 增加 `MODULE_DEPENDENCIES`、`MODULE_COLLECTORS`、`AnalysisTargets()`、`delivery_outputs()` 和 `report_outputs()`。
- `DataDeliver()` 只基于局部 enabled 集合生成目标，不再修改全局 `config`，不再 `sleep`，不执行文件 IO。
- 依赖模块自动启用：`mapping -> qc_clean`、`count -> mapping`、`deg -> count`，变异、组装、rMATS、融合均依赖 mapping。
- `snakefile` 只计算一次 `ANALYSIS_TARGETS`，交付和报告规则复用该列表；`rule all` 使用最终 `ALL_TARGETS`。
- `13.deliver.smk`、`14.Report.smk` 不再二次调用 `DataDeliver(config)`，避免丢失样本和对比信息。

### 2. 模块开关

- 统一使用小写 `deg`，修复原实现读取 `DEG` 导致 `deg: false` 失效的问题。
- `fastq_screen: false` 时不再生成 FastQ Screen 目标。
- 新增独立 `deliver` 开关；`report: true` 会通过规则依赖自动拉起交付链路，但 `report: false` 不再生成报告目标。
- `only_qc: true` 的目标范围收敛为 MD5、原始读长 QC、fastp 清洗和合并 QC 报告，不再隐式拉入 mapping/count/下游模块。
- 无启用 DEG/rMATS 时不要求 `paired_csv`，使 QC-only 或基础分析配置可独立解析。

### 3. 配置与参考路径

- `snakefile` 仅加载 FlowFrame 规定的四件套配置，移除全局 `container:` 指令和 `container_env` 强制加载。
- `resolve_reference_paths()` 支持 `STAR_index`、`deg_enrich_wrapper`、`ploidy_setting` 的当前基因版本，并解析共享的 `STAR_index.GO.obo` 和当前版本 `go_annotation`。
- `check_reference_paths()` 只校验当前基因版本及 GO 数据库，避免无关 genome 条目阻塞启动。
- Schema 增加顶层必填项、`fastq_screen`、`deliver`、`report_engine`，并移除 STAR genome 配置中错误的强制 `ploidy`。
- `config/config.yaml` 增加统一默认开关和 `pipeline_version`。
- 删除仓库根目录带有真实路径及内网 Loki 地址的 `config.yaml`，新增脱敏模板 `examples/analysisyaml.example.yaml`。

### 4. 交付、报告和集群

- 报告渲染引擎由 `report_engine` 驱动，支持 `auto`、Docker、Apptainer、Singularity。
- `auto` 模式按 Docker → Apptainer → Singularity 顺序探测，适配集群无 Docker 的环境。
- `cluster_config.yaml` 增加 `clusters.default.queues` 映射；集群模式缺少队列映射时 `resource_manager` fail-fast，不再静默提交无队列任务。
- README 已同步项目配置模板路径、deliver/report 开关和 only_qc 语义。

## 验证证据

### 自动检查

以下检查已通过：

```text
snakemake --version                         -> 9.19.0
python3 -m py_compile rules/utils/*.py      -> PASS
git diff --check                             -> PASS
```

### 目标生成单元检查

- `AnalysisTargets()` 不修改输入配置。
- `fastq_screen: false` 时不包含 FastQ Screen 文件。
- `deg: false` 时不包含 `06.DEG` 目标。
- `only_qc: true` 时不包含 mapping/count 目标。
- `report: false` 时不包含报告输出。
- 参考路径解析正确处理 GRCm39 当前版本和 GO OBO 路径，同时保留 `gene_col` 等元数据。

### Snakemake dry-run

使用 `/tmp` 下虚拟参考、样本表和空 FASTQ 夹具完成两次入口级 dry-run：

1. QC-only 配置：DAG 共 13 个 job，仅包含 MD5、fastp、FastQC、MultiQC 和 `rule all`。
2. 非 QC-only、`deg: false`、`fastq_screen: false` 配置：DAG 共 42 个 job，包含 STAR/RSEM 及 mapping/count 相关规则，不包含 DEG 或 FastQ Screen 规则。

虚拟夹具只用于验证配置、规则解析和 DAG 接线，未被当作真实生物学端到端结果。

## 审核重点

- 确认 `only_qc` 是否需要保留旧行为（旧实现会继续运行 mapping/count）；当前实现按 FlowFrame §5.2 的 QC-only 规范收敛。
- 确认生产环境报告镜像是否能被 Docker、Apptainer 或 Singularity 正确运行；默认 `report_engine: auto`。
- 使用真实项目配置执行一次 `snakemake -n`，再执行小规模真实数据端到端测试。
- 本工作树开始时 `src` 子模块指针相对 `main` 已处于变更状态；本分支未修改该子模块内容，请审核时单独处理。

## 建议审核命令

```bash
git diff --stat
git diff -- README.md snakefile rules/ schema/ config/ examples/ docs/
snakemake -s snakefile --cores 1 --use-conda --logger rich-loguru \
  --config analysisyaml=/path/to/project/01.workflow/config.yaml -n
```
