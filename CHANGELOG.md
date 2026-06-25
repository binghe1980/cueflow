# Changelog

All notable changes to CueFlow (随读) are documented here.
This project adheres to [Semantic Versioning](https://semver.org/).

## v1.0.1 — 2026-06-25

✨ **Adds in-app auto-update.**

- **In-app updates via Sparkle** — CueFlow now checks for new versions and can
  install them in place. A **"Check for Updates…"** item is in the menu-bar menu,
  and scheduled background checks are on by default. Updates are EdDSA-signed and
  served over HTTPS.
- Signed with an Apple Developer ID and notarized by Apple (same as v1.0.0).
- No feature changes otherwise — this is the baseline that enables automatic
  updates going forward (versions released after it will update automatically).

## v1.0.0 — 2026-06-21

🎉 **First public release of CueFlow (随读).**

CueFlow is a notch-adjacent macOS teleprompter, built on the open-source
[NotchPrompt](https://github.com/saif0200/notchprompt) (MIT) and extended with a
voice-follow engine, a cue (off-script) mode, and a rebuilt script library.

### Added

- **Voice-follow auto-scroll** — on-device speech recognition scrolls the prompt
  to where you are actually reading. Supports Chinese, English, and mixed zh+en
  (the latter via bundled offline WhisperKit). Includes fuzzy/phonetic alignment,
  pixel-smooth scrolling, and an adjustable notch-follow height.
- **Cue mode (随讲)** — outline-driven, off-script presenting: attach data,
  examples, quotes, and reminders to each outline point and jump between them
  with hotkeys (`1–9`, `⌥⌘.` / `⌥⌘,`).
- **Rebuilt script library** — one document, multiple reading modes; manage and
  switch between scripts (`⌥⌘]` / `⌥⌘[`), import/export plain text.
- **Bilingual UI** — Simplified Chinese and English, switchable at runtime.
- **Screen-share privacy mode** (`⌥⌘H`) — hide the prompter from your audience
  while recording or sharing (best-effort, app-dependent).
- **Draggable floating overlay** with independent position and size.
- **Bundled offline speech model** so voice-follow works with no internet.

### Carried over from NotchPrompt

- Auto-scroll with adjustable speed/font/width/height and optional countdown.
- Global hotkeys via Carbon system hotkeys (reliable across apps).
- Multi-display handling with sensible defaults and fallback.

### Notes

- This build is **signed with an Apple Developer ID and notarized by Apple**, so
  it opens with a normal double-click (no Gatekeeper prompt).
- Requires **macOS 14.0+**. The WhisperKit mixed-language mode is best on
  Apple Silicon.
