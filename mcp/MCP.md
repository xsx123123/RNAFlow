***

# 组学分析 MCP Server 开发规范文档

**OmicsMCP Framework Specification v1.0**

***

## 一、整体设计原则

### 1.1 核心理念

```
每个 MCP Server = 一条组学分析流程的完整 AI 接口层
不负责分析逻辑本身，只负责：
  - 参数校验与组装
  - 异步任务提交与状态追踪
  - 结果摘要与上下文传递
```


### 1.2 架构分层

```
┌─────────────────────────────────────────┐
│           LLM Orchestrator              │  ← Claude / GPT / 本地模型
└──────────────┬──────────────────────────┘
               │ MCP Protocol
┌──────────────▼──────────────────────────┐
│         各组学 MCP Server               │
│  RNAFlow-MCP  ATACFlow-MCP  WGS-MCP    │
│  ChIPFlow-MCP  scRNA-MCP   ProMCP      │
└──────────────┬──────────────────────────┘
               │ subprocess / API
┌──────────────▼──────────────────────────┐
│       Snakemake Pipeline Layer          │
│  各流程的 Snakefile + conda 环境        │
└─────────────────────────────────────────┘
```


### 1.3 强制约束

- **每个 MCP Server 注册 Tool 数量 ≤ 20 个**（含所有兼容别名）
- **所有涉及 I/O 的 tool 必须是 `async def`**
- **流程执行 tool 必须异步提交，立即返回 `job_id`，不阻塞**
- **禁止在模块顶层执行任何 I/O 操作**（数据库初始化、文件读取等）

***

## 二、目录结构规范

每个 MCP Server 必须遵循以下目录结构：

```
{flow_name}_mcp/
│
├── server.py                  # 唯一入口，只做 MCP 注册
├── pyproject.toml             # 依赖管理
├── README.md                  # 安装与使用说明
│
├── core/
│   ├── config.py              # 路径配置（全部懒加载）
│   ├── logger.py              # 统一日志
│   ├── response.py            # 统一返回格式工具函数
│   ├── middleware.py          # 耗时追踪装饰器
│   └── legacy.py              # Backward compat dispatcher（如需要）
│
├── models/
│   └── schemas.py             # Pydantic 模型，所有输入输出结构定义
│
├── services/
│   ├── pipeline.py            # 流程提交与状态追踪（核心）
│   ├── project.py             # 项目结构管理
│   ├── system.py              # 系统资源 & 环境检查
│   └── results.py             # 结果解析与摘要
│
├── db/
│   ├── database.py            # DB 初始化（懒加载）
│   ├── session.py             # get_db() 单例
│   └── models.py              # ORM 模型
│
├── examples/
│   ├── config_standard.yaml   # 标准配置模板
│   ├── config_minimal.yaml    # 最简配置模板
│   └── samples_template.csv   # 样本表模板
│
├── skills/
│   └── SKILL.md               # AI 使用该 MCP 的引导文档
│
└── tests/
    ├── test_tools.py
    ├── test_services.py
    └── fixtures/              # 测试用小数据集
```


***

## 三、Tool 设计规范

### 3.1 Tool 分类与数量限制

每个 MCP Server 的 Tool 按以下 5 类组织，**总数不超过 20 个**：


| 类别 | 职责 | 数量上限 |
| :-- | :-- | :-- |
| **Setup** | 项目初始化、配置生成 | 4 个 |
| **Execution** | 流程提交、dry-run | 2 个 |
| **Monitor** | 状态查询、日志获取 | 4 个 |
| **Results** | 结果解析、QC 摘要 | 4 个 |
| **System** | 环境检查、资源查询 | 3 个 |
| **Legacy** | 向后兼容（dispatcher） | 1 个 |

### 3.2 必须实现的 Tool 清单（最小集）

所有组学 MCP 必须实现以下 **12 个核心 tool**：

```python
# ===== Setup 类 =====
list_supported_genomes()           # 列出支持的参考基因组
get_config_template(mode)          # 获取配置模板
setup_project(root, name, ...)     # 一键初始化项目结构+配置
validate_config(config_path)       # 校验配置文件
scan_samples(directory)            # 智能扫描目录并提取样本表

# ===== Execution 类 =====
run_pipeline(config_path, ...)     # 异步提交流程，返回 job_id
dry_run_pipeline(config_path)      # 仅验证，不执行

# ===== Monitor 类 =====
get_pipeline_status(job_id)        # 查询运行状态
get_pipeline_log(job_id, lines)    # 获取运行日志
list_runs(project, status, limit)  # 列出历史运行记录
cancel_pipeline(job_id)            # 取消运行中的任务

# ===== Results 类 =====
get_run_summary(job_id)            # 获取结果摘要（QC指标等）
list_output_files(job_id)          # 列出输出文件路径

# ===== System 类 =====
check_environment()                # 检查 conda/软件环境
check_system_resources()           # 检查 CPU/内存/磁盘
```


### 3.3 Tool 命名规范

```
格式：{动词}_{名词}[_{修饰词}]
示例：run_pipeline / get_pipeline_log / list_supported_genomes

禁止：
  - 重复注册同功能 tool（用 legacy_dispatcher 处理旧名称）
  - tool 名称含流程前缀（MCP Server 本身即代表流程）
  - 使用 camelCase（统一用 snake_case）
```


### 3.4 Tool Docstring 必填格式

```python
@mcp.tool()
async def run_pipeline(
    config_path: str,
    cores: int = 20,
    dry_run: bool = False,
    user_confirmed: bool = False,
) -> Dict[str, Any]:
    """
    [一句话说明功能，必须包含「异步/同步」信息]
    
    IMPORTANT: [关键行为说明，LLM 需要知道的注意事项]
    
    Workflow:
      1. [推荐的调用前置步骤]
      2. [本 tool 做什么]
      3. [调用后推荐的后续步骤]
    
    Args:
        config_path: [说明 + 示例路径格式]
        cores: [说明 + 推荐值]
        dry_run: [说明使用场景]
        user_confirmed: [安全确认说明]
    
    Returns:
        {
            "status": "success|error",
            "job_id": "唯一任务ID，用于后续状态查询",
            "message": "人类可读的状态描述"
        }
    """
```


### 3.5 Async 规范

```python
# ✅ 规范：涉及 I/O 的 tool
@mcp.tool()
async def validate_config(config_path: str) -> Dict[str, Any]:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _validate_config_sync, config_path)

# ✅ 规范：长时任务提交
@mcp.tool()
async def run_pipeline(config_path: str, ...) -> Dict[str, Any]:
    try:
        result = await asyncio.wait_for(
            _submit_pipeline(config_path, ...),
            timeout=30.0  # 仅限提交阶段超时
        )
        return success_response(result)
    except asyncio.TimeoutError:
        return error_response("Pipeline submission timed out after 30s")

# ❌ 禁止：同步函数调用 async 函数
@mcp.tool()
def run_pipeline_bad(config_path: str) -> str:
    return run_pipeline_async(config_path)  # 返回 coroutine 对象！
```


***

## 四、统一返回格式规范

### 4.1 所有 Tool 必须使用统一结构

```python
# core/response.py（每个 MCP Server 必须包含此文件）

from typing import Any, Dict, Optional

def success_response(
    data: Any = None,
    message: str = "",
    job_id: Optional[str] = None
) -> Dict:
    resp = {"status": "success", "message": message, "data": data}
    if job_id:
        resp["job_id"] = job_id
    return resp

def error_response(
    message: str,
    details: str = "",
    error_code: Optional[str] = None
) -> Dict:
    return {
        "status": "error",
        "message": message,
        "details": details,
        "error_code": error_code,
    }

def pending_response(job_id: str, message: str = "") -> Dict:
    return {
        "status": "pending",
        "job_id": job_id,
        "message": message or f"Job {job_id} submitted. Use get_pipeline_status('{job_id}') to monitor.",
    }
```


### 4.2 流程状态字段标准

```python
# 状态枚举（所有 MCP 统一）
class PipelineStatus(str, Enum):
    PENDING   = "pending"    # 已提交，排队中
    RUNNING   = "running"    # 执行中
    SUCCESS   = "success"    # 成功完成
    FAILED    = "failed"     # 执行失败
    CANCELLED = "cancelled"  # 已取消
    DRY_RUN   = "dry_run"    # dry-run 完成
```


***

## 五、Pydantic Schema 规范

### 5.1 必须定义的公共模型

```python
# models/schemas.py

from pydantic import BaseModel, Field, validator
from typing import List, Optional, Literal
from enum import Enum

class GenomeVersion(str, Enum):
    """所有流程支持的参考基因组（各 MCP 按需扩展）"""
    HG38 = "hg38"
    HG19 = "hg19"
    MM10 = "mm10"
    MM39 = "mm39"

class ExecutionMode(str, Enum):
    LOCAL   = "local"
    CLUSTER = "cluster"
    CLOUD   = "cloud"

class BaseProjectConfig(BaseModel):
    """所有组学流程配置的基类"""
    project_name: str = Field(..., description="项目名称，只允许字母数字下划线")
    genome_version: GenomeVersion
    species: str
    raw_data_path: List[str] = Field(..., description="FASTQ 文件或目录的绝对路径列表")
    output_dir: str = Field(..., description="结果输出绝对路径")
    execution_mode: ExecutionMode = ExecutionMode.LOCAL
    cores: int = Field(default=20, ge=1, le=256)

    @validator("project_name")
    def validate_project_name(cls, v):
        import re
        if not re.match(r'^[a-zA-Z0-9_\-]+$', v):
            raise ValueError("项目名称只允许字母、数字、下划线和连字符")
        return v

    @validator("raw_data_path", each_item=True)
    def validate_paths_absolute(cls, v):
        from pathlib import Path
        if not Path(v).is_absolute():
            raise ValueError(f"路径必须为绝对路径: {v}")
        return v

class RunRecord(BaseModel):
    """数据库运行记录标准结构"""
    run_id: str
    project_name: str
    status: str
    start_time: str
    end_time: Optional[str]
    config_path: str
    log_path: str
    cores: int
    error_message: Optional[str]
```


***

## 六、数据库规范

### 6.1 统一表结构

所有组学 MCP 使用 SQLite，表结构必须包含以下字段：

```sql
CREATE TABLE IF NOT EXISTS pipeline_runs (
    run_id        TEXT PRIMARY KEY,      -- UUID
    project_name  TEXT NOT NULL,
    pipeline_type TEXT NOT NULL,         -- 流程类型: rnaflow/atacflow/wgs 等
    status        TEXT NOT NULL,         -- pending/running/success/failed/cancelled
    config_path   TEXT NOT NULL,
    output_dir    TEXT,
    log_path      TEXT,
    pid           INTEGER,               -- 进程ID，用于 cancel
    cores         INTEGER DEFAULT 20,
    dry_run       INTEGER DEFAULT 0,
    start_time    TEXT,                  -- ISO 8601
    end_time      TEXT,
    duration_sec  INTEGER,
    error_message TEXT,
    metadata      TEXT                   -- JSON 字符串，存流程特有字段
);

CREATE INDEX IF NOT EXISTS idx_project_name ON pipeline_runs(project_name);
CREATE INDEX IF NOT EXISTS idx_status ON pipeline_runs(status);
CREATE INDEX IF NOT EXISTS idx_start_time ON pipeline_runs(start_time);
```


### 6.2 懒加载规范

```python
# db/session.py
from threading import Lock

_db_path = None
_lock = Lock()

def get_db_path() -> str:
    global _db_path
    if _db_path is None:
        with _lock:
            if _db_path is None:  # double-check
                from db.database import init_database
                _db_path = init_database()
    return _db_path
```


***

## 七、Resource 与 Prompt 规范

### 7.1 必须提供的 Resource

```python
# 每个 MCP Server 至少提供以下 3 个 resource：

@mcp.resource("{flow}://config-templates/standard")
async def get_standard_template() -> str:
    """标准分析配置模板"""

@mcp.resource("{flow}://config-templates/minimal")  
async def get_minimal_template() -> str:
    """最简配置模板（快速上手）"""

@mcp.resource("{flow}://skills/guide")
async def get_skill_guide() -> str:
    """AI 使用本 MCP 的操作指南"""
```


### 7.2 Resource 必须有缓存

```python
import functools
from pathlib import Path

@functools.lru_cache(maxsize=16)
def _read_template_cached(path: str) -> str:
    try:
        return Path(path).read_text(encoding="utf-8")
    except FileNotFoundError:
        return f"# Template not found: {path}"
    except Exception as e:
        return f"# Error reading template: {e}"
```


### 7.3 必须提供的 Prompt

```python
# 每个 MCP 必须提供以下 3 个标准 prompt：

@mcp.prompt()
def new_project_wizard(...) -> str:
    """引导 AI 一步步帮用户创建新项目"""

@mcp.prompt()  
def troubleshoot_failure(log_path: str) -> str:
    """引导 AI 诊断流程失败原因"""

@mcp.prompt()
def interpret_results(job_id: str) -> str:
    """引导 AI 解读分析结果，生成报告摘要"""
```


***

## 八、SKILL.md 规范

每个 MCP 的 `skills/SKILL.md` 必须包含以下章节：

```markdown
# {FlowName} MCP 使用指南

## 适用场景
[一句话描述：什么情况下用这个 MCP]

## 标准分析流程
[完整的 tool 调用顺序，用 mermaid 流程图表示]

## Tool 速查表
| Tool | 用途 | 关键参数 | 返回值 |
|------|------|---------|--------|

## 常见错误处理
| 错误信息 | 原因 | 解决方法 |
|---------|------|---------|

## 与其他 MCP 的协作
[说明本 MCP 的上游/下游 MCP 是什么]

## 参数推荐值
[各物种/数据类型的推荐 cores / 内存等]
```


***

## 九、各组学流程专属扩展字段

### 9.1 RNA-seq MCP（RNAFlow）

```python
class RNAseqProjectConfig(BaseProjectConfig):
    sample_csv: str                    # samples.csv 绝对路径
    contrasts_csv: str                 # contrasts.csv 绝对路径
    library_type: Literal[
        "fr-firststrand",
        "fr-secondstrand", 
        "unstranded"
    ] = "fr-firststrand"
    only_qc: bool = False
    deg: bool = True                   # 差异表达分析
    rmats: bool = False                # 可变剪接分析
    call_variant: bool = False         # SNP calling
    detect_novel_transcripts: bool = False
    fastq_screen: bool = True

# 专属额外 tool（在通用12个之外）：
create_sample_csv(sample_data, output_path)
create_contrasts_csv(contrasts, output_path)
get_deg_summary(job_id)               # 差异基因数量摘要

#### 样本识别与命名规范 (Mandatory)
1. **智能去噪**：扫描时必须剔除 `_R1/_R2`、`_raw`、`.RAW` 等下机干扰后缀。
2. **ID 缩写提取**：提取具有表达性的 ID 缩写作为 `sample_name`。
   - *示例*：`L1MLA1700058-PI_L18_1` -> `PI_L18_1`。
3. **Group 逻辑**：
   - **QC 模式**：`group` 默认等于 `sample_name`。
   - **配对分析**：必须遵循实验设计的 group 名称；若无特别指定，则使用 `sample_name`。

#### 核心配置手动确认 SOP
1. **生成预览**：生成 `config.yaml`, `samples.csv`, `contrasts.csv` 后展示预览。
2. **停顿询问**：明确告知用户“核心配置已就绪，请手动确认无误后调用 run_pipeline”。
3. **禁止越权**：未经用户明确回复“确认”前，禁止自动提交任务。
```


### 9.2 ATAC-seq MCP（ATACFlow）

```python
class ATACseqProjectConfig(BaseProjectConfig):
    sample_csv: str
    peak_caller: Literal["macs2", "macs3", "hmmratac"] = "macs2"
    genome_size: Optional[str] = None  # macs2 -g 参数
    blacklist_regions: Optional[str] = None
    only_qc: bool = False
    call_peaks: bool = True
    motif_analysis: bool = False
    ataqv: bool = True                 # QC 质量评估

# 专属额外 tool：
get_tss_enrichment(job_id)            # TSS 富集分数
get_frip_scores(job_id)               # FRiP 分数摘要
```


### 9.3 WGS/WES MCP

```python
class WGSProjectConfig(BaseProjectConfig):
    sample_csv: str
    sequencing_type: Literal["wgs", "wes"] = "wgs"
    capture_bed: Optional[str] = None  # WES 必填
    ploidy: int = 2
    call_snv: bool = True
    call_indel: bool = True
    call_cnv: bool = False
    call_sv: bool = False
    variant_caller: Literal["gatk", "deepvariant", "strelka2"] = "gatk"

# 专属额外 tool：
get_variant_summary(job_id)           # 变异统计摘要
get_coverage_stats(job_id)            # 覆盖度统计
```


### 9.4 ChIP-seq MCP

```python
class ChIPseqProjectConfig(BaseProjectConfig):
    sample_csv: str                    # 必须包含 input/control 列
    peak_type: Literal["narrow", "broad"] = "narrow"
    peak_caller: Literal["macs2", "sicer2"] = "macs2"
    idr_analysis: bool = True          # IDR 重复一致性分析
    motif_analysis: bool = False
    genome_size: Optional[str] = None

# 专属额外 tool：
get_idr_results(job_id)
get_peak_stats(job_id)
```


### 9.5 单细胞 RNA-seq MCP

```python
class scRNAseqProjectConfig(BaseProjectConfig):
    chemistry: Literal["10x_v2", "10x_v3", "10x_v3.1"] = "10x_v3"
    expected_cells: int = 5000
    aligner: Literal["cellranger", "starsolo", "alevin"] = "starsolo"
    clustering: bool = True
    cell_type_annotation: bool = False

# 专属额外 tool：
get_cell_stats(job_id)                # 细胞数/基因数/UMI 统计
get_clustering_summary(job_id)        # 聚类结果摘要
```


***

## 十、测试规范

### 10.1 每个 MCP 必须包含以下测试

```python
# tests/test_tools.py 必须覆盖：

class TestSetupTools:
    def test_list_supported_genomes_returns_list(self)
    def test_get_config_template_standard(self)
    def test_get_config_template_minimal(self)
    def test_validate_config_valid_file(self)
    def test_validate_config_missing_field(self)
    def test_validate_config_invalid_path(self)

class TestExecutionTools:
    async def test_dry_run_returns_immediately(self)
    async def test_run_pipeline_returns_job_id(self)
    async def test_run_pipeline_requires_user_confirmed(self)
    async def test_run_pipeline_submission_timeout(self)

class TestMonitorTools:
    async def test_get_status_unknown_job_id(self)
    async def test_get_log_returns_string(self)
    def test_list_runs_empty(self)
    def test_list_runs_with_filter(self)

class TestResponseFormat:
    def test_all_tools_return_status_field(self)   # 统一格式检查
    def test_error_response_has_message(self)
```


### 10.2 集成测试用小数据集

```
tests/fixtures/
├── tiny_fastq/           # 1000 reads 的测试 FASTQ
├── config_valid.yaml     # 合法配置
├── config_missing_field.yaml
├── config_invalid_path.yaml
└── samples_valid.csv
```


***

## 十一、部署配置规范

### 11.1 `pyproject.toml` 必填字段

```toml
[project]
name = "{flow-name}-mcp"
version = "0.1.0"
requires-python = ">=3.10"

dependencies = [
    "fastmcp>=2.0",
    "pydantic>=2.0",
    "aiosqlite>=0.19",
]

[project.scripts]
"{flow-name}-mcp" = "server:mcp.run"

[tool.fastmcp]
transport = "stdio"           # 默认 stdio，生产环境改 http
log_level = "INFO"
```


### 11.2 Claude Desktop 集成配置模板

```json
{
  "mcpServers": {
    "rnaflow": {
      "command": "uv",
      "args": ["run", "--directory", "/path/to/rnaflow_mcp", "rnaflow-mcp"],
      "env": {
        "RNAFLOW_ROOT": "/path/to/rnaflow",
        "CONDA_PATH": "/opt/miniconda3/bin/conda"
      }
    },
    "atacflow": {
      "command": "uv",
      "args": ["run", "--directory", "/path/to/atacflow_mcp", "atacflow-mcp"],
      "env": {
        "ATACFLOW_ROOT": "/path/to/atacflow"
      }
    }
  }
}
```


***

## 十二、各流程开发 Checklist

AI 按此框架实现时，每个流程完成后需逐项确认：

```
架构
  ☐ 目录结构符合第二节规范
  ☐ server.py 只做注册，无业务逻辑
  ☐ 模块顶层无任何 I/O 操作

Tool 设计
  ☐ 总 tool 数 ≤ 20
  ☐ 12 个核心 tool 全部实现
  ☐ 所有 I/O tool 为 async def
  ☐ 所有 tool 有完整 docstring
  ☐ 向后兼容用 legacy_dispatcher 处理

返回格式
  ☐ 所有 tool 返回含 status 字段
  ☐ 使用 core/response.py 的工具函数
  ☐ 流程状态使用 PipelineStatus 枚举

Schema
  ☐ 继承 BaseProjectConfig
  ☐ 路径字段有绝对路径校验
  ☐ 项目名称有格式校验

数据库
  ☐ 使用统一表结构
  ☐ 懒加载实现
  ☐ 包含 cancel/pid 字段

文档
  ☐ skills/SKILL.md 包含全部必要章节
  ☐ 提供 3 个标准 prompt
  ☐ examples/ 有可用配置模板

测试
  ☐ 覆盖全部 4 类测试
  ☐ 有 fixtures 小数据集
  ☐ 通过统一返回格式检查
```
