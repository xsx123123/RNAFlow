# RNAFlow MCP Server

这是一个基于 [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) 构建的服务端，使用 **[uv](https://docs.astral.sh/uv/)** 进行现代化的环境管理。

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

## 🚀 快速开始

### 前置要求
- Python 3.13+
- **uv (包管理器) - 必须先在服务器上安装**
- conda/mamba (用于运行 Snakemake)
- Node.js (可选，用于 MCP Inspector 测试)

### 1. 安装 uv (如果服务器未安装)
**重要**：uv 必须在运行 MCP 服务器的机器上安装。如果使用远程部署，请确保在远程服务器上安装 uv。

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### 验证 uv 安装
安装完成后，验证 uv 是否可用：
```bash
which uv
uv --version
```

如果 uv 安装在 pyenv 等环境管理工具中，请记录其绝对路径（例如：`/home/zj/.pyenv/shims/uv`），在 SSH 配置时需要使用。

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
npx @modelcontextprotocol/inspector uv --directory mcp run server.py
```

---

## 🤖 在 AI 客户端中使用

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
        "server.py"
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
        "uv", "run", "python", "server.py"
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
        "-p", "4567",
        "zj@your-server-ip",
        "cd", "/home/zj/pipeline/RNAFlow/mcp", "&&",
        "uv", "run", "python", "server.py"
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
        "/home/zj/.pyenv/versions/prefect/bin/uv", "run", "python", "server.py"
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
        "uv", "run", "python", "server.py"
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
| `server.py` | MCP 服务器核心代码 |
| `start.sh` | 便捷启动脚本 |
| `mcp_config.yaml` | 服务配置文件（路径、网络等） |
| `pyproject.toml` | uv 项目配置（依赖定义） |
| `uv.lock` | 依赖锁定文件，确保环境可复现 |
| `data/rnaflow_runs.db` | SQLite 数据库，存储项目运行记录 |
| `logs/mcp/` | MCP 服务器运行日志目录 |
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
