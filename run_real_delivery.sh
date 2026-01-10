#!/bin/bash

# =================================================================
# RNAFlow Real Data Delivery Test
# =================================================================

# 1. 路径定义
PROJECT_ROOT=$(pwd)
TOOL_ROOT="$PROJECT_ROOT/src/src/data-deliver/RNAFlow_Deliver_Tool"
PYTHON_LIB="$TOOL_ROOT/python"
CLI_SCRIPT="$PYTHON_LIB/RNAFlow_Deliver/cli.py"
CONFIG_FILE="$TOOL_ROOT/config/full_delivery_config.yaml"

# 真实数据源
DATA_SOURCE="/data/jzhang/project/Temp/PRJNA1224991_lettcue/01.workflow"

# 交付输出位置 (在当前目录下创建)
OUTPUT_DIR="./real_data_delivery_test"

# 2. 环境配置
# 将工具库加入 PYTHONPATH，确保能加载 data_deliver_rs (Rust后端)
export PYTHONPATH=$PYTHONPATH:$PYTHON_LIB

echo -e "\n============================================="
echo "       🚀 RNAFlow Data Delivery Tool         "
echo "============================================="
echo "源数据: $DATA_SOURCE"
echo "目标地: $OUTPUT_DIR"
echo "配置表: $CONFIG_FILE"
echo "---------------------------------------------"

# 3. 检查源目录是否存在
if [ ! -d "$DATA_SOURCE" ]; then
    echo "[错误] 找不到源数据目录: $DATA_SOURCE"
    echo "请确认挂载路径或拼写是否正确。"
    exit 1
fi

# 4. 执行交付
# 清理旧的测试结果 (可选)
if [ -d "$OUTPUT_DIR" ]; then
    echo "清理旧的输出目录..."
    rm -rf "$OUTPUT_DIR"
fi

python3 "$CLI_SCRIPT" deliver \
    -d "$DATA_SOURCE" \
    -o "$OUTPUT_DIR" \
    -c "$CONFIG_FILE"

# 5. 结果提示
if [ $? -eq 0 ]; then
    echo -e "\n✅ 交付测试成功！"
    echo "---------------------------------------------"
    echo "请查看目录结构: ls -F $OUTPUT_DIR"
    echo "检查 JSON 报告: cat $OUTPUT_DIR/delivery_manifest.json"
else
    echo -e "\n❌ 交付测试失败，请查看上方报错信息。"
fi
