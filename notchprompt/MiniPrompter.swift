//
//  MiniPrompter.swift
//  Cueflow (随读)
//
//  F8: Notch "mini" prompter — collapses the overlay to a single line that shows
//  the current sentence, advancing automatically by speed; long sentences pan
//  horizontally (marquee). Independently authored; no third-party code.
//

import SwiftUI

enum SentenceSplitter {
    private static let terminators: Set<Character> = ["。", "！", "？", "!", "?", ".", "；", ";", "\n"]

    /// Split text into display sentences, keeping the trailing punctuation.
    static func sentences(from text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for ch in text {
            if ch == "\n" {
                let t = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { result.append(t) }
                current = ""
                continue
            }
            current.append(ch)
            if terminators.contains(ch) {
                let t = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { result.append(t) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { result.append(tail) }
        return result
    }
}

struct MiniPrompterView: View {
    @ObservedObject var model: PrompterModel
    let fontSize: CGFloat

    @State private var sentences: [String] = []
    @State private var index: Int = 0
    @State private var sentenceElapsed: TimeInterval = 0
    @State private var lastTick: Date?
    @State private var textWidth: CGFloat = 0

    private let hPad: CGFloat = 22
    private static let tick: TimeInterval = 1.0 / 60.0

    private var current: String { sentences.indices.contains(index) ? sentences[index] : "" }

    /// Reading units per second derived from the scroll speed setting.
    private var unitsPerSecond: Double { max(1.5, model.speedPointsPerSecond / 20.0) }

    private var dwell: TimeInterval {
        let units = Double(PrompterModel.readingUnitCount(in: current))
        return max(1.0, units / unitsPerSecond)
    }

    var body: some View {
        GeometryReader { geo in
            let avail = max(1, geo.size.width - hPad * 2)
            TimelineView(.periodic(from: .now, by: Self.tick)) { timeline in
                ZStack {
                    if sentences.isEmpty {
                        Text(LocalizationManager.shared.l(.scrollReady))
                            .font(.system(size: max(13, fontSize * 0.7), design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Text(current)
                            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .fixedSize()
                            .background(widthReader)
                            .frame(width: geo.size.width,
                                   alignment: fits(avail) ? .center : .leading)
                            .offset(x: fits(avail) ? 0 : hPad + marqueeOffset(avail))
                            .clipped()
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .onChange(of: timeline.date) { _, date in advanceTick(at: date) }
            }
            .onAppear { rebuild() }
            .onChange(of: model.script) { _, _ in rebuild() }
            .onChange(of: model.resetToken) { _, _ in index = 0; restartSentence() }
            .onChange(of: model.jumpBackToken) { _, _ in
                index = max(0, index - 1); restartSentence()
            }
            .onChange(of: model.isRunning) { _, _ in lastTick = nil }
        }
    }

    private var widthReader: some View {
        GeometryReader { p in
            Color.clear.preference(key: MiniWidthKey.self, value: p.size.width)
        }
        .onPreferenceChange(MiniWidthKey.self) { textWidth = $0 }
    }

    private func fits(_ avail: CGFloat) -> Bool { textWidth <= avail + 0.5 }

    /// Horizontal pan for overflow sentences: 0 → -(overflow) across the dwell.
    private func marqueeOffset(_ avail: CGFloat) -> CGFloat {
        let overflow = max(0, textWidth - avail)
        guard overflow > 0 else { return 0 }
        // Hold briefly at both ends; pan in the middle of the dwell.
        let progress = min(1, max(0, (sentenceElapsed / dwell - 0.15) / 0.7))
        return -overflow * CGFloat(progress)
    }

    private func rebuild() {
        sentences = SentenceSplitter.sentences(from: model.cueScript.spokenOnly)
        index = min(index, max(0, sentences.count - 1))
        restartSentence()
    }

    private func restartSentence() {
        sentenceElapsed = 0
        lastTick = nil
    }

    private func advanceTick(at date: Date) {
        guard !sentences.isEmpty else { lastTick = date; return }
        guard model.isRunning else { lastTick = date; return }
        let dt = lastTick.map { max(0, min(date.timeIntervalSince($0), 0.25)) } ?? Self.tick
        lastTick = date
        sentenceElapsed += dt

        if sentenceElapsed >= dwell {
            if index < sentences.count - 1 {
                index += 1
                restartSentence()
            } else {
                // Reached the last sentence.
                if model.scrollMode == .infinite {
                    index = 0
                    restartSentence()
                } else {
                    model.markReachedEndInStopMode()
                }
            }
        }
    }
}

private struct MiniWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
