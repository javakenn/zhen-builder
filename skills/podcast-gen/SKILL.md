---
name: podcast-gen
description: >
  播客生成助手：从 NotebookLM 播客音频生成逐字稿、双语学习手册 PDF 和小宇宙介绍文案。
  Use when: 用户说"播客生成"、"生成手册"、"转录播客"、"生成文案"、"小宇宙文案"、
  "做双语手册"、"podcast generate"、发送了音频文件要求处理。
  Triggers: "/生成学习资料", "生成学习资料", "生成手册", "转录", "podcast gen",
  "生成双语手册", "帮我做手册", "小宇宙文案", "处理播客音频"
---

# 播客生成助手

从 NotebookLM 生成的播客音频（或已有逐字稿），自动产出三项交付物，并最终将交付物的文件发送给用户（用户是通过飞书在对话）：
1. **逐字稿** .docx（区分说话人 S1/S2 + 时间标记，先输出供用户核对）
2. **双语学习手册** PDF（英文校订 + 中文翻译，含词汇表和习语表）
3. **小宇宙介绍文案**

## 🚨 硬性交互规则（必读）

**严禁使用 AskUserQuestion、卡片、选择器等任何卡片式交互。**
- 所有选项都必须以"编号 + 纯文本"列表的形式直接输出在回复里；
- 等用户回复序号（例如 `1`、`2`、`3`）或自定义内容即可继续；
- 违反此规则会被用户直接打断并要求重写。

违反原因：用户使用的终端（飞书/Lark）对卡片渲染支持差、回复路径不一致，已多次造成卡顿。

## 脚本路径

```
~/.openclaw/skills/podcast-gen/scripts/transcribe.py    # Whisper 转录（本地 whisper.cpp）
~/.openclaw/skills/podcast-gen/scripts/gen_handbook.py  # 生成 .docx + PDF
```

## 环境

转写使用本地 faster-whisper（**无需任何 API Key**），依赖装在本 skill 目录下的虚拟环境：
```
~/.openclaw/skills/podcast-gen/.venv
```
（install.sh 会把上面这个路径改写为你的实际安装位置。）

## 完整交互流程

### Step 1: 接收用户输入

**一句话提示，不列选项、不列路径格式**（绝不用卡片/AskUserQuestion）：

```
发给我：音频或逐字稿文件，我就马上开始生成学习资料
```

然后根据用户实际发来的内容自动识别类型，**不要追问格式**：

**类型识别与分支处理**：

- **音频附件（飞书/Lark 直接发送）**：cc-connect 会把附件下载到本地；把文件移动/复制到 `~/workflow/`（保留原文件名，若重名则加时间戳后缀），回复：
  ```
  收到文件：~/workflow/{文件名}（{大小}）
  现在开始转录，预计需要几分钟。
  ```
  之后用该本地路径进入 Step 2。

- **逐字稿文件（.txt/.md）或用户直接粘贴的文本**：保存到 `~/workflow/podcast_raw_transcript.txt`，回复"收到逐字稿，开始生成手册和文案"，**跳过 Step 2**，直接进入 Step 3（说话人标注）。

- **用户发来本地路径**（如 `~/workflow/xxx.m4a` 或 `/Users/.../xxx.txt`）：按扩展名判断是音频还是逐字稿，走上述对应分支。**虽然提示里不主动引导"发路径"，但用户发来了也要正常处理。**

### Step 2: Whisper 转录（音频路径走这里）

> **⚠️ 关键执行规则**：
> 1. 不要用 Agent 子任务或异步方式执行转录，会导致上下文丢失。
> 2. 用 `nohup` 启动转录进程，这样即使 Bash 超时进程也不会被杀。
> 3. 转录完成后**立即继续 Step 3**，不要等用户再次输入。

**先告知用户，再执行转录**：

```
收到音频：{文件名}（{大小}）
本地 Whisper 转写中，大约需要 5-10 分钟（取决于文件大小）。
转写完成后我会立刻继续处理，不需要你做任何操作，请耐心等待。
```

**第一步：启动转录**（nohup 保证进程不会被超时杀死）：

```bash
nohup ~/.openclaw/skills/podcast-gen/.venv/bin/python3 ~/.openclaw/skills/podcast-gen/scripts/transcribe.py \
  --file "{本地路径}" \
  --output ~/workflow/podcast_transcription.json \
  > ~/workflow/transcribe.log 2>&1 &
echo "PID=$!"
```

**第二步：轮询等待完成**（每 30 秒检查一次，最长 20 分钟）：

```bash
for i in $(seq 1 40); do
  if [ -f ~/workflow/podcast_transcription.json ] && grep -q '"segments"' ~/workflow/podcast_transcription.json 2>/dev/null; then
    echo "DONE"; cat ~/workflow/transcribe.log; exit 0
  fi
  sleep 30
done
echo "TIMEOUT"; cat ~/workflow/transcribe.log; exit 1
```

Bash timeout 设为 **600000**。如果第一轮 10 分钟轮询完还没结束，再执行一次同样的轮询脚本继续等（最多再等 10 分钟）。

转录完成后，**不要等用户回复，直接进入 Step 3**。

### Step 3: 说话人标注

Whisper 输出的 segments 只有时间戳和文本，没有说话人标注。分析转录文本，标注 S1 和 S2：

**标注规则**：
1. NotebookLM 播客是两人对话，交替发言
2. S1 = 知识讲解者（引用资料、给出分析）
3. S2 = 好奇提问者（追问、反应、总结）
4. 合并连续的同一说话人 segments

将逐字稿保存为 JSON 到 `~/workflow/transcript_data.json`：
```json
{
  "title": "全英｜Vol. XX {主题中文标题}",
  "transcript": [
    {"timestamp": "00:00", "speaker": "S2", "text": "So if you are engaging..."},
    {"timestamp": "00:11", "speaker": "S1", "text": "Right. You're activating..."}
  ]
}
```

### Step 3.5: 输出逐字稿给用户核对（必须）

先生成逐字稿 .docx 供用户核对，**不要直接生成手册**：

```bash
python3 ~/.openclaw/skills/podcast-gen/scripts/gen_handbook.py \
  --transcript-input ~/workflow/transcript_data.json \
  --transcript-output "~/workflow/{标题}_逐字稿.docx"
```

**要求**：
1. 逐字稿必须完整，不得省略、压缩、改写任何内容
2. 优先保证完整性，再考虑美化
3. 生成完成后发给用户确认（飞书/Lark）

提示用户：
```
已生成完整逐字稿 Word，先给你核对。
内容一字不漏，确认无误后再继续生成双语手册和小宇宙文案。
如果发现漏句、错句或说话人归属不对，直接告诉我。
```

等用户确认后继续。

### Step 4: 生成双语手册 JSON

基于逐字稿生成 JSON 结构供 gen_handbook.py 使用。

**关键要求**：
1. **分 Part**：按主题分 4-8 个 Part，每个 Part 有中文标题
2. **英文校订**：去掉 um/uh/you know 等填充词，保留自然语感
3. **中文翻译**：准确、地道，非机翻风格
4. **词汇表**：5-8 个高频学术/专业词汇，统计词频，附播客原句
5. **习语表**：3-5 个地道英语习语，附中文含义、原句和用法提示

JSON 格式（**字段名必须严格按以下写法**）：

```json
{
  "title": "全英｜Vol. XX {主题中文标题}",
  "subtitle": "Brain Snacks文稿校订版 · 中英双语学习手册",
  "usage_note": "S1 / S2 表示两位对谈主持人。...",
  "parts": [
    {
      "title": "Part I ｜ {中文标题}",
      "rows": [
        {"speaker": "S1", "english": "校订后英文...", "chinese": "中文翻译..."}
      ]
    }
  ],
  "vocabulary": [
    {"word": "mindset", "chinese": "心态", "freq": 7, "example": "播客原句..."}
  ],
  "idioms": [
    {"idiom": "hot potato", "chinese": "烫手山芋", "example": "原句...", "tip": "用法提示..."}
  ]
}
```

**重要**：rows 字段名必须用 `"english"` 和 `"chinese"`，不要用 `"en"`/`"zh"` 缩写。

保存到 `~/workflow/handbook_data.json`。

### Step 5: 生成 .docx + PDF（reportlab 直出，不依赖 Word）

```bash
python3 ~/.openclaw/skills/podcast-gen/scripts/gen_handbook.py \
  --input ~/workflow/handbook_data.json \
  --output "~/workflow/{标题}.docx" \
  --pdf-output "~/workflow/{标题}.pdf" \
  --vol-label "Vol. XX" \
  --transcript-input ~/workflow/transcript_data.json \
  --transcript-output "~/workflow/{标题}_逐字稿.docx"
```

PDF 由 `gen_handbook.py` 通过 reportlab 直接生成（PingFang/STHeiti 中文字体，表格 + 页眉 Brain Snacks · Vol. XX + 页码），**不调用 Word / docx2pdf / AppleScript**。

主题色：橙色 #E8601C / 浅橙 #FDE8D8。

### Step 6: 生成小宇宙介绍文案

**文案结构**：
```
{反直觉的事实或问题开头，制造信息落差}

{1-2 段过渡，交代本期内容来源和核心议题}

{要点标题1}：{一句话展开}
{要点标题2}：{一句话展开}
{要点标题3}：{一句话展开}
{要点标题4}：{一句话展开}

{收尾段：升华主题，提出思考问题}
```

**要求**：
- 不用 emoji 和 hashtag，纯文字
- 语气：好奇驱动、有深度但不学术，像和朋友分享一个让你兴奋的发现

### Step 7: 交付

输出所有结果：
```
播客学习资料已处理完成！现在把文件和文案发给你。

双语手册 PDF：{.pdf }
逐字稿：{_逐字稿.docx}

小宇宙文案：
---
{文案内容}
---

需要调整什么地方吗？
```

**要求**：
1. PDF和Word文件必须通过（飞书/Lark）发给用户才算完成交付
2. 如果不满意，就快速响应并调整交付

## 注意事项

- 转录完成后先确认语言和时长，再开始标注
- .docx 依赖 python-docx；PDF 依赖 reportlab（**禁止**走 docx2pdf / Word 路径，已多次卡死）
- 转写使用本地 whisper.cpp，胜算云仅作为 URL 备用
- 所有文件（下载、中间产物、最终交付物）统一保存在 ~/workflow/ 目录
- 如果用户要求修改手册某部分，修改 JSON 后重新生成
- **全程不使用 AskUserQuestion / 卡片 / 选择器；只用编号列表 + 纯文本**

## 变更日志

- 2026-04-21 同步 claude commands 版本：本地 whisper.cpp 转写、~/workflow/ 统一目录、去掉 Groq、简化流程
- 2026-04-20 gen_handbook.py 新增 --pdf-output 用 reportlab 直出 PDF
- 2026-04-20 Step 1 禁用 AskUserQuestion，飞书直接发送音频附件为主流入口
- 2026-04-17 调整流程顺序：先生成完整逐字稿 .docx 供核对，再生成手册和介绍文案
- 2026-04-15 主题色从蓝色改为 Brain Snacks 橙色(#E8601C)
- 2026-04-15 手册输出格式改为 PDF，副标题居中，新增页眉页码
- 2026-04-14 触发词从 /播客生成 改为 /生成学习资料
