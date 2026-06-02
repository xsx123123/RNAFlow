import sys
from pathlib import Path

# 将上级目录加入路径
sys.path.insert(0, str(Path(__file__).parent))

# 直接测试底层服务函数，避免 FastMCP 封装带来的复杂度
from services.system import check_conda_environment, list_supported_genomes
from core.config import MCP_PATHS


def test_mcp_logic():
    print("=== 开始 RNAFlow MCP 逻辑测试 ===")

    # 1. 测试配置加载
    print("\n[1/3] 正在检查路径配置...")
    print(f"Conda 路径: {MCP_PATHS.get('conda_path')}")
    print(f"Snakemake 路径: {MCP_PATHS.get('snakemake_path')}")

    # 2. 测试 Conda 环境
    print("\n[2/3] 正在测试 Conda 环境检测...")
    env_result = check_conda_environment()
    if env_result.get("available"):
        print(f"✅ 成功: 环境 '{env_result['env_name']}' 已就绪")
        print(f"✅ Snakemake 可用性: {env_result.get('snakemake_available')}")
    else:
        print(f"❌ 失败: {env_result.get('error') or env_result.get('message')}")

    # 3. 测试参考基因组列表
    print("\n[3/3] 正在测试参考基因组读取...")
    genomes = list_supported_genomes()
    if isinstance(genomes, list) and len(genomes) > 0 and "error" not in genomes[0]:
        print(f"✅ 成功: 找到了 {len(genomes)} 个支持的基因组")
        print(f"示例: {genomes[0]['name']}")
    else:
        print(f"❌ 失败: 无法读取参考基因组配置")

    print("\n=== 测试完成 ===")


if __name__ == "__main__":
    test_mcp_logic()
