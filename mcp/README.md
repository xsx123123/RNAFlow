# RNAFlow MCP Server

这是一个基于 [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) 构建的服务端，使用 **[uv](https://docs.astral.sh/uv/)** 进行现代化的环境管理。

---

## ⚠️ 重要：部署前必须配置

**在部署到新服务器前，请务必修改以下配置文件中的参数：**

### 1. 核心配置文件：`mcp_config.yaml`
```yaml
# Conda 的二进制文件路径（根据新服务器环境修改）
conda_path: "conda"  # "conda" 或绝对路径如 "/home/user/miniconda3/bin/conda"

# Snakemake 的二进制文件路径（根据新服务器环境修改）
snakemake_path: "snakemake"  # 或绝对路径如 "/home/user/miniconda3/envs/rnaflow/bin/snakemake"

# 默认激活的 conda 环境名称
default_env: "snakemake9"  # 修改为你的环境名称
```

### 2. 客户端配置：Claude Desktop 的 `claude_desktop_config.json`
- SSH 用户和服务器 IP
- 项目路径
- uv 的绝对路径（如需要）

### 3. 检查清单
- [ ] 确认 conda/mamba 已正确安装
- [ ] 确认 snakemake 环境已创建
- [ ] 确认 `mcp_config.yaml` 中的路径配置正确
- [ ] 运行 `uv sync` 安装依赖
- [ ] 测试本地运行：`uv run python main.py`

---

## 🌟 功能特性

- **基因组查询**：列出系统支持的参考基因组（从 `config/reference.yaml` 的 `mcp_genome_version` 读取）。
- **配置生成**：自动化生成 `config.yaml`, `samples.csv`, `contrasts.csv`。
- **系统资源监控**：实时检查 CPU、内存、磁盘使用情况，任务提交前预警。
- **项目运行管理**：使用 SQLite 数据库记录每次运行信息，支持查询和统计。
- **项目冲突检测**：启动任务前检查项目名称冲突，避免重复。
- **异步运行**：后台启动 Snakemake，不阻塞 AI。
- **详细日志**：所有操作记录到 `logs/mcp/` 目录，含时间戳和详细运行信息。
- **环境隔离**：使用 `uv` 确保依赖库与分析环境互不干扰。
- **双模式支持**：本地 stdio 模式 + 远程部署能力。

---

## 🏗️ 架构设计与文件结构

本项目采用**模块化分层架构**，便于维护和扩展。如果你要创建类似的 MCP（如 ATAC-seq、ChIP-seq 等），可以直接参考此结构！

### 整体架构图

```
┌─────────────────────────────────────────────────────────────┐
│                     main.py (入口层)                      │
│  - FastMCP 实例初始化                                       │
│  - 工具/资源/提示词注册                                      │
│  - 向后兼容工具别名                                         │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────┼───────────┐
         │           │           │
         ▼           ▼           ▼
    ┌─────────┐  ┌────────┐  ┌─────────┐
    │  core/  │  │models/ │  │   db/   │
    │ (基础层) │  │(数据层)│  │(数据层) │
    └─────────┘  └────────┘  └─────────┘
         │           │           │
         └───────────┼───────────┘
                     │
                     ▼
              ┌──────────────┐
              │  services/   │
              │  (业务层)    │
              └──────────────┘
```

### 目录结构详解

```
mcp/
├── main.py                 # ⭐ 核心入口（只负责 FastMCP 初始化和工具注册）
│                           #    参考要点：保持简洁，不包含业务逻辑
│
├── core/                   # 📦 核心基础模块（所有 MCP 通用）
│   ├── __init__.py
│   ├── config.py           # 路径定义、配置加载 (MCP_PATHS, load_mcp_config)
│   │                       #    参考要点：集中管理所有路径和配置
│   └── logger.py           # 日志配置 (setup_logging)
│                           #    参考要点：统一的日志格式和输出位置
│
├── models/                 # 📊 数据模型层（Pydantic 模型）
│   ├── __init__.py
│   └── schemas.py          # Pydantic 数据模型 (ProjectConfig)
│                           #    参考要点：
│                           #      - 定义完整的配置结构
│                           #      - 添加字段验证（如基因组版本枚举）
│                           #      - 支持动态加载验证规则（从配置文件）
│
├── db/                     # 🗄️ 数据库层
│   ├── __init__.py
│   ├── database.py         # 数据库连接和初始化 (init_database, get_db_connection)
│   │                       #    参考要点：
│   │                       #      - 统一的数据库连接管理
│   │                       #      - 自动创建表结构
│   └── crud.py             # 纯粹的数据库增删改查
│                           #    参考要点：
│                           #      - 只做数据操作，不包含业务逻辑
│                           #      - 每个函数只做一件事
│
├── services/               # 🛠️ 业务逻辑层（核心功能实现）
│   ├── __init__.py
│   │
│   ├── project_mgr.py      # 项目管理服务
│   │                       #    功能：
│   │                       #      - 创建项目结构
│   │                       #      - 生成配置文件 (config.yaml)
│   │                       #      - 生成 CSV 文件 (samples.csv, contrasts.csv)
│   │                       #      - 配置验证
│   │                       #    参考要点：按功能域划分服务
│   │
│   ├── snakemake.py        # Snakemake 执行服务
│   │                       #    功能：
│   │                       #      - 命令拼接
│   │                       #      - Dry Run 逻辑
│   │                       #      - 异步/后台进程管理
│   │                       #    参考要点：
│   │                       #      - 分离 dry_run 和实际运行
│   │                       #      - 使用后台进程避免阻塞
│   │
│   └── system.py           # 系统服务
│                           #    功能：
│                           #      - 环境检查 (Conda)
│                           #      - 系统资源监控 (CPU/内存/磁盘)
│                           #      - 运行记录查询
│                           #    参考要点：
│                           #      - 封装系统调用
│                           #      - 提供友好的错误提示
│
├── docs/                   # 📚 旧文件备份（归档用）
│   ├── USAGE_EXAMPLES.md
│   ├── TEST_AND_DEPLOY.md
│   └── ...
│
├── skills/                 # 🎯 MCP Skills（AI 提示词模板）
├── test/                   # 🧪 测试文件
├── data/                   # 💾 数据库文件存放
├── logs/                   # 📝 日志文件存放
│
├── README.md               # 📖 本文档
├── start.sh                # 🚀 便捷启动脚本
├── mcp_config.yaml         # ⚙️ MCP 服务配置
├── pyproject.toml          # 📦 uv 项目配置
└── uv.lock                 # 🔒 依赖锁定文件
```

### 各模块职责说明

| 模块 | 职责 | 可复用性 |
|------|------|---------|
| `core/config.py` | 路径管理、配置加载 | ⭐⭐⭐⭐⭐ 完全通用 |
| `core/logger.py` | 日志系统配置 | ⭐⭐⭐⭐⭐ 完全通用 |
| `models/schemas.py` | 数据模型定义 | ⭐⭐⭐⭐ 需根据分析类型修改 |
| `db/database.py` | 数据库初始化 | ⭐⭐⭐⭐⭐ 完全通用 |
| `db/crud.py` | 数据库操作 | ⭐⭐⭐⭐ 基本通用，表结构可能调整 |
| `services/project_mgr.py` | 项目结构、配置生成 | ⭐⭐⭐ 需根据分析类型修改 |
| `services/snakemake.py` | Snakemake 执行 | ⭐⭐⭐⭐ 基本通用 |
| `services/system.py` | 系统检查、运行查询 | ⭐⭐⭐⭐⭐ 完全通用 |
| `main.py` | 工具注册、入口 | ⭐⭐⭐⭐ 基本通用，工具列表需调整 |

### 创建新 MCP（如 ATACFlow）的步骤

#### 1. 复制框架
```bash
# 复制整个 mcp/ 目录为新的项目
cp -r RNAFlow/mcp ATACFlow/mcp
```

#### 2. 修改核心配置
- 更新 `pyproject.toml` 中的项目名称
- 更新 `mcp_config.yaml`（如需要）
- 修改 `core/config.py` 中的路径引用（如需要）

#### 3. 定制数据模型
编辑 `models/schemas.py`：
- 修改 `ProjectConfig` 类，添加 ATAC-seq 特有的配置字段
- 调整 `Genome_Version` 验证（或保持动态加载机制）

#### 4. 修改业务逻辑
编辑 `services/project_mgr.py`：
- 修改 `setup_complete_project()` 中的默认配置
- 更新生成的配置文件模板
- 调整 CSV 文件结构（如需要）

#### 5. 更新入口
编辑 `main.py`：
- 更新 FastMCP 名称（如 `"ATACFlow"`）
- 确保所有工具都正确注册
- 更新提示词（Prompts）

#### 6. 测试验证
- 运行 `uv sync` 安装依赖
- 使用 `./start.sh test` 测试
- 验证所有工具功能正常

### 关键设计原则

1. **单一职责**：每个模块/函数只做一件事
2. **依赖倒置**：业务层依赖抽象，不依赖具体实现
3. **配置驱动**：尽可能从配置文件读取，避免硬编码
4. **向后兼容**：保留旧工具名称作为别名，避免破坏现有集成
5. **动态验证**：从 `config/reference.yaml` 动态加载支持的基因组版本

---

## 💡 使用示例

### 快速开始 - 推荐方式

#### 方式一：使用 setup_complete_project 一键设置（最简单）

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

#### 方式二：分步设置

```python
# Step 1: 创建目录结构
create_project_structure("/data/jzhang/project/Temp/rna_skills_analysis")

# Step 2: 获取配置模板
get_config_template("qc_only")

# Step 3: 生成完整配置
# (需要先创建 ProjectConfig 对象，或使用 setup_complete_project)
```

### 工具名称对照

| 新工具名 (蛇形) | 旧工具名 (驼峰) |
|-----------------|-----------------|
| `generate_config_file` | `rnaflowGenerateConfigFile` |
| `create_project_structure` | `createProjectStructure` |
| `setup_complete_project` | `setupCompleteProject` |
| `create_sample_csv` | `createSampleCsv` |
| `create_contrasts_csv` | `createContrastsCsv` |

两种命名方式都支持！

### 分析模式说明

| 模式 | 说明 |
|------|------|
| `qc_only` | 仅做质量控制（最快） |
| `standard` | 标准 DEG 分析（推荐） |
| `complete` | 完整分析（包含变异检测、可变剪接等） |

---

## 🚀 快速开始

### 前置要求
- Python 3.13+
- uv (包管理器)
- conda/mamba (用于运行 Snakemake)
- Node.js (可选，用于 MCP Inspector 测试)

### 1. 安装 uv (如果未安装)
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### 2. 安装项目依赖
```bash
cd /home/zj/pipeline/RNAFlow/mcp
uv sync
```

**可选：安装系统资源监控依赖（推荐）**
```bash
uv add psutil
# 或安装完整可选依赖
uv sync --extra full
```

### 3. 测试运行

#### 方式一：使用便捷脚本（推荐）
```bash
# 快速测试（使用 MCP Inspector）
./start.sh test

# 前台运行本地模式
./start.sh local

# 后台运行
./start.sh background
```

#### 方式二：手动使用 MCP Inspector
```bash
npx @modelcontextprotocol/inspector uv --directory mcp run main.py
```

---

## 🔌 MCP 连接方式说明

### 重要理解：MCP stdio 模式的工作原理

RNAFlow MCP 使用 **stdio 模式**（标准输入输出），这意味着：
- ❌ **不能像传统 Web 服务那样独立后台运行**
- ✅ **需要由客户端（如 Claude Desktop）直接启动进程**
- ✅ **客户端通过 stdin/stdout 与 MCP 服务器通信**

---

### start.sh 脚本使用说明

| 命令 | 用途 | 适用场景 |
|------|------|---------|
| `./start.sh local` | 前台运行本地模式 | 开发调试 |
| `./start.sh test` | 启动 MCP Inspector 测试 | 功能测试 |
| `./start.sh background` | 后台运行（不推荐用于 stdio 模式） | - |

⚠️ **注意**：`./start.sh background` 对于 stdio 模式没有实际意义，因为 MCP 需要客户端主动连接。

---

## 🤖 在 AI 客户端中使用

### 实际使用方案

#### 方案一：本地使用（最简单）

如果你的 AI 客户端（如 Claude Desktop）和 RNAFlow MCP 在同一台机器上：

**配置 `claude_desktop_config.json`：**
```json
{
  "mcpServers": {
    "rnaflow": {
      "command": "uv",
      "args": [
        "--directory",
        "/home/zj/pipeline/RNAFlow/mcp",
        "run",
        "main.py"
      ]
    }
  }
}
```

**工作原理**：
- Claude Desktop 每次启动时会自动运行这个命令
- MCP 进程由 Claude Desktop 管理
- 不需要手动后台运行

---

#### 方案二：远程使用（推荐用于服务器部署）

如果 RNAFlow MCP 在远程服务器上，使用 SSH 隧道方式：

**配置 `claude_desktop_config.json`（本地机器）：**
```json
{
  "mcpServers": {
    "rnaflow": {
      "command": "ssh",
      "args": [
        "-p", "4567",
        "zj@your-server-ip",
        "cd", "/home/zj/pipeline/RNAFlow/mcp", "&&",
        "/home/zj/.pyenv/versions/prefect/bin/uv", "run", "python", "main.py"
      ]
    }
  }
}
```

**工作原理**：
- Claude Desktop 通过 SSH 连接到远程服务器
- 在远程服务器上启动 MCP 进程
- stdio 通过 SSH 隧道传输
- 每次使用时自动连接，不需要手动后台保持

**优点**：
- ✅ 安全（SSH 加密）
- ✅ 简单（不需要额外配置服务）
- ✅ 按需启动（不使用时不占用资源）

---

#### 方案三：长期保持连接（可选）

如果你希望 MCP 进程长期保持，可以使用 SSH 的 ControlMaster 功能：

**在本地 `~/.ssh/config` 中添加：**
```ssh
Host rnaflow-server
    HostName your-server-ip
    Port 4567
    User zj
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 1h
```

然后在 `claude_desktop_config.json` 中使用：
```json
{
  "mcpServers": {
    "rnaflow": {
      "command": "ssh",
      "args": [
        "rnaflow-server",
        "cd", "/home/zj/pipeline/RNAFlow/mcp", "&&",
        "uv", "run", "python", "main.py"
      ]
    }
  }
}
```

这样 SSH 连接会保持 1 小时，减少重复连接的开销。

---

### 验证连接

配置完成后，重启 Claude Desktop，你应该能在可用工具列表中看到 RNAFlow 的工具！

---

## 🚀 快速开始

### 场景一：本地使用（服务端和客户端在同一台机器）

编辑你的 `claude_desktop_config.json`：
```json
{
  "mcpServers": {
    "rnaflow": {
      "command": "uv",
      "args": [
        "--directory",
        "/home/zj/pipeline/RNAFlow/mcp",
        "run",
        "main.py"
      ]
    }
  }
}
```

### 场景二：远程部署（服务端在远程服务器，客户端在本地）

#### 方案 A：SSH 隧道方式（最简单，无需修改代码）

在你的**本地机器**上编辑 `claude_desktop_config.json`：

**基本配置（默认SSH端口22）：**
```json
{
  "mcpServers": {
    "rnaflow": {
      "command": "ssh",
      "args": [
        "zj@your-server-ip",
        "cd", "/home/zj/pipeline/RNAFlow/mcp", "&&",
        "uv", "run", "python", "main.py"
      ]
    }
  }
}
```

**自定义SSH端口配置：**
如果您的SSH服务器使用自定义端口（例如4567），需要添加 `-p` 参数：
```json
{
  "mcpServers": {
    "rnaflow": {
      "command": "ssh",
      "args": [
        "zj@your-server-ip",
        "cd", "/home/zj/pipeline/RNAFlow/mcp", "&&",
        "uv", "run", "python", "main.py"
      ]
    }
  }
}
```

**pyenv环境中的uv配置：**
如果uv安装在pyenv的特定环境中（例如prefect环境），使用绝对路径：
```json
{
  "mcpServers": {
    "rnaflow": {
      "command": "ssh",
      "args": [
        "-p", "4567",
        "zj@your-server-ip",
        "cd", "/home/zj/pipeline/RNAFlow/mcp", "&&",
        "/home/zj/.pyenv/versions/prefect/bin/uv", "run", "python", "main.py"
      ]
    }
  }
}
```

**或者在SSH命令中临时设置PATH：**
```json
{
  "mcpServers": {
    "rnaflow": {
      "command": "ssh",
      "args": [
        "-p", "4567",
        "zj@your-server-ip",
        "export PATH=\"/home/zj/.pyenv/versions/prefect/bin:$PATH\"", "&&",
        "cd", "/home/zj/pipeline/RNAFlow/mcp", "&&",
        "uv", "run", "python", "main.py"
      ]
    }
  }
}
```

**优点**：
- 不需要额外配置网络服务
- SSH 加密传输，安全
- 配置简单，即插即用

#### 方案 B：生产环境部署（systemd + Nginx）

如果需要作为长期运行的服务，请参考 `TEST_AND_DEPLOY.md` 中的完整方案，包括：
- systemd 服务配置（自动重启、日志管理）
- Nginx 反向代理配置
- 防火墙配置建议

---

## 📊 系统资源监控

### `check_system_resources` 工具
该工具用于检查服务器的CPU、内存和磁盘使用情况：

```python
# 使用示例（通过MCP调用）
check_system_resources()
```

**检查内容：**
- **CPU**：总核心数、使用率、可用核心数
- **内存**：总量、可用量、使用率
- **磁盘**：根目录和参考数据目录的使用情况

**预警阈值：**
- CPU使用率 > 80%
- 内存使用率 > 85% 或可用内存 < 4GB
- 磁盘空间 < 50GB

### `run_rnaflow` 资源检查
提交任务前自动检查系统资源，发现问题时会显示警告：

```python
# 参数说明
run_rnaflow(
    config_path="/path/to/config.yaml",
    cores=20,
    dry_run=False,
    skip_resource_check=False  # 设置为True可跳过检查
)
```

---

## 📝 日志系统

### 日志位置
所有日志文件存储在：`/home/zj/pipeline/RNAFlow/mcp/logs/mcp/`

### 日志文件命名
```
mcp_server_YYYYMMDD_HHMMSS.log
```
例如：`mcp_server_20260324_235011.log`

### 日志格式
```
2026-03-24 23:50:11 - RNAFlowMCP - INFO - === RNAFlow MCP Server 启动 ===
```
包含：**时间戳** - **日志名称** - **日志级别** - **消息内容**

### 日志级别
| 级别 | 说明 | 输出位置 |
|------|------|---------|
| DEBUG | 详细调试信息 | 仅日志文件 |
| INFO | 一般信息 | 文件 + 控制台 |
| WARNING | 警告信息 | 文件 + 控制台 |
| ERROR | 错误信息（含堆栈） | 文件 + 控制台 |

### 已记录日志的工具
- `list_supported_genomes`：调用时间、配置文件、基因组列表
- `check_system_resources`：资源状态、警告信息、详细数据
- `check_conda_environment`：环境检查过程和结果
- `run_rnaflow`：配置参数、资源检查、命令执行、进程PID

---

## 🗄️ 项目运行数据库

### 数据库概述
使用 SQLite 数据库记录所有 RNAFlow 项目运行信息，数据库文件位于：
`/home/zj/pipeline/RNAFlow/mcp/data/rnaflow_runs.db`

### 记录的信息
每次运行会自动记录以下信息：
- **运行ID**：自动生成，格式为 `项目名_YYYYMMDD_HHMMSS`
- **项目名称**：从 config.yaml 读取
- **基因组版本**：使用的参考基因组
- **物种**：分析的物种
- **配置路径**：config.yaml 的完整路径
- **配置内容**：完整的 config.yaml 内容（JSON 格式）
- **使用核心数**：运行时使用的 CPU 核心数
- **开始时间**：任务启动时间
- **状态**：running/completed/failed
- **日志文件**：流程日志文件路径
- **进程ID**：后台进程 PID

### 数据库工具

#### 1. `list_runs` - 列出运行记录
```python
# 列出最近50条记录
list_runs()

# 按项目名称筛选
list_runs(project_name="MyProject")

# 按状态筛选
list_runs(status="running")  # running/completed/failed

# 限制返回数量
list_runs(limit=20)
```

#### 2. `get_run_details` - 获取运行详情
```python
# 通过运行ID获取详细信息
get_run_details(run_id="MyProject_20260325_000015")
```

#### 3. `get_run_statistics` - 获取运行统计
```python
# 获取全部统计
get_run_statistics()

# 按日期范围统计
get_run_statistics(start_date="2026-01-01", end_date="2026-12-31")
```

#### 4. `check_project_name_conflict` - 检查项目冲突
```python
# 检查项目名称是否已存在
check_project_name_conflict(project_name="MyProject")
```

#### 5. `check_snakemake_status` - 检查Snakemake运行状态
```python
# 检查所有运行中的任务
check_snakemake_status()

# 检查特定运行ID的状态
check_snakemake_status(run_id="MyProject_20260325_000015")
```
**功能说明：**
- 检查进程是否还在运行
- 显示CPU和内存使用情况
- 自动更新数据库中的运行状态（running/completed/failed）
- 显示最近20行日志

#### 6. `get_snakemake_log` - 获取Snakemake日志
```python
# 获取默认最后50行日志
get_snakemake_log(run_id="MyProject_20260325_000015")

# 指定获取行数
get_snakemake_log(run_id="MyProject_20260325_000015", lines=100)
```

### 自动功能
- **运行记录**：每次调用 `run_rnaflow` 时自动记录到数据库
- **冲突检测**：启动任务前自动检查项目名称冲突并提示
- **运行ID生成**：自动生成唯一的运行ID，避免冲突

---

## 📂 目录结构

| 文件/目录 | 说明 |
|-----------|------|
| `main.py` | MCP 服务器核心入口（FastMCP 实例初始化、工具注册） |
| `core/` | 核心模块 |
| `core/config.py` | 路径定义、MCP_PATHS 和 load_mcp_config |
| `core/logger.py` | setup_logging 日志配置 |
| `models/` | 数据模型 |
| `models/schemas.py` | Pydantic 数据模型 (ProjectConfig) |
| `db/` | 数据库模块 |
| `db/database.py` | 数据库连接和初始化 |
| `db/crud.py` | 数据库增删改查操作 |
| `services/` | 业务逻辑服务 |
| `services/project_mgr.py` | 项目结构生成、CSV/YAML 生成逻辑 |
| `services/snakemake.py` | Snakemake 命令拼接、异步调用、Dry Run 逻辑 |
| `services/system.py` | 环境检查 (Conda)、系统资源监控 |
| `start.sh` | 便捷启动脚本 |
| `mcp_config.yaml` | 服务配置文件（路径、网络等） |
| `pyproject.toml` | uv 项目配置（依赖定义） |
| `uv.lock` | 依赖锁定文件，确保环境可复现 |
| `data/rnaflow_runs.db` | SQLite 数据库，存储项目运行记录 |
| `logs/mcp/` | MCP 服务器运行日志目录 |
| `server.py.old` | 旧版本服务器代码（已备份） |
| `TEST_AND_DEPLOY.md` | 详细的测试与部署指南 |
| `README.md` | 本文档 |

---

## ⚙️ 配置说明

编辑 `mcp_config.yaml` 可以自定义：

```yaml
# 路径配置
conda_path: "micromamba"
snakemake_path: "/path/to/snakemake"
default_env: "snakemake9"

# 远程服务配置（可选）
host: "0.0.0.0"    # 监听地址
port: 8000          # 监听端口
```

---

## 🔧 故障排查

### 问题 1：`uv` 命令找不到
```bash
# 确认 uv 安装位置
which uv

# 或重新安装
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### 问题 2：SSH连接时提示 `uv: command not found`
当使用SSH远程连接时，可能因为环境变量未加载导致找不到uv。

**解决方案A：使用uv的绝对路径**
```bash
# 先找到uv的完整路径
find /home/zj/.pyenv -name uv -type f -executable

# 例如：/home/zj/.pyenv/versions/prefect/bin/uv
```

**解决方案B：在SSH命令中设置PATH**
在SSH命令开头添加PATH设置，或在 `~/.bashrc` 中永久添加：
```bash
echo 'export PATH="/home/zj/.pyenv/versions/prefect/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 问题 3：测试SSH连接
在配置MCP前，先手动测试SSH连接是否正常：
```bash
# 测试基本连接
ssh -p 4567 zj@your-server-ip "echo '连接成功'"

# 测试uv是否可用
ssh -p 4567 zj@your-server-ip "/home/zj/.pyenv/versions/prefect/bin/uv --version"
```

### 问题 2：依赖安装失败
```bash
cd /home/zj/pipeline/RNAFlow/mcp
rm -rf .venv uv.lock
uv sync
```

### 问题 3：测试时工具不显示
- 确认 `uv sync` 成功完成
- 检查 Python 版本是否 >= 3.13
- 查看 MCP Inspector 的日志输出

### 问题 4：查看服务器运行日志
```bash
# 查看最新的日志文件
cd /home/zj/pipeline/RNAFlow/mcp/logs/mcp/

# 查看最新日志的最后100行
ls -lt /home/zj/pipeline/RNAFlow/mcp/logs/mcp/ | head -2
tail -n 100 /home/zj/pipeline/RNAFlow/mcp/logs/mcp/<最新的日志文件名>

# 实时跟踪日志
tail -f /home/zj/pipeline/RNAFlow/mcp/logs/mcp/<最新的日志文件名>
```

### 问题 5：系统资源监控不工作
确保已安装 `psutil` 依赖：
```bash
cd /home/zj/pipeline/RNAFlow/mcp
uv add psutil
```

---

## ⚠️ 注意事项

- **项目命名**：本项目在 `pyproject.toml` 中命名为 `rnaflow-mcp`，避免与官方 `mcp` 库冲突。
- **环境要求**：运行 Snakemake 仍需系统路径中有 `conda` 或 `mamba`。
- **远程部署**：生产环境建议使用 SSH 隧道或 systemd + Nginx 方案，详见 `TEST_AND_DEPLOY.md`。

---

## 📚 更多信息

- [Model Context Protocol 官方文档](https://modelcontextprotocol.io/)
- [fastmcp 项目](https://github.com/jlowin/fastmcp)
- [uv 包管理器](https://docs.astral.sh/uv/)
