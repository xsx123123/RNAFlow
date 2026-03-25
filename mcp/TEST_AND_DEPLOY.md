# RNAFlow MCP 测试与部署指南

## 🚀 快速开始（推荐先测试本地模式）

### 1. 环境准备

```bash
cd /home/zj/pipeline/RNAFlow/mcp

# 安装依赖（如果还没安装）
uv sync
```

### 2. 本地模式测试（默认）

#### 方式 A：使用 MCP Inspector 测试（推荐）
```bash
# 需要先安装 Node.js
npx @modelcontextprotocol/inspector uv --directory /home/zj/pipeline/RNAFlow/mcp run server.py
```

#### 方式 B：直接运行测试
```bash
# 测试基本运行
uv run python server.py
```

---

## 🌐 远程部署方案

### 方案一：SSH 隧道方式（最简单，无需改代码）

#### 服务端（远程服务器）：
```bash
# 直接保持原有代码，不需要修改
# 确认服务能正常运行即可
```

#### 客户端（本地机器）的 Claude Desktop 配置：
编辑 `claude_desktop_config.json`：
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

---

### 方案二：创建独立的 SSE 服务器

我为你创建了一个简化方案：保持原有的 `server.py` 作为本地版本，另外创建一个 `sse_server.py` 用于远程部署。

#### Step 1: 更新配置文件
编辑 `mcp_config.yaml`，添加远程服务配置：
```yaml
conda_path: "micromamba"
snakemake_path: "/home/zj/.local/share/mamba/envs/snakemake9/bin/snakemake"
default_env: "snakemake9"
# 新增远程服务配置
host: "0.0.0.0"
port: 8000
```

#### Step 2: 安装额外依赖
```bash
uv add uvicorn starlette
```

#### Step 3: 创建 systemd 服务（生产环境）
创建 `/etc/systemd/system/rnaflow-mcp.service`（需要 sudo）：
```ini
[Unit]
Description=RNAFlow MCP Server
After=network.target

[Service]
Type=simple
User=zj
WorkingDirectory=/home/zj/pipeline/RNAFlow/mcp
Environment="PATH=/home/zj/.local/bin:/usr/bin:/bin"
ExecStart=/home/zj/.local/bin/uv run python sse_server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

#### Step 4: 启动服务
```bash
sudo systemctl daemon-reload
sudo systemctl enable rnaflow-mcp
sudo systemctl start rnaflow-mcp
sudo systemctl status rnaflow-mcp
```

---

## 📋 验证清单

- [ ] 本地模式能正常运行
- [ ] `uv sync` 成功安装所有依赖
- [ ] MCP Inspector 能连接并列出工具
- [ ] 测试 `list_supported_genomes` 工具返回正确结果
- [ ] （如使用远程）SSH 隧道能正常连接

## 🔧 故障排查

### 问题：uv 命令找不到
```bash
# 确认 uv 安装位置
which uv
# 或重新安装
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### 问题：依赖安装失败
```bash
rm -rf .venv uv.lock
uv sync
```
