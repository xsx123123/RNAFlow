# RNAFlow MCP Server (v0.2.0 Optimized)

这是一个基于 [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) 构建的高性能组学分析服务端，专门为 RNA-seq 分析流程设计。本项目通过 **[uv](https://docs.astral.sh/uv/)** 进行环境管理，采用模块化分层架构，支持本地 Stdio 和远程部署模式。

---

## 🏗️ 核心架构

本项目遵循“轻量级接口层”设计原则，将分析逻辑与 AI 交互层分离：

- **入口层 (`main.py`)**: 负责 FastMCP 初始化与工具/资源注册。
- **基础层 (`core/`)**: 日志系统、路径配置、性能追踪及向后兼容分发器。
- **业务层 (`services/`)**: 项目管理、Snakemake 调度、系统资源监控逻辑。
- **数据层 (`models/`, `db/`)**: Pydantic 配置校验模型与基于 SQLite 的异步任务追踪。

---

## 🌟 关键优化 (v0.2.0)

- **工具集精简**: 工具数量从 40+ 整合至 23 个，显著降低 LLM 上下文压力。
- **异步安全**: 所有 I/O 密集型操作（文件读写、系统调用）均在 `executor` 中运行，不阻塞事件循环。
- **懒加载机制**: 数据库和配置信息采用懒加载模式，服务器启动近乎瞬时。
- **向后兼容**: 完整保留旧版 CamelCase 别名和旧格式配置文件支持。
- **任务监控**: 后台运行 Snakemake，支持通过 `run_id` 实时追踪日志与状态。

---

## 🚀 部署指南

### 1. 环境准备
- **Python**: 3.13+
- **uv**: 推荐使用的包管理器
- **Conda/Mamba**: 必须安装，用于运行 Snakemake 流程环境

```bash
cd /home/zj/pipeline/RNAFlow/mcp
uv sync  # 安装所有依赖
```

### 2. 核心配置 (`mcp_config.yaml`)
部署前请根据服务器环境修改以下路径：
```yaml
conda_path: "/path/to/conda"      # Conda 二进制文件路径
snakemake_path: "/path/to/snakemake" # Snakemake 路径
default_env: "snakemake"          # 默认运行环境
```

### 3. 客户端集成 (Claude Desktop)

#### 方案 A：本地使用
如果 AI 客户端与 MCP 在同一台机器：
```json
{
  "mcpServers": {
    "rnaflow": {
      "command": "uv",
      "args": ["--directory", "/home/zj/pipeline/RNAFlow/mcp", "run", "main.py"]
    }
  }
}
```

#### 方案 B：远程部署 (SSH 隧道 - 推荐)
这是最安全且最简单的远程连接方式，无需在服务器暴露端口：
```json
{
  "mcpServers": {
    "rnaflow": {
      "command": "ssh",
      "args": [
        "-p", "22",
        "zj@your-server-ip",
        "cd /home/zj/pipeline/RNAFlow/mcp && /home/zj/.local/bin/uv run python main.py"
      ]
    }
  }
}
```

---

## 🛠️ 工具速查表

| 类别 | 工具名称 (蛇形命名) | 功能说明 |
| :--- | :--- | :--- |
| **Setup** | `setup_complete_project` | 一键初始化目录、配置、样本表 |
| | `list_supported_genomes` | 列出系统支持的参考基因组 |
| | `validate_config` | 验证 config.yaml 合法性 |
| **Exec** | `run_rnaflow` | **异步提交流程**，返回 `job_id` |
| | `run_simple_qc_analysis` | 快速启动 QC 模式设置 |
| **Monitor**| `check_snakemake_status` | 检查任务进度及最近日志 |
| | `get_snakemake_log` | 获取指定任务的详细日志 |
| | `list_runs` | 查询历史运行记录 |
| **System** | `check_system_resources` | CPU/内存/磁盘 实时状态监控 |
| | `check_conda_environment` | 校验 Snakemake 运行环境 |

---

## 💡 使用流程示例

1.  **查询基因组**: 调用 `list_supported_genomes` 确认可用版本。
2.  **环境检查**: 调用 `check_conda_environment` 确保分析环境就绪。
3.  **初始化项目**: 调用 `setup_complete_project` 创建工作区。
4.  **放置数据**: 将 FASTQ 文件放入 `00.raw_data/`。
5.  **提交流程**: 调用 `run_rnaflow(config_path="...", dry_run=True)` 进行演练。
6.  **正式运行**: 设置 `user_confirmed=True` 正式启动后台分析。
7.  **状态监控**: 使用 `check_snakemake_status` 查看进度。

---

## 📂 目录结构
```text
mcp/
├── main.py           # FastMCP 入口
├── mcp_config.yaml   # 服务路径配置
├── core/             # 核心组件 (日志、分发、响应)
├── models/           # Pydantic 数据模型
├── services/         # 业务逻辑 (项目、流程、系统)
├── db/               # 数据库会话与 CRUD
├── skills/           # AI 提示词与技能文档
├── data/             # SQLite 数据库文件
└── logs/mcp/         # 服务器运行日志
```

---

## 📝 维护与日志
- **服务器日志**: `/home/zj/pipeline/RNAFlow/mcp/logs/mcp/`
- **任务日志**: 每个项目的 `01.workflow/rnaflow_run.log`
- **数据库**: `/home/zj/pipeline/RNAFlow/mcp/data/rnaflow_runs.db`

---
**RNAFlow MCP** - *让组学分析触手可及* 🚀