# zhen-builder

把 NotebookLM 播客音频一键变成**逐字稿 + 双语学习手册 PDF + 小宇宙文案**的 Agent Skill。

收录 skill：**`podcast-gen`（触发词「生成学习资料」）** —— 输入一段播客音频（或已有逐字稿），自动产出三项交付物：

1. **逐字稿** `.docx`（区分说话人 S1/S2 + 时间戳，先给你核对）
2. **双语学习手册** `.pdf`（英文校订 + 中文翻译，含词汇表、习语表）
3. **小宇宙介绍文案**

转写用本地 [faster-whisper](https://github.com/SYSTRAN/faster-whisper)（**无需任何 API Key**）；PDF 用 reportlab 直出（内置 PingFang/STHeiti 中文字体，不依赖 Word）。

---

## 快速安装

适用于任何「以本地目录加载 skill」的 Agent（Claude Code `~/.claude/skills`、openclaw `~/.openclaw/skills` 等）。

```bash
git clone https://github.com/javakenn/zhen-builder.git
cd zhen-builder
./install.sh                      # 自动选择 skills 目录
# 或显式指定目标 Agent 的 skills 目录：
./install.sh ~/.claude/skills
./install.sh ~/.openclaw/skills
```

`install.sh` 会：
1. 把 skill 复制到 `<skills-dir>/podcast-gen`
2. 在该目录建 `.venv` 并安装依赖（faster-whisper / python-docx / reportlab）
3. 把 `SKILL.md` 里写死的路径改写成你的实际安装路径
4. 创建 `~/workflow` 工作目录

> 首次转写时 faster-whisper 会自动下载 `medium` 模型（约 1.5GB），属正常，仅一次。

### 前置要求

- Python **3.10–3.12**（faster-whisper 暂无 3.13+ 的 wheel；install.sh 会自动挑兼容版本）
- 约 2GB 磁盘（依赖 + whisper 模型）
- 无需 ffmpeg（faster-whisper 依赖的 PyAV 已内置）

## 使用

安装后在你的 Agent 里说「**生成学习资料**」，然后把播客音频或逐字稿发给它即可。其余流程（转写 → 说话人标注 → 逐字稿核对 → 手册 + 文案）由 skill 自动驱动，所有中间产物与成品统一落在 `~/workflow/`。

也可单独调用脚本：

```bash
# 转写音频 → JSON
<skill>/.venv/bin/python3 <skill>/scripts/transcribe.py \
  --file audio.m4a --output ~/workflow/podcast_transcription.json

# 由 JSON 生成 .docx + PDF
<skill>/.venv/bin/python3 <skill>/scripts/gen_handbook.py \
  --input ~/workflow/handbook_data.json \
  --output ~/workflow/手册.docx --pdf-output ~/workflow/手册.pdf
```

## 手动安装（不想用脚本）

把 `skills/podcast-gen/` 整个目录拷到你的 skills 目录，建 venv 装 `requirements.txt`，再把 `SKILL.md` 里的 `~/.openclaw/skills/podcast-gen` 替换成你的实际安装路径即可。

## 结构

```
zhen-builder/
├── install.sh              一键安装脚本
├── requirements.txt        Python 依赖
└── skills/podcast-gen/
    ├── SKILL.md            skill 定义与完整交互流程
    ├── scripts/
    │   ├── transcribe.py   faster-whisper 本地转写
    │   └── gen_handbook.py .docx + PDF 生成（reportlab）
    └── references/
        └── xiaoyuzhou_sample.md  小宇宙文案样例
```

## License

MIT
