<div align="center">

<img src="assets/icon.png?v=20260622" alt="CueFlow" width="120" />

# CueFlow · 随读

**A Mac teleprompter that hugs the notch — and *listens* as you read, scrolling to follow you**

[![License](https://img.shields.io/badge/license-MIT-22c55e.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-v1.0.0-3b82f6.svg)](CHANGELOG.md)
[![Platform](https://img.shields.io/badge/macOS-14%2B-111827.svg?logo=apple&logoColor=white)](#requirements)
[![Chip](https://img.shields.io/badge/Apple%20Silicon%20%26%20Intel-supported-f59e0b.svg)](#requirements)
[![Website](https://img.shields.io/badge/Website-cueflow.flowlab.im-16a34a.svg)](https://cueflow.flowlab.im/)

**🌐 Official site · [cueflow.flowlab.im](https://cueflow.flowlab.im/)** &nbsp;|&nbsp; [简体中文](README.md) &nbsp;·&nbsp; **🌏 English**

</div>

---

> CueFlow (Chinese name **随读**, "read-along") is a menu-bar macOS teleprompter. It places the prompt right next to your camera/notch so you can **look at the lens** while reading — and it can use on-device speech recognition to **scroll exactly to where you are reading**, instead of guessing a constant speed.

## ✨ Features

- **🎯 Notch-adjacent prompting** — the overlay sits near the camera, so your eyes barely leave the lens.
- **Three reading modes**
  - **Auto-scroll** — constant speed with adjustable speed / font size / width / height / countdown.
  - **Voice-follow** — on-device speech recognition scrolls to where you are reading; supports Chinese, English, and mixed zh+en.
  - **Cue mode (outline cards)** — for speaking off-script: attach data, examples, quotes, and reminders to each outline point and hop between them with hotkeys.
- **📚 Script library** — manage multiple scripts, import/export plain text, switch in one tap.
- **🕶️ Screen-share privacy** — hide the prompter from your audience while recording or sharing your screen (best-effort, app-dependent).
- **🪟 Draggable floating window** — place and size the prompt wherever you like.
- **⌨️ Global hotkeys** — start/pause, change speed, and jump without switching windows.
- **🌐 Bilingual UI (中/EN)**, lives quietly in the menu bar.

## 🖼️ Screenshots

> Screenshots coming soon — try it out and share your setup in an Issue.

<!-- Drop 1–2 real screenshots or a demo GIF here, e.g.:
![CueFlow overlay](assets/screenshot-main.png)
![Voice-follow demo](assets/voice-follow.gif)
-->

## 💻 Requirements

- **macOS 14.0 (Sonoma) or later**
- Apple Silicon or Intel Mac
- **Voice-follow**:
  - "Chinese / English" mode uses the built-in macOS speech recognizer (works on both Apple Silicon and Intel);
  - "Mixed zh+en (WhisperKit)" runs fully on-device and is **recommended on Apple Silicon** for best speed and accuracy.

## 📥 Download & Install

1. Open the [Releases page](https://github.com/binghe1980/cueflow/releases) and download the latest `CueFlow-v1.0.0-macos.dmg`.
2. Open the DMG and drag **CueFlow** into your **Applications** folder.
3. Launch CueFlow from Launchpad/Applications — its icon appears in the menu bar.

> 📦 The download is ~135 MB because the offline speech model is bundled, so voice-follow works **without an internet connection**.

### ✅ First launch

CueFlow is **signed with an Apple Developer ID** and **notarized by Apple**, so it **opens with a normal double-click** — no "unidentified developer" or "damaged" prompts.

> Want to confirm the download is intact? Compare the SHA-256 in "Verify the file" below.

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
| --- | --- |
| `⌥⌘P` | Start / Pause scrolling |
| `⌥⌘R` | Reset to top |
| `⌥⌘J` | Jump back 5 seconds |
| `⌥⌘O` | Show / Hide the prompter window |
| `⌥⌘H` | Toggle screen-share privacy mode |
| `⌥⌘=` / `⌥⌘-` | Speed up / down |
| `⌥⌘G` | Enter / Exit cue mode |
| `⌥⌘.` / `⌥⌘,` | Cue mode: next / previous outline point |
| `⌥⌘L` | Cue mode: outline overview / return |
| `⌥⌘]` / `⌥⌘[` | Switch to next / previous script |

> In cue mode, press number keys `1–9` to jump straight to an outline point.
> If a shortcut is already taken by another app, the menu bar will warn you.

## 🔒 Privacy

CueFlow keeps your reading on your own machine as much as possible:

- **WhisperKit mixed zh+en mode is 100% on-device offline** — audio never leaves your Mac.
- **Chinese / English mode** prefers the **on-device** macOS recognizer; if your Mac lacks on-device recognition for the selected language, macOS may **fall back to Apple's speech servers** (the UI shows "cloud" in that case), governed by **Apple's speech & privacy policy**.
- **CueFlow itself never uploads, stores, or forwards your audio, and contains no third-party analytics, tracking, or ad SDKs.**
- The app's network entitlement is used only to download the speech model from Hugging Face on demand when no bundled model is present (release builds already include the model, so this normally isn't needed).

## 🛠️ Build from Source

```bash
git clone https://github.com/binghe1980/cueflow.git
cd cueflow

# Fetch the offline speech model (~144MB, not stored in Git)
./scripts/fetch_whisper_model.sh base

# Open in Xcode
open notchprompt.xcodeproj
```

Build a local DMG from the command line (ad-hoc signed, for your own testing):

```bash
./scripts/build_release_zip.sh v1.0.0
# Output: dist/CueFlow-v1.0.0-macos.dmg
```

The official release is built with Developer ID signing + Apple notarization (requires a certificate and notary credentials):

```bash
./scripts/sign_notarize_release.sh v1.0.0
```

## ✅ Verify the file (optional)

After downloading, check the SHA-256 to confirm the file is intact and untampered:

```bash
shasum -a 256 ~/Downloads/CueFlow-v1.0.0-macos.dmg
```

> Each Release lists the official SHA-256 — if it matches, you're good to install.

## 🙏 Credits & License

CueFlow is built on top of these open-source projects — thank you:

- **[NotchPrompt](https://github.com/saif0200/notchprompt)** by Saif — the base project, MIT.
- **[WhisperKit](https://github.com/argmaxinc/WhisperKit)** by Argmax — on-device speech recognition, MIT.
- **[swift-transformers](https://github.com/huggingface/swift-transformers)** by Hugging Face — Apache-2.0.
- **[swift-argument-parser](https://github.com/apple/swift-argument-parser)** by Apple — Apache-2.0.
- **[Whisper](https://github.com/openai/whisper)** by OpenAI — the bundled offline model, MIT.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the full third-party license list.

This project is released under the **MIT License** — see [LICENSE](LICENSE). You're free to use, modify, and distribute it; just keep the copyright and license notices.

---

<div align="center">
<sub>CueFlow · 随读 — v1.0.0, the first public release · Made with ❤️ for creators</sub>
</div>
