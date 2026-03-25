#!/usr/bin/env python3
"""
测试 MCP 服务器是否能正常启动并列出工具
"""

import sys
from pathlib import Path

# Add mcp directory to path
sys.path.insert(0, str(Path(__file__).parent))

try:
    from server import mcp

    print("✅ MCP 服务器导入成功！")
    print()

    # List all registered tools
    print("📋 注册的工具列表:")
    print("-" * 60)

    # Try to access tools from the mcp object
    # FastMCP stores tools in _tools or similar attribute
    if hasattr(mcp, "_tools"):
        for tool_name, tool in mcp._tools.items():
            print(f"  - {tool_name}")
    elif hasattr(mcp, "tools"):
        for tool in mcp.tools:
            if hasattr(tool, "name"):
                print(f"  - {tool.name}")
    else:
        print("  (无法直接列出工具，请启动服务器查看)")

    print("-" * 60)
    print()
    print("🚀 现在可以重启 MCP 服务器进行测试了！")
    print()
    print("使用以下命令启动:")
    print("  cd /home/zj/pipeline/RNAFlow/mcp")
    print("  uv run python server.py")
    print()
    print("或者使用便捷脚本:")
    print("  ./start.sh local")

except Exception as e:
    print(f"❌ 错误: {e}")
    import traceback

    traceback.print_exc()
    sys.exit(1)
