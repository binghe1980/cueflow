<div align="center">

<img src="assets/icon.png?v=20260622" alt="CueFlow" width="120" />

# CueFlow · 随读

**贴着刘海的 Mac 提词器 —— 会"听"你朗读、自动跟随滚动**

[![License](https://img.shields.io/badge/license-MIT-22c55e.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-v1.1.0-3b82f6.svg)](CHANGELOG.md)
[![Platform](https://img.shields.io/badge/macOS-14%2B-111827.svg?logo=apple&logoColor=white)](#系统要求)
[![Chip](https://img.shields.io/badge/Apple%20Silicon%20%26%20Intel-supported-f59e0b.svg)](#系统要求)
[![Website](https://img.shields.io/badge/官方网站-cueflow.flowlab.im-16a34a.svg)](https://cueflow.flowlab.im/)

**官方网站 · [cueflow.flowlab.im](https://cueflow.flowlab.im/)** &nbsp;|&nbsp; **简体中文** &nbsp;·&nbsp; [English](README.en.md)

</div>

---

> CueFlow（中文名「随读」）是一款常驻菜单栏的 macOS 提词器。它把提词条贴在屏幕顶部刘海/摄像头附近，让你**看着镜头**也能读稿；并且能用本机语音识别**听你读到哪、就滚到哪**，告别匀速滚动对不上节奏的尴尬。

## 主要功能

### 提词与朗读

- **刘海贴合提词**：提词浮层贴近摄像头，视线几乎不离开镜头，出镜更自然。
- **三种朗读模式**
  - **自动播放** —— 匀速滚动，速度 / 字号 / 宽度 / 高度 / 倒计时均可调。
  - **语音跟随** —— 本机语音识别，你读到哪它滚到哪；支持中文、英文、中英混读。
  - **随讲模式（大纲卡片）** —— 脱稿即兴用：给每个大纲点挂数据、案例、金句、提醒，用热键在要点间跳转。
- **留海迷你提词**（v1.1）：把刘海折叠成一行、放大显示**当前句**，按速度自动逐句推进，长句横向滚动读完 —— 扫一眼即可，进一步降低"读提词"痕迹。

### 操作与效率

- **触控板手势翻页**（v1.1）：鼠标悬停提词浮层即可双指操作 —— 普通模式横滑调速、纵滑滚动；随讲模式横滑跳段、纵滑翻看素材。
- **计时与排练统计**（v1.1）：浮层内置计时条（正计时 / 倒计时 / 预计剩余）；菜单栏「排练统计」记录每次时长、字数、平均语速与完成度，全部存在本机、不上传。
- **全局快捷键**：不切换窗口也能开始 / 暂停 / 调速 / 跳转。

### 界面与隐私

- **可视化设置中心**（v1.1）：分类侧栏 + 分组卡片，外观设置支持实时预览，并可选择动效风格。
- **屏幕共享隐身**：录屏或共享屏幕时，把提词器对观众隐藏（尽力而为，取决于具体 App）。
- **独立可拖拽浮窗**：自由摆放提词窗口位置与大小。
- **中英双语界面**，常驻菜单栏，轻量不打扰。

## 界面预览

> 截图待补充。下载试用后欢迎在 Issue 里分享你的使用场景。

<!-- 在这里放 1–2 张实际截图或一段演示 GIF，例如：
![CueFlow 主界面](assets/screenshot-main.png)
![语音跟随演示](assets/voice-follow.gif)
-->

## 系统要求

- **macOS 14.0（Sonoma）或更高版本**
- Apple Silicon 或 Intel Mac 均可运行
- **语音跟随**：
  - 「中文 / 英文」模式使用 macOS 内置语音识别，Apple Silicon 与 Intel 都可用；
  - 「中英混读（WhisperKit）」为本机离线识别，**推荐 Apple Silicon**，效果与速度更佳。

## 下载与安装

1. 打开 [Releases 页面](https://github.com/binghe1980/cueflow/releases)，下载最新的 `CueFlow-v1.1.0-macos.dmg`。
2. 双击打开 DMG，把 **CueFlow** 拖到 **应用程序（Applications）** 文件夹。
3. 从「启动台 / 应用程序」打开 CueFlow，菜单栏会出现它的图标。

> 安装包约 135 MB，因为内置了离线语音模型，下载后**无需联网**即可使用语音跟随。
>
> 已发布版本支持**软件内自动更新**：有新版时会在 App 内提示，一键升级。

### 首次打开

CueFlow 已使用 **Apple Developer ID 签名**并通过 **Apple 公证（notarization）**，**双击即可正常打开**，不会再出现"无法验证开发者""已损坏"之类的拦截。

> 想确认下载完整性，可对照每个 Release 页面附带的 SHA-256。

## 键盘快捷键

| 快捷键 | 功能 |
| --- | --- |
| `⌥⌘P` | 开始 / 暂停滚动 |
| `⌥⌘R` | 回到开头 |
| `⌥⌘J` | 后退 5 秒 |
| `⌥⌘O` | 显示 / 隐藏提词浮窗 |
| `⌥⌘H` | 屏幕共享隐身（隐私模式）开关 |
| `⌥⌘=` / `⌥⌘-` | 加速 / 减速 |
| `⌥⌘G` | 进入 / 退出随讲模式 |
| `⌥⌘.` / `⌥⌘,` | 随讲：下一个 / 上一个大纲点 |
| `⌥⌘L` | 随讲：大纲总览 / 返回 |
| `⌥⌘]` / `⌥⌘[` | 切换到下一份 / 上一份脚本 |

> 以上 `⌥⌘` 组合键始终可用，且不影响在其它 App 里打字。
>
> 空格、方向键、数字键 `1–9` 等**裸键控制**（暂停、调速、跳点）属于演示用的「免提快捷键」，默认关闭；需要时在「设置 → 快捷键」中开启。开启后这些键会被全局占用，仅建议在录制 / 演示时使用。

## 隐私说明

CueFlow 把"读稿这件事"尽量留在你的电脑里：

- **WhisperKit 中英混读模式：100% 本机离线**，音频不出本机。
- **中文 / 英文模式**：优先使用 macOS **本机语音识别**；如果你的 Mac 不支持所选语言的本机识别，macOS 可能会**回落到苹果云端识别**（此时界面会标注「云端」）。这部分由 **Apple 的语音识别与隐私政策**管辖。
- **排练统计**等使用数据仅保存在本机，不上传。
- **CueFlow 自身不会上传、保存或转发你的音频，也没有任何第三方统计、埋点或广告 SDK。**
- App 请求的网络权限仅用于：当本机没有内置模型时，按需从 Hugging Face 下载语音模型（发行版已内置模型，正常情况下用不到）；以及检查软件更新。

## 从源码构建

```bash
git clone https://github.com/binghe1980/cueflow.git
cd cueflow

# 拉取离线语音模型（约 144MB，未纳入 Git 仓库）
./scripts/fetch_whisper_model.sh base

# 用 Xcode 打开
open notchprompt.xcodeproj
```

命令行打包本地 DMG（ad-hoc 签名，供本机自测）：

```bash
./scripts/build_release_zip.sh v1.1.0
# 产物：dist/CueFlow-v1.1.0-macos.dmg
```

正式发行版用 Developer ID 签名 + Apple 公证打包（需配好证书与公证凭据）：

```bash
./scripts/sign_notarize_release.sh v1.1.0
```

## 校验文件（可选）

下载后可核对 SHA-256，确认文件完整、未被篡改：

```bash
shasum -a 256 ~/Downloads/CueFlow-v1.1.0-macos.dmg
```

> 每个 Release 页面会附上官方 SHA-256 值，比对一致即可放心安装。

## 致谢与开源协议

CueFlow 基于以下开源项目构建，谨致谢意：

- **[NotchPrompt](https://github.com/saif0200/notchprompt)** by Saif —— 本项目的基线，MIT 协议。
- **[WhisperKit](https://github.com/argmaxinc/WhisperKit)** by Argmax —— 本机语音识别，MIT 协议。
- **[swift-transformers](https://github.com/huggingface/swift-transformers)** by Hugging Face —— Apache-2.0。
- **[swift-argument-parser](https://github.com/apple/swift-argument-parser)** by Apple —— Apache-2.0。
- **[Whisper](https://github.com/openai/whisper)** by OpenAI —— 内置离线语音模型，MIT 协议。

完整的第三方许可清单见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

本项目以 **MIT 协议**开源，详见 [LICENSE](LICENSE)。你可以自由使用、修改、分发，只需保留版权与许可声明。

---

<div align="center">
<sub>CueFlow · 随读 — v1.1.0 · 为中文创作者打造</sub>
</div>
