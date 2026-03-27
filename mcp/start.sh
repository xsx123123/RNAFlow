#!/bin/bash
# RNAFlow MCP 启动脚本
# 使用方法:
#   ./start.sh local      - 启动本地 stdio 模式（默认）
#   ./start.sh test       - 使用 MCP Inspector 测试
#   ./start.sh background - 在后台运行本地模式

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

case "${1:-local}" in
    local)
        echo "🚀 启动 RNAFlow MCP 本地模式..."
        echo "RNAFlow Root: $(dirname "$SCRIPT_DIR")"
        uv run python main.py
        ;;
    
    test)
        echo "🧪 启动 MCP Inspector 测试..."
        if ! command -v npx &> /dev/null; then
            echo "错误: 需要安装 Node.js 和 npm"
            echo "请先安装: https://nodejs.org/"
            exit 1
        fi
        npx @modelcontextprotocol/inspector uv --directory "$SCRIPT_DIR" run main.py
        ;;
    
    background)
        echo "📦 在后台启动 RNAFlow MCP..."
        LOG_FILE="$SCRIPT_DIR/mcp_server.log"
        nohup uv run python main.py > "$LOG_FILE" 2>&1 &
        PID=$!
        echo "服务已启动 (PID: $PID)"
        echo "日志文件: $LOG_FILE"
        echo "停止命令: kill $PID"
        ;;
    
    *)
        echo "用法: $0 {local|test|background}"
        echo ""
        echo "命令说明:"
        echo "  local      - 前台运行本地模式（默认）"
        echo "  test       - 使用 MCP Inspector 测试"
        echo "  background - 后台运行本地模式"
        exit 1
        ;;
esac
