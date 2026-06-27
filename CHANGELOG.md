# Changelog

All notable changes to CueFlow (随读) are documented here.
This project adheres to [Semantic Versioning](https://semver.org/).

## v1.1.0 — 2026-06-27

Experience upgrade: a visual settings center, timing & rehearsal stats, trackpad
gestures, and a single-line mini prompter in the notch.

### Added

- **Visual settings center** — a categorized sidebar with grouped cards, a live
  appearance preview, and selectable motion styles (Standard / Brisk / Minimal,
  honoring the system "Reduce Motion" setting).
- **Timer** — an in-overlay timer with count-up, count-down (to a target), and
  estimated-remaining modes. The target alert is visual + haptic only (no sound),
  so it is safe while recording.
- **Rehearsal stats** — a menu-bar "Rehearsal Stats" window recording each
  session's duration, word count, average pace, and completion. Stored locally;
  never uploaded. A per-session summary card shows after finishing (toggleable).
- **Trackpad gesture paging** — hover the overlay and use two fingers: normal
  mode swipes change speed (horizontal) and scroll (vertical); cue mode swipes
  change outline point (horizontal) and browse materials (vertical). Toggleable.
- **Mini prompter in the notch** — collapse the notch to one line showing the
  current sentence, auto-advancing by speed, with long sentences panning
  horizontally.

### Fixed

- The app no longer captures bare keys (Space / arrows / number keys) globally by
  default, which previously could block typing in other apps while CueFlow was
  open. These presenting-oriented keys now live behind a **"hands-free keys"**
  toggle (off by default) in Settings → Shortcuts. The `⌥⌘` chords are unaffected.
- The timer "time's up" indicator is now translucent so it no longer obscures the
  scrolling text behind it.

### Notes

- Signed with an Apple Developer ID and notarized by Apple. Existing v1.0.1 users
  receive this update automatically via Sparkle.

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
