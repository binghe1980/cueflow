//
//  VoiceFollowTestView.swift
//  Cueflow (随读)
//
//  F3 spike UI: read the script aloud and watch the current line highlight and
//  auto-scroll. Validates Apple-speech + AlignmentEngine tracking before the
//  full in-prompter integration (which needs the TextKit2 render refactor).
//

import AppKit
import SwiftUI

struct VoiceFollowTestView: View {
    @ObservedObject private var model = PrompterModel.shared
    @ObservedObject private var lm = LocalizationManager.shared
    @ObservedObject private var vf = VoiceFollowController.shared

    @State private var script: String = ""
    @State private var localeID: String = "zh-CN"

    var body: some View {
        VStack(spacing: 10) {
            toolbar
            Divider()
            scriptArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            statusArea
        }
        .padding(12)
        .frame(minWidth: 640, minHeight: 520)
        .onAppear { if script.isEmpty { script = model.script } }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Picker(lm.l(.vfLanguage), selection: $localeID) {
                Text(lm.l(.vfLangZh)).tag("zh-CN")
                Text(lm.l(.vfLangEn)).tag("en-US")
                Text(lm.l(.vfLangMixed)).tag("whisper")
            }
            .pickerStyle(.segmented)
            .frame(width: 320)
            .labelsHidden()
            .disabled(vf.isListening)

            Button(lm.l(.vfReloadScript)) { script = model.script }
                .disabled(vf.isListening)

            Spacer()

            if vf.isListening {
                Button(lm.l(.vfStop)) { vf.stop() }
            } else {
                Button(lm.l(.vfStart)) {
                    Task { await vf.start(scriptText: script, localeID: localeID, useWhisper: localeID == "whisper") }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    @ViewBuilder
    private var scriptArea: some View {
        if vf.isListening {
            followView
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(lm.l(.vfHint))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                TextEditor(text: $script)
                    .font(.system(size: 15))
            }
        }
    }

    private var followView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(vf.lines.enumerated()), id: \.offset) { idx, _ in
                        Text(attributedLine(idx))
                            .font(.system(size: 22, weight: idx == vf.displayLineIndex ? .semibold : .regular))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(idx)
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: vf.displayLineIndex) { _, line in
                withAnimation(.easeInOut(duration: 0.45)) {
                    proxy.scrollTo(line, anchor: .center)
                }
            }
        }
    }

    private func attributedLine(_ idx: Int) -> AttributedString {
        voiceWaveAttributed(line: vf.lines[idx], lineStart: vf.lineStartOffset(idx), lead: vf.displayCharOffset)
    }

    private var statusArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(vf.isListening ? Color.red : Color.secondary)
                    .frame(width: 8, height: 8)
                Text(vf.status.isEmpty ? lm.l(.vfReady) : vf.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 8)
            }

            // Live mic level — confirms the app is actually receiving audio.
            HStack(spacing: 6) {
                Image(systemName: "mic.fill")
                    .font(.caption2)
                    .foregroundStyle(vf.audioLevel > 0.03 ? Color.green : Color.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.2))
                        Capsule()
                            .fill(Color.green)
                            .frame(width: max(2, CGFloat(min(vf.audioLevel, 1)) * geo.size.width))
                    }
                }
                .frame(height: 6)
            }

            if !vf.recognizedText.isEmpty {
                Text("\(lm.l(.vfHeard))：\(vf.recognizedText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !vf.hint.isEmpty {
                Text(vf.hint)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
final class VoiceFollowWindowController: NSWindowController {
    init() {
        let hosting = NSHostingController(rootView: VoiceFollowTestView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L(.vfWindowTitle)
        window.contentViewController = hosting
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 640, height: 520)
        window.level = NSWindow.Level(Int(NSWindow.Level.screenSaver.rawValue) + 1)
        window.setFrameAutosaveName("CueflowVoiceFollowWindow")
        window.setFrame(NSRect(x: 0, y: 0, width: 720, height: 640), display: false)
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}

// MARK: - Shared voice-follow rendering

/// Flowing highlight: unread text bright (what to read next), a short green wave
/// trails the smoothed leading edge, older read text dimmed.
func voiceWaveAttributed(line: String, lineStart: Int, lead: Double, band: Double = 6) -> AttributedString {
    if line.isEmpty { return AttributedString(" ") }
    var result = AttributedString()
    for (k, ch) in line.enumerated() {
        let g = Double(lineStart + k)
        let d = lead - g
        var piece = AttributedString(String(ch))
        if d < 0 {
            piece.foregroundColor = .primary
        } else if d <= band {
            piece.foregroundColor = Color.green.opacity(1.0 - 0.55 * (d / band))
        } else {
            piece.foregroundColor = .secondary
        }
        result += piece
    }
    return result
}

/// Voice-follow content rendered inside the real prompter windows (notch + floating).
/// Multi-line view: the current line is kept near the top reading line (so upcoming
/// lines stay visible below) with smooth eased scrolling + the flowing wave highlight.
struct FollowingPrompterView: View {
    @ObservedObject var vf: VoiceFollowController
    var fontSize: CGFloat = 26
    /// Vertical position (fraction from top) where the current line sits.
    var anchorFraction: CGFloat = 0.30

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: fontSize * 0.5) {
                    ForEach(Array(vf.lines.enumerated()), id: \.offset) { idx, _ in
                        Text(voiceWaveAttributed(line: vf.lines[idx],
                                                 lineStart: vf.lineStartOffset(idx),
                                                 lead: vf.displayCharOffset))
                            .font(.system(size: fontSize, weight: idx == vf.displayLineIndex ? .semibold : .regular))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(idx)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 400)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .onChange(of: vf.displayLineIndex) { _, line in
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(line, anchor: UnitPoint(x: 0.5, y: anchorFraction))
                }
            }
            .onChange(of: vf.isListening) { _, listening in
                if listening {
                    proxy.scrollTo(vf.displayLineIndex, anchor: UnitPoint(x: 0.5, y: anchorFraction))
                }
            }
        }
    }
}
