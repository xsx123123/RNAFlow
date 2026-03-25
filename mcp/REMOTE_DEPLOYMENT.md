# RNAFlow MCP 远程部署指南

本指南说明如何将 RNAFlow MCP 服务从本地 stdio 模式转换为远程部署模式。

## 部署方式概览

### 方式一：SSH 端口转发（最简单，推荐用于快速测试）

### 方式二：使用 MCP SSE 传输层（标准方式）

### 方式三：使用 Nginx 反向代理 + systemd 服务（生产环境推荐）

---

## 方式一：SSH 端口转发（快速方案）

### 服务端操作
```bash
# 1. 启动本地 MCP 服务
cd /home/zj/pipeline/RNAFlow/mcp
uv run python server.py

# 2. 或者使用 nohup 在后台运行
nohup uv run python server.py > mcp_server.log 2>&1 &
```

### 客户端操作（本地机器）
```bash
# 通过 SSH 隧道转发
ssh -L 9999:localhost:9999 user@your-server-ip
```

### Claude Desktop 配置
```json
{
  "mcpServers": {
    "rnaflow": {
      "command": "ssh",
      "args": [
        "user@your-server-ip",
        "cd", "/home/zj/pipeline/RNAFlow/mcp", "&&",
        "uv", "run", "python", "server.py"
      ]
    }
  }
}
```

---

## 方式二：使用 MCP SSE 传输层（标准方式）

### 1. 安装额外依赖
```bash
cd /home/zj/pipeline/RNAFlow/mcp
uv add "mcp[cli]" uvicorn
```

### 2. 创建 SSE 服务器启动脚本
创建 `sse_server.py`（见同目录下的文件）

### 3. 启动 SSE 服务
```bash
uv run python sse_server.py
```

服务将监听在 `http://0.0.0.0:8000/sse`

### 4. 客户端配置
Claude Desktop 配置：
```json
{
  "mcpServers": {
    "rnaflow": {
      "transport": "sse",
      "url": "http://your-server-ip:8000/sse"
    }
  }
}
```

---

## 方式三：生产环境部署（Nginx + systemd）

### Step 1: 创建 systemd 服务文件
创建 `/etc/systemd/system/rnaflow-mcp.service`：
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

### Step 2: 启动服务
```bash
sudo systemctl daemon-reload
sudo systemctl enable rnaflow-mcp
sudo systemctl start rnaflow-mcp
sudo systemctl status rnaflow-mcp
```

### Step 3: 配置 Nginx 反向代理
创建 `/etc/nginx/sites-available/rnaflow-mcp`：
```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location /mcp/ {
        proxy_pass http://localhost:8000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # SSE 相关配置
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 86400;
    }
}
```

启用配置：
```bash
sudo ln -s /etc/nginx/sites-available/rnaflow-mcp /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## 安全建议

1. **使用 HTTPS**: 配置 Let's Encrypt SSL 证书
2. **防火墙限制**: 使用 ufw/iptables 限制访问 IP
3. **认证机制**: 考虑添加 API Key 或 OAuth2 认证
4. **日志监控**: 定期检查服务日志
