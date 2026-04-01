#!/bin/bash
# RNAFlow 容器化迁移脚本
# 用于将现有的conda环境转换为容器镜像

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_REGISTRY="your-registry.com/rnaflow"  # 修改为你的镜像仓库
VERSION="0.1.9"

echo "=== RNAFlow Containerization Script ==="
echo "Version: $VERSION"
echo ""

# Function: 显示帮助
show_help() {
    cat << EOF
Usage: $0 [command] [options]

Commands:
    export-envs     导出所有conda环境为精简版本
    build-base      构建基础镜像
    build-all       构建所有模块镜像
    build-single    构建单一综合镜像
    push            推送镜像到仓库
    test            测试容器化运行

Options:
    -r, --registry  指定镜像仓库 (默认: $DOCKER_REGISTRY)
    -v, --version   指定版本号 (默认: $VERSION)
    -h, --help      显示帮助

Examples:
    $0 export-envs                          # 导出精简的环境文件
    $0 build-single -r myregistry.io/rnaflow  # 构建单一镜像
    $0 build-all                             # 构建所有模块镜像
EOF
}

# Function: 导出精简环境
export_envs() {
    echo "[1/4] 导出conda环境定义..."
    mkdir -p "$SCRIPT_DIR/docker/envs"
    
    for env_file in "$SCRIPT_DIR"/envs/*.yaml; do
        if [ -f "$env_file" ]; then
            env_name=$(basename "$env_file" .yaml)
            echo "  处理: $env_name"
            
            # 提取关键包定义，去除构建号以减小体积
            python3 << PYEOF
import yaml
import sys

with open('$env_file', 'r') as f:
    env = yaml.safe_load(f)

# 创建精简版本
minimal = {
    'name': env.get('name', '$env_name'),
    'channels': env.get('channels', ['bioconda', 'conda-forge']),
    'dependencies': []
}

# 提取主要工具，去除精确版本和构建号
for dep in env.get('dependencies', []):
    if isinstance(dep, str):
        # 提取包名（去掉版本和构建号）
        pkg_name = dep.split('=')[0] if '=' in dep else dep
        # 保留主要工具的精确版本
        if any(tool in pkg_name for tool in ['star', 'rsem', 'samtools', 'gatk', 'fastp', 'fastqc']):
            minimal['dependencies'].append(dep.split('=')[0] + '=' + dep.split('=')[1] if '=' in dep else pkg_name)
        else:
            minimal['dependencies'].append(pkg_name)
    else:
        minimal['dependencies'].append(dep)

# 去重
minimal['dependencies'] = list(dict.fromkeys(minimal['dependencies']))

with open('$SCRIPT_DIR/docker/envs/${env_name}.yaml', 'w') as f:
    yaml.dump(minimal, f, default_flow_style=False, sort_keys=False)

print(f"  已创建精简版本: docker/envs/${env_name}.yaml")
PYEOF
        fi
    done
    echo "✓ 环境导出完成"
}

# Function: 构建基础镜像
build_base() {
    echo "[2/4] 构建基础镜像..."
    
    cat > "$SCRIPT_DIR/docker/Dockerfile.base" << 'EOF'
FROM condaforge/mambaforge:24.11.3-0

LABEL maintainer="RNAFlow Team"
LABEL description="RNAFlow Base Image with Snakemake"

# 安装系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    procps \
    && rm -rf /var/lib/apt/lists/*

# 安装Snakemake
RUN mamba install -c conda-forge -c bioconda \
    snakemake=9.9.0 \
    mamba \
    && mamba clean -afy

WORKDIR /pipeline
EOF

    docker build -f "$SCRIPT_DIR/docker/Dockerfile.base" \
        -t "$DOCKER_REGISTRY/rnaflow-base:$VERSION" \
        "$SCRIPT_DIR/docker"
    
    echo "✓ 基础镜像构建完成: $DOCKER_REGISTRY/rnaflow-base:$VERSION"
}

# Function: 构建单一综合镜像
build_single() {
    echo "[3/4] 构建单一综合镜像..."
    
    cat > "$SCRIPT_DIR/Dockerfile" << EOF
FROM $DOCKER_REGISTRY/rnaflow-base:$VERSION

LABEL version="$VERSION"
LABEL description="RNAFlow Complete Pipeline"

# 复制项目文件
COPY . /pipeline/

# 预创建所有conda环境
RUN cd /pipeline && \
    snakemake --conda-create-envs-only \
    --use-conda \
    --conda-frontend mamba \
    --conda-prefix /opt/conda/envs/rnaflow || echo "Environment pre-creation completed"

# 设置环境变量
ENV RNAFLOW_HOME=/pipeline
ENV PATH="/opt/conda/envs/rnaflow/bin:/pipeline/src:\$PATH"

WORKDIR /pipeline

ENTRYPOINT ["snakemake"]
CMD ["--help"]
EOF

    docker build -f "$SCRIPT_DIR/Dockerfile" \
        -t "$DOCKER_REGISTRY/rnaflow:$VERSION" \
        -t "$DOCKER_REGISTRY/rnaflow:latest" \
        "$SCRIPT_DIR"
    
    echo "✓ 综合镜像构建完成: $DOCKER_REGISTRY/rnaflow:$VERSION"
}

# Function: 构建多模块镜像
build_all() {
    echo "[3/4] 构建所有模块镜像..."
    
    # QC模块
    cat > "$SCRIPT_DIR/docker/Dockerfile.qc" << 'EOF'
FROM rnaflow-base:latest

RUN mamba create -n rnaflow-qc -c bioconda -c conda-forge \
    fastqc=0.12.1 fastp=0.23.4 multiqc=1.25.1 \
    && mamba clean -afy

ENV PATH="/opt/conda/envs/rnaflow-qc/bin:$PATH"
EOF
    docker build -f "$SCRIPT_DIR/docker/Dockerfile.qc" \
        -t "$DOCKER_REGISTRY/rnaflow-qc:$VERSION" \
        "$SCRIPT_DIR/docker"

    # Mapping模块
    cat > "$SCRIPT_DIR/docker/Dockerfile.mapping" << 'EOF'
FROM rnaflow-base:latest

RUN mamba create -n rnaflow-mapping -c bioconda -c conda-forge \
    star=2.7.11b samtools=1.21 sambamba=1.0.0 \
    qualimap=2.3 rseqc=5.0.3 \
    && mamba clean -afy

ENV PATH="/opt/conda/envs/rnaflow-mapping/bin:$PATH"
EOF
    docker build -f "$SCRIPT_DIR/docker/Dockerfile.mapping" \
        -t "$DOCKER_REGISTRY/rnaflow-mapping:$VERSION" \
        "$SCRIPT_DIR/docker"

    # RSEM模块
    cat > "$SCRIPT_DIR/docker/Dockerfile.rsem" << 'EOF'
FROM rnaflow-base:latest

RUN mamba create -n rnaflow-rsem -c bioconda -c conda-forge \
    rsem=1.3.3 star=2.7.11b samtools=1.21 \
    && mamba clean -afy

ENV PATH="/opt/conda/envs/rnaflow-rsem/bin:$PATH"
EOF
    docker build -f "$SCRIPT_DIR/docker/Dockerfile.rsem" \
        -t "$DOCKER_REGISTRY/rnaflow-rsem:$VERSION" \
        "$SCRIPT_DIR/docker"

    echo "✓ 所有模块镜像构建完成"
}

# Function: 推送镜像
push_images() {
    echo "[4/4] 推送镜像到仓库..."
    docker push "$DOCKER_REGISTRY/rnaflow-base:$VERSION"
    docker push "$DOCKER_REGISTRY/rnaflow:$VERSION"
    docker push "$DOCKER_REGISTRY/rnaflow:latest"
    echo "✓ 镜像推送完成"
}

# Function: 测试运行
test_run() {
    echo "[Test] 测试容器化运行..."
    
    docker run --rm -v "$(pwd):/workspace" \
        "$DOCKER_REGISTRY/rnaflow:$VERSION" \
        --version
    
    echo "✓ 测试通过"
}

# 主程序
main() {
    case "${1:-}" in
        export-envs)
            export_envs
            ;;
        build-base)
            build_base
            ;;
        build-single)
            build_base
            build_single
            ;;
        build-all)
            build_base
            build_all
            ;;
        push)
            push_images
            ;;
        test)
            test_run
            ;;
        -h|--help|help)
            show_help
            ;;
        *)
            echo "错误: 未知命令: ${1:-}"
            show_help
            exit 1
            ;;
    esac
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--registry)
            DOCKER_REGISTRY="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

main "$@"
