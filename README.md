<div align="center">

<img src="skills/ispeak-personal-speaking/assets/readme-banner.svg" width="100%" alt="iSpeak：雅思口语和语法，打包一起练。">

# 你的故事，就是你的口语教材。

**让 AI 把真实经历写进口语与语法练习，再生成你的专属 iPhone App。**

<a href="https://github.com/ChoneyChen/ispeak/releases/latest/download/ispeak-personal-speaking.zip"><img src="skills/ispeak-personal-speaking/assets/skill-download.svg" width="210" height="48" alt="下载 Skill · 免费开源"></a>

[官网](https://choneychen.github.io/ispeak/) · [直接使用通用版](https://choneychen.github.io/ispeak/app/)

**28 个口语话题　 /　 140 个语法点　 /　 700 张中英句卡**

</div>

---

## 把语法，用在你真正想讲的话里

| 口语场景 | 表达目标 | 一起练的语法 |
| :--- | :--- | :--- |
| **Part 1 · 日常问答** | 我的习惯、家乡、学习和工作 | 现在时、频率副词、比较级、原因从句 |
| **Part 2 · 讲述经历** | 事情经过、感受与反思 | 过去时、过去完成时、定语从句、条件句 |
| **Part 3 · 表达观点** | 原因、影响和不同角度 | 让步从句、情态动词、对比与因果 |

> **一条经历，变成一句能开口的英语。** 以下是虚构示例。
>
> 我组织过一次分享，没提前检查设备，当时有点慌。
>
> **If I’d checked** the equipment earlier, **I would have felt** more relaxed.
>
> 如果我早点检查设备，当时就会更从容。
>
> 用第三条件句反思过去，再换成你自己故事中的细节，练习连贯作答。

## 每天几句，慢慢记牢

**先学，再背。** 学习仍然一次一句，上半看语法、下半读例句，向左滑进入下一句。完成一节后，才解锁对应的中文回忆练习。

| 这次更新 | 你怎么用 |
| :--- | :--- |
| **每日计划** | 自己设定新学与复习目标，默认新学 10 句、复习 30 句；达到目标后仍可继续学习 |
| **新旧混合** | 新解锁的句子和到期旧句交替出现，也可选择先复习 |
| **难句加强** | 背错后，隔开其他句子或稍等一会儿，完成两次回忆；不会刚看完答案就算记住 |
| **按反馈安排复习** | 正确则逐步拉长间隔；有点难则更快回来；逾期内容保留 |
| **按时提醒** | 原生 iPhone 版可自选开启本地提醒，通知不展示私人例句 |
| **确定会了，就斩** | 永久移出自动背诵，仍能在句库查阅 |

普通句卡尽量一屏读完，主要按钮固定在底部；长句和大字号保留必要的阅读空间。旧版学习进度、已斩和已完成记录保留，升级前自动备份旧进度。

## 更推荐：用 Skill 做个人专用版

你提供自己的身份、兴趣和几段真实经历，AI 沿着共享课程框架生成：

**个性化双语句库 → 配套教材 → 能学习、背诵和复习的 iPhone App。**

**① [下载 Skill](https://github.com/ChoneyChen/ispeak/releases/latest/download/ispeak-personal-speaking.zip)**，解压并进入 `ispeak-personal-speaking` 文件夹，运行：

```sh
python3 scripts/install_skill.py
```

安装到当前用户的 Codex skills 目录；已有同名技能时会停止，避免覆盖。其他支持本地 Skill 的 AI 工具，可按其规则导入技能文件夹。

**② 新开一个聊天，告诉 AI 你的经历：**

```text
使用 $ispeak-personal-speaking。

我正在准备雅思口语。
我的身份是……平时喜欢……
我想讲的几段真实经历是……

请把口语话题和语法打包一起练，
生成我的个性化句库、双语教材，
以及能学习、背诵和复习的 iPhone App。
```

不必手写 700 句，也可以先做一个小单元或只生成教材。AI 会整理事实、写作和检查，再完成教材与应用；原生安装需要 **Mac、Xcode 和自己的 Apple 签名**。

## 也可以直接使用通用版

**[打开 / 安装通用版 →](https://choneychen.github.io/ispeak/app/)**

700 句通用情境，打开就能练。在 iPhone 的 Safari 中打开，分享 → 添加到主屏幕；首次在线打开以缓存内容，之后可离线练习。第一人称设定均为练习场景，想练自己的故事更推荐个人版。

[通用版 PDF 教材](https://github.com/ChoneyChen/ispeak/releases/latest/download/iSpeak-General-Guide.pdf) · [原生通用版源码](https://github.com/ChoneyChen/ispeak/releases/latest/download/ispeak-general-ios-source.zip)

<details>
<summary><b>想进一步了解框架和开发方式？</b></summary>

内容与应用分离：结构化句库同时驱动教材与原生应用，每位学习者复用同一套界面、学习引擎和本机存储。应用运行时不调用模型 API，不需要后台登录。

[Skill 指令](skills/ispeak-personal-speaking/SKILL.md) · [内容与事实规则](skills/ispeak-personal-speaking/references/profile-and-content.md) · [应用架构](skills/ispeak-personal-speaking/references/ios-architecture.md) · [复习规则与设计依据](skills/ispeak-personal-speaking/references/recall-design.md) · [验证方法](skills/ispeak-personal-speaking/references/delivery-and-qa.md)

官网由 GitHub Pages 发布，`docs/app` 为离线通用版，`skills/` 为可独立安装和打包的完整技能。原生版本提供源码，目前没有 App Store / TestFlight 或共享签名 IPA。

</details>

---

<div align="center">

**口语和语法，打包一起练。把句子，说成自己的。**

[下载 Skill](https://github.com/ChoneyChen/ispeak/releases/latest/download/ispeak-personal-speaking.zip) · [打开通用版](https://choneychen.github.io/ispeak/app/) · [MIT License](LICENSE)

</div>

<sub>独立开源学习项目，非 IELTS 官方题库，不承诺分数。代码与通用资源使用 MIT 许可。公开包不含原作者的私人画像、PDF、句库或签名；你的个性化产物仍可能包含个人经历，使用框架不会自动将其公开。</sub>
