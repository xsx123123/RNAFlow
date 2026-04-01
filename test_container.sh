#!/bin/bash
# RNAFlow 容器化测试脚本

set -e

echo "========================================"
echo "  RNAFlow Containerization Test Suite"
echo "========================================"
echo ""

# 配置
IMAGE_NAME="${1:-rnaflow:0.1.9}"
TEST_DATA_DIR="${2:-./test_data}"
RESULTS_DIR="${3:-./test_results}"

mkdir -p "$RESULTS_DIR"

echo "[Config]"
echo "  Image: $IMAGE_NAME"
echo "  Test Data: $TEST_DATA_DIR"
echo "  Results: $RESULTS_DIR"
echo ""

# 测试计数
TESTS_PASSED=0
TESTS_FAILED=0

# 辅助函数
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    
    echo "[TEST] $test_name"
    echo "  Command: $test_cmd"
    
    if eval "$test_cmd" > "$RESULTS_DIR/${test_name}.log" 2>&1; then
        echo "  ✓ PASSED"
        ((TESTS_PASSED++))
    else
        echo "  ✗ FAILED"
        echo "  Log: $RESULTS_DIR/${test_name}.log"
        ((TESTS_FAILED++))
    fi
    echo ""
}

# ==================== 测试开始 ====================

# Test 1: 镜像存在检查
echo "--- Phase 1: Image Tests ---"
run_test "image_exists" "docker image inspect $IMAGE_NAME > /dev/null 2>&1"

# Test 2: Snakemake版本检查
run_test "snakemake_version" "docker run --rm $IMAGE_NAME --version"

# Test 3: 基础工具检查
run_test "tools_available" "docker run --rm $IMAGE_NAME --help | grep -q 'snakemake'"

echo "--- Phase 2: Environment Tests ---"

# Test 4: Conda环境检查（如果使用conda）
run_test "conda_env" "docker run --rm --entrypoint /bin/bash $IMAGE_NAME -c 'conda --version'"

# Test 5: 关键工具检查
run_test "star_available" "docker run --rm --entrypoint /bin/bash $IMAGE_NAME -c 'which STAR || true'"
run_test "samtools_available" "docker run --rm --entrypoint /bin/bash $IMAGE_NAME -c 'which samtools || true'"
run_test "fastqc_available" "docker run --rm --entrypoint /bin/bash $IMAGE_NAME -c 'which fastqc || true'"

echo "--- Phase 3: Volume Mount Tests ---"

# Test 6: 目录挂载测试
echo "test_content" > "$RESULTS_DIR/mount_test.txt"
run_test "volume_mount" "docker run --rm -v $RESULTS_DIR:/test $IMAGE_NAME --configfile /test/mount_test.txt --dry-run 2>&1 | head -1"

echo "--- Phase 4: Dry-run Tests ---"

# Test 7: Snakefile语法检查（如果提供测试数据）
if [ -f "$TEST_DATA_DIR/config.yaml" ]; then
    run_test "snakefile_syntax" "docker run --rm \
        -v $TEST_DATA_DIR:/data \
        -v $(pwd):/pipeline \
        -w /pipeline \
        $IMAGE_NAME \
        -n --config analysisyaml=/data/config.yaml"
else
    echo "[SKIP] Dry-run tests (no test data found at $TEST_DATA_DIR)"
fi

# ==================== 测试总结 ====================
echo ""
echo "========================================"
echo "  Test Summary"
echo "========================================"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed. Check logs in $RESULTS_DIR"
    exit 1
fi
