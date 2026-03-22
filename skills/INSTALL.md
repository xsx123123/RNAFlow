# RNAFlow Skills 安装指南

## 快速安装

### 为 Claude Code / OpenCode 安装

```bash
cd /home/zj/pipeline/RNAFlow/skills
./install_skills.sh
```

### 为 Codex 安装

```bash
cd /home/zj/pipeline/RNAFlow/skills
./install_codex_skills.sh
```

## 手动安装

如果需要手动安装，按以下步骤操作：

### 1. 创建目标目录

```bash
mkdir -p ~/.claude/skills/RNAFlow
```

### 2. 复制文件

```bash
cd /home/zj/pipeline/RNAFlow/skills

# 复制核心文件
cp SKILL.md ~/.claude/skills/RNAFlow/
cp path_config.yaml ~/.claude/skills/RNAFlow/
cp start_rnaflow.sh ~/.claude/skills/RNAFlow/

# 复制文档
cp README.md ~/.claude/skills/RNAFlow/
cp usage-guide.md ~/.claude/skills/RNAFlow/

# 复制示例配置
mkdir -p ~/.claude/skills/RNAFlow/examples
cp examples/*.yaml ~/.claude/skills/RNAFlow/examples/
cp examples/*.csv ~/.claude/skills/RNAFlow/examples/
cp examples/*.sh ~/.claude/skills/RNAFlow/examples/
```

### 3. 设置执行权限

```bash
chmod +x ~/.claude/skills/RNAFlow/start_rnaflow.sh
chmod +x ~/.claude/skills/RNAFlow/examples/run_rnaflow.sh
```

## 安装后配置

### 1. 验证路径配置

编辑 `~/.claude/skills/RNAFlow/path_config.yaml`，确保：

```yaml
RNAFLOW_ROOT: "/home/zj/pipeline/RNAFlow"
```

### 2. 重启 AI Agent

重启 opencode 或 Claude Code 以加载新安装的 skill。

## 使用

安装后，你可以这样使用：

```
"帮我运行RNAFlow分析"
"设置RNAFlow项目"
"使用RNAFlow进行差异表达分析"
```

## 卸载

如需卸载：

```bash
rm -rf ~/.claude/skills/RNAFlow
```
