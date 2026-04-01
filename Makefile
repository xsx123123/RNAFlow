# RNAFlow Containerization Makefile
# 简化容器化操作

.PHONY: help build test run clean shell push

# 配置变量
IMAGE_NAME ?= rnaflow
VERSION ?= 0.1.9
REGISTRY ?= 
FULL_IMAGE = $(REGISTRY)$(IMAGE_NAME):$(VERSION)

# 默认目标
help:
	@echo "RNAFlow Containerization Commands"
	@echo ""
	@echo "Usage: make [target] [VARIABLE=value]"
	@echo ""
	@echo "Targets:"
	@echo "  build        构建 Docker 镜像"
	@echo "  build-sing   构建 Singularity 镜像"
	@echo "  test         运行容器测试"
	@echo "  run          运行分析（需指定 CONFIG）"
	@echo "  shell        进入容器 Shell"
	@echo "  push         推送镜像到仓库"
	@echo "  clean        清理构建产物"
	@echo "  export-envs  导出精简环境文件"
	@echo ""
	@echo "Variables:"
	@echo "  IMAGE_NAME   镜像名称 (默认: $(IMAGE_NAME))"
	@echo "  VERSION      版本号 (默认: $(VERSION))"
	@echo "  REGISTRY     镜像仓库 (默认: $(REGISTRY))"
	@echo "  CONFIG       配置文件路径"
	@echo "  DATA_DIR     数据目录 (默认: /data)"
	@echo ""
	@echo "Examples:"
	@echo "  make build"
	@echo "  make run CONFIG=/data/project/config.yaml"
	@echo "  make push REGISTRY=myregistry.io/"

# 构建 Docker 镜像
build:
	@echo "[+] Building Docker image: $(FULL_IMAGE)"
	docker build -t $(IMAGE_NAME):$(VERSION) .
	docker tag $(IMAGE_NAME):$(VERSION) $(IMAGE_NAME):latest
	@echo "[✓] Build complete: $(IMAGE_NAME):$(VERSION)"

# 构建 Singularity 镜像（需要sudo）
build-sing:
	@echo "[+] Building Singularity image: rnaflow_$(VERSION).sif"
	@if [ ! -f "rnaflow.def" ]; then \
		echo "[!] Creating default rnaflow.def..."; \
		$(MAKE) singularity-def; \
	fi
	sudo singularity build rnaflow_$(VERSION).sif rnaflow.def
	@echo "[✓] Singularity build complete"

# 生成 Singularity 定义文件
singularity-def:
	@cat > rnaflow.def << 'EOF'
Bootstrap: docker
From: condaforge/mambaforge:latest

%labels
    Author RNAFlow Team
    Version $(VERSION)

%post
    apt-get update && apt-get install -y --no-install-recommends procps && rm -rf /var/lib/apt/lists/*
    mamba install -c conda-forge -c bioconda snakemake=9.9.0 mamba -y
    mamba clean -afy
    mkdir -p /pipeline

%files
    . /pipeline

%environment
    export PATH="/opt/conda/bin:$$PATH"
    export RNAFLOW_HOME=/pipeline

%runscript
    cd /pipeline
    exec snakemake "$$@"
EOF
	@echo "[✓] Created rnaflow.def"

# 运行测试
test:
	@echo "[+] Running container tests..."
	chmod +x test_container.sh
	./test_container.sh $(IMAGE_NAME):$(VERSION)

# 运行分析（需要指定CONFIG）
run:
ifndef CONFIG
	@echo "[!] Error: CONFIG not specified"
	@echo "Usage: make run CONFIG=/path/to/config.yaml"
	@exit 1
endif
	@echo "[+] Running RNAFlow with config: $(CONFIG)"
	docker run --rm -it \
		-v $(DATA_DIR):/data \
		-v $(shell dirname $(CONFIG)):/config:ro \
		-v $(shell pwd):/pipeline \
		$(IMAGE_NAME):$(VERSION) \
		--cores=$(CORES) \
		--config analysisyaml=/config/$(shell basename $(CONFIG))

# 进入容器 Shell
shell:
	@echo "[+] Starting interactive shell in container..."
	docker run --rm -it \
		-v $(DATA_DIR):/data \
		-v $(shell pwd):/pipeline \
		--entrypoint /bin/bash \
		$(IMAGE_NAME):$(VERSION)

# 推送镜像到仓库
push:
ifndef REGISTRY
	@echo "[!] Error: REGISTRY not specified"
	@echo "Usage: make push REGISTRY=myregistry.io/"
	@exit 1
endif
	@echo "[+] Pushing to $(REGISTRY)"
	docker tag $(IMAGE_NAME):$(VERSION) $(FULL_IMAGE)
	docker push $(FULL_IMAGE)
	@echo "[✓] Pushed: $(FULL_IMAGE)"

# 导出精简环境
export-envs:
	@echo "[+] Exporting minimal conda environments..."
	chmod +x containerize.sh
	./containerize.sh export-envs

# 清理构建产物
clean:
	@echo "[+] Cleaning up..."
	docker rmi -f $(IMAGE_NAME):$(VERSION) 2>/dev/null || true
	docker rmi -f $(IMAGE_NAME):latest 2>/dev/null || true
	rm -f rnaflow_*.sif rnaflow.def
	@echo "[✓] Cleanup complete"

# 默认配置
DATA_DIR ?= /data
CORES ?= 60
