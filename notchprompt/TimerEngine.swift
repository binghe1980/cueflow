//
//  TimerEngine.swift
//  Cueflow (随读)
//
//  F6-C: Lightweight rehearsal timer. Tracks elapsed prompting time at ~4Hz,
//  pauses/resumes with the scroll/voice session, and reports the finished
//  duration to the stats store. Display + countdown formatting live in TimerBadge.
//  Independently authored; no third-party code.
//

import SwiftUI
import AppKit
import Combine

@MainActor
final class TimerEngine: ObservableObject {
    static let shared = TimerEngine()

    /// Seconds elapsed in the current prompting session (accumulates across pauses).
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var isTicking: Bool = false

    private var base: TimeInterval = 0
    private var runStart: Date?
    private var ticker: AnyCancellable?

    private init() {}

    private func computeElapsed() -> TimeInterval {
        if let runStart { return base + Date().timeIntervalSince(runStart) }
        return base
    }

    /// Begin/continue counting (idempotent).
    func resume() {
        guard !isTicking else { return }
        runStart = Date()
        isTicking = true
        ticker = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.elapsed = self.computeElapsed()
            }
        elapsed = computeElapsed()
    }

    /// Stop counting but keep the accumulated time.
    func pause() {
        guard isTicking else { return }
        base = computeElapsed()
        runStart = nil
        isTicking = false
        ticker?.cancel()
        ticker = nil
        elapsed = base
    }

    /// Reset back to zero. Keeps ticking if it was already running (fresh restart).
    func reset() {
        base = 0
        runStart = isTicking ? Date() : nil
        elapsed = 0
    }

    /// Total seconds accumulated so far (live).
    var currentSeconds: Int { Int(computeElapsed().rounded()) }
}

// MARK: - On-overlay timer badge

/// Compact, non-interactive timer chip shown in a corner of the overlay /
/// floating window. Respects `model.timerMode`. Fires a haptic (no sound) when a
/// countdown target is reached.
struct TimerBadge: View {
    @ObservedObject var model: PrompterModel
    @ObservedObject private var timer = TimerEngine.shared
    @ObservedObject private var lm = LocalizationManager.shared
    @State private var firedTargetHaptic = false

    var body: some View {
        Group {
            if model.timerMode != .off && model.hasStartedSession && !model.isCountingDown {
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let reached = isTargetReached
        HStack(spacing: 5) {
            Image(systemName: glyph)
                .font(.system(size: 9, weight: .semibold))
            Text(displayText)
                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
            if reached {
                Text(lm.l(.timerReachedTarget)).font(.system(size: 10, weight: .bold))
            }
        }
        .foregroundStyle(reached ? Color.white : Color.white.opacity(0.92))
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        // Keep the "time's up" red translucent so scrolling text stays visible.
        .background((reached ? Color.red.opacity(0.42) : Color.black.opacity(0.62)), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(reached ? 0.3 : 0.14), lineWidth: 1))
        .onChange(of: timer.elapsed) { _, _ in
            if isTargetReached {
                if !firedTargetHaptic {
                    firedTargetHaptic = true
                    // Visual + haptic only — never plays a sound (live/recording safe).
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                }
            } else {
                firedTargetHaptic = false
            }
        }
    }

    private var glyph: String {
        switch model.timerMode {
        case .countDown: return "timer"
        case .remaining: return "hourglass"
        default: return "stopwatch"
        }
    }

    private var isTargetReached: Bool {
        model.timerMode == .countDown && timer.currentSeconds >= model.timerTargetSeconds
    }

    private var displayText: String {
        switch model.timerMode {
        case .off:
            return ""
        case .countUp:
            return TimeFormat.clock(timer.currentSeconds)
        case .countDown:
            let remaining = model.timerTargetSeconds - timer.currentSeconds
            if remaining >= 0 { return TimeFormat.clock(remaining) }
            return "+" + TimeFormat.clock(-remaining)   // overrun
        case .remaining:
            let est = Int(model.estimatedReadDuration.rounded()) - timer.currentSeconds
            return TimeFormat.clock(max(0, est))
        }
    }
}
