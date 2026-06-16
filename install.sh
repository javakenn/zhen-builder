#!/usr/bin/env bash
# zhen-builder · podcast-gen（生成学习资料）一键安装
#
# 用法：
#   ./install.sh                      # 自动选择 Agent skills 目录安装
#   ./install.sh ~/.claude/skills     # 指定安装到某个 Agent 的 skills 目录
#   ./install.sh ~/.openclaw/skills
#
# 安装动作：
#   1. 把 skill 复制到 <skills-dir>/podcast-gen
#   2. 在该目录建 .venv 并安装依赖（faster-whisper / python-docx / reportlab）
#   3. 把 SKILL.md 里写死的路径改写为实际安装路径
#   4. 创建 ~/workflow 工作目录

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- 1. 确定目标 skills 目录 ----
if [ "${1:-}" != "" ]; then
  SKILLS_DIR="${1/#\~/$HOME}"
elif [ -d "$HOME/.claude" ]; then
  SKILLS_DIR="$HOME/.claude/skills"
elif [ -d "$HOME/.openclaw" ]; then
  SKILLS_DIR="$HOME/.openclaw/skills"
else
  SKILLS_DIR="$HOME/.claude/skills"
fi

SKILL_ROOT="$SKILLS_DIR/podcast-gen"
echo "==> 安装目标：$SKILL_ROOT"

# ---- 2. 复制 skill 文件 ----
mkdir -p "$SKILL_ROOT"
cp -R "$REPO_DIR/skills/podcast-gen/." "$SKILL_ROOT/"

# ---- 3. 创建 venv 并安装依赖 ----
PYTHON="${PYTHON:-python3}"
echo "==> 创建虚拟环境 .venv（使用 $PYTHON）"
"$PYTHON" -m venv "$SKILL_ROOT/.venv"
VENV_PY="$SKILL_ROOT/.venv/bin/python3"
echo "==> 安装依赖（首次较慢，含 faster-whisper / reportlab / python-docx）"
"$VENV_PY" -m pip install --quiet --upgrade pip
"$VENV_PY" -m pip install --quiet -r "$REPO_DIR/requirements.txt"

# ---- 4. 改写 SKILL.md 中写死的路径，指向实际安装位置 ----
# 原 skill 默认写死 ~/.openclaw/skills/podcast-gen，这里替换成本机实际路径，
# 并让 gen_handbook.py 用 venv 的 python（确保 docx/reportlab 可用）。
export SKILL_ROOT VENV_PY  # 供下面 perl 通过 %ENV 读取
perl -0pi -e 's{\Q~/.openclaw/skills/podcast-gen\E}{$ENV{SKILL_ROOT}}g' "$SKILL_ROOT/SKILL.md"
perl -0pi -e 's{\Q$HOME/.openclaw/skills/podcast-gen\E}{$ENV{SKILL_ROOT}}g' "$SKILL_ROOT/SKILL.md"
perl -0pi -e 's{python3 \Q$ENV{SKILL_ROOT}\E/scripts/gen_handbook\.py}{$ENV{VENV_PY} $ENV{SKILL_ROOT}/scripts/gen_handbook.py}g' "$SKILL_ROOT/SKILL.md"

# ---- 5. 工作目录 ----
mkdir -p "$HOME/workflow"

echo ""
echo "✅ 安装完成：$SKILL_ROOT"
echo "   - 依赖已装入 $SKILL_ROOT/.venv"
echo "   - 工作目录 ~/workflow 已就绪"
echo ""
echo "首次转写时 faster-whisper 会自动下载 medium 模型（约 1.5GB），属正常。"
echo "在你的 Agent 里说「生成学习资料」并发来音频或逐字稿即可触发。"
