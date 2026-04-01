# RNAFlow 容器化迁移指南

> 将现有的 Conda 环境管理迁移到容器化部署的完整方案

## 📚 目录

- [快速开始](#快速开始)
- [方案选择](#方案选择)
- [详细步骤](#详细步骤)
- [集群部署](#集群部署)
- [常见问题](#常见问题)

---

## 快速开始

### 1. 构建容器镜像

```bash
# 进入项目目录
cd /home/zj/pipeline/RNAFlow

# 赋予脚本执行权限
chmod +x containerize.sh

# 导出精简环境并构建单一综合镜像
./containerize.sh build-single -r your-registry.io/rnaflow -v 0.1.9
```

### 2. 使用容器运行分析

```bash
# Docker 运行
docker run --rm -it \
    -v /data:/data \
    -v $(pwd):/workspace \
    your-registry.io/rnaflow:0.1.9 \
    --cores=60 \
    --config analysisyaml=/workspace/config.yaml

# Singularity/Apptainer 运行 (HPC推荐)
apptainer run docker://your-registry.io/rnaflow:0.1.9 \
    --cores=60 \
    --config analysisyaml=config.yaml
```

---

## 方案选择

### 方案对比

| 特性 | Conda (当前) | Docker | Singularity/Apptainer |
|------|-------------|--------|----------------------|
| 环境隔离 | ✅ | ✅✅ | ✅✅ |
| 可移植性 | ⚠️ 依赖Conda | ✅ 需Docker服务 | ✅✅ 单文件 |
| HPC兼容性 | ✅✅ | ❌ | ✅✅ |
| 镜像体积 | N/A | ~5-10GB | ~5-10GB |
| 启动速度 | 快 | 快 | 较快 |
| 多用户共享 | ⚠️ | ✅ | ✅✅ |

### 推荐方案

| 场景 | 推荐方案 |
|------|---------|
| 单机/工作站 | Docker + 单一综合镜像 |
| HPC集群 | Singularity/Apptainer |
| CI/CD流水线 | Docker + 多阶段构建 |
| 云端部署 | Kubernetes + 多容器 |

---

## 详细步骤

### 方案A: Singularity/Apptainer (HPC推荐)

#### Step 1: 创建 Singularity 定义文件

```bash
# 创建 Singularity 定义文件
cat > rnaflow.def << 'EOF'
Bootstrap: docker
From: condaforge/mambaforge:latest

%labels
    Author RNAFlow Team
    Version 0.1.9
    Description RNA-seq Analysis Pipeline

%post
    # 安装系统依赖
    apt-get update && apt-get install -y --no-install-recommends \
        procps pigz && \
        rm -rf /var/lib/apt/lists/*
    
    # 安装 Snakemake
    mamba install -c conda-forge -c bioconda \
        snakemake=9.9.0 mamba -y && \
        mamba clean -afy
    
    # 创建RNAFlow目录
    mkdir -p /pipeline
    
    # 预安装核心环境（可选，加速运行）
    # mamba create -n rnaflow-star -c bioconda star=2.7.11b -y

%files
    . /pipeline

%environment
    export PATH="/opt/conda/bin:$PATH"
    export RNAFLOW_HOME=/pipeline

%runscript
    cd /pipeline
    exec snakemake "$@"

%help
    RNAFlow - RNA-seq Analysis Pipeline
    Usage: singularity run rnaflow.sif [snakemake options]
EOF
```

#### Step 2: 构建 Singularity 镜像

```bash
# 本地构建（需要sudo）
sudo singularity build rnaflow_0.1.9.sif rnaflow.def

# 或远程构建（无sudo环境）
singularity build --remote rnaflow_0.1.9.sif rnaflow.def

# 从Docker镜像转换
singularity pull docker://your-registry.io/rnaflow:0.1.9
```

#### Step 3: 运行分析

```bash
# 基本运行
singularity exec rnaflow_0.1.9.sif snakemake --version

# 完整分析（挂载数据目录）
singularity run --bind /data:/data \
    rnaflow_0.1.9.sif \
    --cores=60 \
    --config analysisyaml=/data/project/config.yaml

# 使用Apptainer (新版Singularity)
apptainer run --bind /data:/data \
    rnaflow_0.1.9.sif \
    --cores=60 \
    --config analysisyaml=/data/project/config.yaml
```

### 方案B: Docker 单一镜像

#### Step 1: 创建 Dockerfile

```dockerfile
# 使用多阶段构建减小体积
FROM condaforge/mambaforge:latest AS base

# 安装基础工具
RUN mamba install -c conda-forge -c bioconda \
    snakemake=9.9.0 mamba pigz -y && \
    mamba clean -afy

FROM base AS rnaflow

WORKDIR /pipeline
COPY . /pipeline/

# 预创建所有conda环境（可选）
# RUN snakemake --conda-create-envs-only --use-conda --conda-frontend mamba

ENV PATH="/opt/conda/bin:$PATH"
ENV RNAFLOW_HOME=/pipeline

ENTRYPOINT ["snakemake"]
```

#### Step 2: 构建与运行

```bash
# 构建镜像
docker build -t rnaflow:0.1.9 .

# 运行分析
docker run --rm \
    -v /data:/data \
    -v $(pwd)/config.yaml:/workspace/config.yaml \
    rnaflow:0.1.9 \
    --cores=60 \
    --config analysisyaml=/workspace/config.yaml
```

### 方案C: Snakemake 原生容器支持

Snakemake 支持在规则级别使用容器，无需改动现有conda配置：

#### 修改 snakefile

```python
# 在snakefile顶部添加
container: "docker://your-registry.io/rnaflow:0.1.9"

# 或在规则级别
rule STAR_mapping:
    input:
        idx_dir = config['STAR_index'][config['Genome_Version']]['index'],
        r1 = "01.qc/short_read_trim/{sample}.R1.trimed.fq.gz",
        r2 = "01.qc/short_read_trim/{sample}.R2.trimed.fq.gz",
    output:
        Aligned_bam = temp('02.mapping/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam'),
    container:
        "docker://your-registry.io/rnaflow-mapping:0.1.9"
    shell:
        """
        STAR --runMode alignReads ...
        """
```

#### 运行命令

```bash
# 使用Docker
snakemake --cores=60 --use-containers

# 使用Singularity
snakemake --cores=60 --use-singularity \
    --singularity-args "--bind /data:/data"
```

---

## 集群部署

### Slurm + Singularity

创建 `submit.sh`:

```bash
#!/bin/bash
#SBATCH --job-name=rnaflow
#SBATCH --cpus-per-task=60
#SBATCH --mem=200G
#SBATCH --time=48:00:00

# 加载Apptainer
module load apptainer

# 运行RNAFlow
apptainer run --bind /data:/data \
    /path/to/rnaflow_0.1.9.sif \
    --cores=$SLURM_CPUS_PER_TASK \
    --config analysisyaml=/data/project/config.yaml \
    --latency-wait 60
```

### Kubernetes 部署

创建 `k8s-rnaflow.yaml`:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: rnaflow-analysis
spec:
  template:
    spec:
      containers:
      - name: rnaflow
        image: your-registry.io/rnaflow:0.1.9
        command:
        - snakemake
        args:
        - --cores=60
        - --config
        - analysisyaml=/data/config.yaml
        volumeMounts:
        - name: data-volume
          mountPath: /data
        resources:
          requests:
            memory: "200Gi"
            cpu: "60"
          limits:
            memory: "250Gi"
            cpu: "64"
      volumes:
      - name: data-volume
        persistentVolumeClaim:
          claimName: rnaflow-data-pvc
      restartPolicy: Never
```

---

## 常见问题

### Q1: 容器内无法访问外部参考基因组

**解决方案**: 使用 `--bind` 挂载参考基因组目录

```bash
singularity run --bind /data/jzhang/reference:/reference \
    rnaflow.sif \
    --config analysisyaml=config.yaml
```

### Q2: 权限问题（无法写入输出目录）

**解决方案**: 使用 `--fakeroot` 或指定用户

```bash
singularity run --fakeroot --bind $(pwd):/workspace \
    rnaflow.sif \
    --config analysisyaml=/workspace/config.yaml
```

### Q3: 容器镜像太大

**优化策略**:
1. 使用多阶段构建
2. 清理conda缓存: `mamba clean -afy`
3. 只安装必要工具

### Q4: 如何与现有conda环境共存

**方案**: 使用 `--use-conda` 和 `--use-singularity` 组合

```bash
snakemake \
    --cores=60 \
    --use-conda \              # 使用conda环境
    --use-singularity \        # 使用容器
    --conda-frontend mamba
```

---

## 迁移检查清单

- [ ] 确认所有数据目录可通过 `--bind` 访问
- [ ] 更新 `config.yaml` 中的路径为容器内路径
- [ ] 测试单个规则运行
- [ ] 测试完整流程Dry-run
- [ ] 测试完整分析流程
- [ ] 验证输出结果一致性
- [ ] 文档更新

---

## 参考资源

- [Snakemake Container Support](https://snakemake.readthedocs.io/en/stable/snakefiles/deployment.html#containerization)
- [Apptainer Documentation](https://apptainer.org/docs/)
- [Singularity Hub](https://singularityhub.github.io/)
