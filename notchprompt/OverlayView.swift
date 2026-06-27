//
//  OverlayView.swift
//  notchprompt
//
//  Created by Saif on 2026-02-08.
//

import AppKit
import SwiftUI

private extension Color {
    /// `#000000` (darkest black for seamless notch blending)
    static let notchBlack = Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1.0)
}

/// Notch overlay sizing. While voice-following (or in 随讲/cue mode), the notch
/// grows so the reader can see upcoming lines / the full outline point.
enum NotchLayout {
    static func height(base: Double,
                       voiceActive: Bool,
                       voiceHeight: Double,
                       cueActive: Bool = false,
                       cueHeight: Double = 300) -> CGFloat {
        if voiceActive { return Swift.max(CGFloat(base), CGFloat(voiceHeight)) }
        if cueActive { return Swift.max(CGFloat(base), CGFloat(cueHeight)) }
        return CGFloat(base)
    }
}

/// MacBook-style notch contour:
/// - flat top edge with square top corners
/// - straight side walls
/// - rounded lower corners
private struct AppleNotchShape: InsettableShape {
    /// Lower corner radius relative to height.
    var bottomCornerRadiusRatio: CGFloat = 0.18
    /// Portion of total height used by the straight side wall.
    var sideWallDepthRatio: CGFloat = 0.82
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard r.width > 0, r.height > 0 else { return Path() }

        let w = r.width
        let h = r.height

        // sideWallDepthRatio controls how much vertical wall exists before lower arcs.
        let depthRatio = max(0.60, min(sideWallDepthRatio, 0.95))
        let lowerArcStartY = r.minY + (h * depthRatio)
        let maxBottomRadiusFromDepth = max(0, r.maxY - lowerArcStartY)
        let maxBottomRadiusFromWidth = w * 0.5
        let targetBottomRadius = h * bottomCornerRadiusRatio
        let bottomRadius = max(
            0,
            min(targetBottomRadius, min(maxBottomRadiusFromDepth, maxBottomRadiusFromWidth))
        )

        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))

        // Right side wall into large lower corner.
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - bottomRadius))
        if bottomRadius > 0 {
            p.addArc(
                center: CGPoint(x: r.maxX - bottomRadius, y: r.maxY - bottomRadius),
                radius: bottomRadius,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
        } else {
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        }

        p.addLine(to: CGPoint(x: r.minX + bottomRadius, y: r.maxY))
        if bottomRadius > 0 {
            p.addArc(
                center: CGPoint(x: r.minX + bottomRadius, y: r.maxY - bottomRadius),
                radius: bottomRadius,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
        } else {
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        }

        p.addLine(to: CGPoint(x: r.minX, y: r.minY))
        p.closeSubpath()

        return p
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var s = self
        s.insetAmount += amount
        return s
    }
}

struct OverlayView: View {
    @ObservedObject var model: PrompterModel
    @ObservedObject private var vf = VoiceFollowController.shared

    var body: some View {
        // Ratio-driven contour tuned to Apple notch geometry and scaled to the
        // current overlay dimensions.
        let shape = AppleNotchShape()
        let hideTopStrokeHeight: CGFloat = 2

        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .clipShape(shape)
                // Blur can brighten the surface; keep it effectively off for notch matching.
                .opacity(0.0)

            shape
                .fill(Color(.sRGB, red: 0, green: 0, blue: 0, opacity: model.backgroundOpacity))

            shape
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                // Hard-cut the stroke off at the very top so the edge blends into the notch.
                .mask(
                    VStack(spacing: 0) {
                        Color.clear.frame(height: hideTopStrokeHeight)
                        Color.white
                    }
                )

            // The scroller is hard-clipped (so text truly "cuts off") and we add
            // subtle blur bands at the top/bottom to soften the exit.
            Group {
                if vf.isListening {
                    // Anchor the reading line high so the grown notch shows upcoming lines below.
                    FollowingPrompterView(vf: vf, fontSize: CGFloat(model.fontSize), anchorFraction: 0.20)
                } else if model.readingMode == .cue {
                    CueCardView(model: model, fontSize: CGFloat(model.fontSize))
                        .overlay { GestureCaptureLayer(model: model) }
                } else if model.cueScript.hasStructure && !model.cueScript.hasSpoken {
                    CueEnterHintView()
                } else {
                    PrompterScroller(model: model, fontSize: CGFloat(model.fontSize))
                        .overlay { GestureCaptureLayer(model: model) }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 58)
            .padding(.bottom, 16)
            .clipShape(Rectangle())
            
            if !model.isCountingDown {
                PrompterControlsBar(model: model)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            ScriptFlashBanner(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .allowsHitTesting(false)

            TimerBadge(model: model)
                .padding(.trailing, 16)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .allowsHitTesting(false)

            if model.isCountingDown {
                ZStack {
                    Color.black.opacity(0.92)
                    Text("\(model.countdownRemaining)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .clipShape(shape)
                .allowsHitTesting(false)
            }
        }
        .frame(width: model.overlayWidth,
               height: NotchLayout.height(base: model.overlayHeight,
                                          voiceActive: vf.isListening,
                                          voiceHeight: model.voiceFollowNotchHeight,
                                          cueActive: model.readingMode == .cue,
                                          cueHeight: model.cueNotchHeight))
    }
}

/// Shared transport/controls bar used by both the notch overlay and the
/// floating window. Tooltips are localized.
struct PrompterControlsBar: View {
    @ObservedObject var model: PrompterModel
    @ObservedObject private var lm = LocalizationManager.shared
    @ObservedObject private var vf = VoiceFollowController.shared

    private func toggleVoice() {
        if vf.isListening {
            vf.stop()
        } else {
            // 语音只朗读"台词"部分（去掉随讲标题/弹药）。无结构脚本时 spokenOnly == 原文。
            Task { await vf.start(scriptText: model.cueScript.spokenOnly, engine: model.voiceEngine) }
        }
    }

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                OverlayControlButton(symbol: vf.isListening ? "mic.fill" : "mic", isActive: vf.isListening) {
                    toggleVoice()
                }
                .help(vf.isListening ? lm.l(.ovVoiceStop) : lm.l(.ovVoiceStart))

                OverlayControlButton(
                    symbol: (model.isRunning || model.isCountingDown) ? "hand.draw.fill" : "play.fill"
                ) {
                    model.switchPlaybackModeFromOverlayControl()
                }
                .help((model.isRunning || model.isCountingDown) ? lm.l(.ovPauseSwitchManual) : lm.l(.ovStartAutoScroll))

                OverlayControlButton(
                    symbol: model.readingMode == .cue ? "list.bullet.rectangle.fill" : "list.bullet.rectangle",
                    isActive: model.readingMode == .cue
                ) {
                    model.toggleCueMode()
                }
                .help(model.readingMode == .cue ? lm.l(.ovCueStop) : lm.l(.ovCueStart))

                OverlayControlButton(symbol: "gobackward.5") {
                    model.jumpBack(seconds: 5)
                }
                .help(lm.l(.ovJumpBack5))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.7), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                OverlayControlButton(symbol: "doc.on.clipboard") {
                    if let text = NSPasteboard.general.string(forType: .string) {
                        model.pasteScript(text)
                    }
                }
                .help(lm.l(.ovPasteScript))

                OverlayControlButton(symbol: "trash") {
                    model.clearScript()
                }
                .help(lm.l(.ovClearScript))

                OverlayControlButton(symbol: "minus", repeatWhilePressed: true) {
                    model.adjustSpeed(delta: -PrompterModel.speedStep)
                }
                .help(lm.l(.ovDecreaseSpeed))

                OverlayControlButton(symbol: "plus", repeatWhilePressed: true) {
                    model.adjustSpeed(delta: PrompterModel.speedStep)
                }
                .help(lm.l(.ovIncreaseSpeed))

                OverlayControlButton(symbol: "square.and.pencil") {
                    NotificationCenter.default.post(name: .cueflowOpenScriptEditor, object: nil)
                }
                .help(lm.l(.ovEditScript))

                OverlayControlButton(symbol: "xmark") {
                    NSApp.terminate(nil)
                }
                .help(lm.l(.ovQuit))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.7), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
    }
}

/// Thin wrapper that builds the shared scrolling text view from the model
/// at a given font size (so notch + floating can share one configuration).
struct PrompterScroller: View {
    @ObservedObject var model: PrompterModel
    let fontSize: CGFloat

    var body: some View {
        ScrollingTextView(
            // 自动/手动滚动只显示"台词"（无结构脚本时 spokenOnly == 原文，行为不变）。
            text: model.cueScript.spokenOnly,
            fontSize: fontSize,
            speedPointsPerSecond: model.speedPointsPerSecond,
            isRunning: model.isRunning,
            hasStartedSession: model.hasStartedSession,
            resetToken: model.resetToken,
            jumpBackToken: model.jumpBackToken,
            jumpBackDistancePoints: model.jumpBackDistancePoints,
            manualScrollToken: model.manualScrollToken,
            manualScrollDeltaPoints: model.manualScrollDeltaPoints,
            fadeFraction: CGFloat(model.edgeFadeFraction),
            backgroundOpacity: model.backgroundOpacity,
            isHovering: false,
            scrollMode: model.scrollMode,
            savedScrollPhaseForResume: model.savedScrollPhaseForResume,
            onSaveScrollPhaseForResume: { phase in
                model.saveScrollPhaseForResume(phase)
            },
            onReachedEnd: {
                if model.isRunning {
                    model.markReachedEndInStopMode()
                }
            }
        )
    }
}

/// Free-floating, draggable/resizable prompter window content (F4).
/// Rounded rectangle (not the notch contour); font can auto-fit the window.
struct FloatingView: View {
    @ObservedObject var model: PrompterModel
    @ObservedObject private var vf = VoiceFollowController.shared

    private let corner: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let font: CGFloat = model.adaptiveFontSize
                ? max(14, min(64, geo.size.width / 20))
                : CGFloat(model.fontSize)

            ZStack {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Color.black.opacity(0.92))
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)

                if vf.isListening {
                    // Voice-follow mode (F3) — flowing highlight + auto-scroll.
                    FollowingPrompterView(vf: vf, fontSize: font)
                        .padding(.top, 44)
                        .padding(.bottom, 44)
                        .padding(.horizontal, 18)
                        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                } else if model.readingMode == .cue {
                    CueCardView(model: model, fontSize: font)
                        .padding(.top, 44)
                        .padding(.bottom, 16)
                        .padding(.horizontal, 18)
                        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                        .overlay { GestureCaptureLayer(model: model) }
                } else if model.cueScript.hasStructure && !model.cueScript.hasSpoken {
                    CueEnterHintView()
                        .padding(.top, 44)
                        .padding(.bottom, 16)
                        .padding(.horizontal, 18)
                } else {
                    PrompterScroller(model: model, fontSize: font)
                        .padding(.horizontal, 18)
                        .padding(.top, 44)
                        .padding(.bottom, 16)
                        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                        .overlay { GestureCaptureLayer(model: model) }
                }

                if !model.isCountingDown {
                    PrompterControlsBar(model: model)
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }

                ScriptFlashBanner(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .allowsHitTesting(false)

                TimerBadge(model: model)
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .allowsHitTesting(false)

                if model.isCountingDown {
                    ZStack {
                        Color.black.opacity(0.92)
                        Text("\(model.countdownRemaining)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    .allowsHitTesting(false)
                }
            }
        }
    }

}

/// Transient banner showing the just-loaded script name when cycling scripts
/// (⌥⌘] / ⌥⌘[). No system popup, so it is safe on screen recordings.
private struct ScriptFlashBanner: View {
    @ObservedObject var model: PrompterModel
    @State private var visible = false
    @State private var title = ""
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        Group {
            if visible {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.82), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
                    .transition(.opacity)
            }
        }
        .onChange(of: model.scriptFlashToken) { _, _ in
            title = model.scriptFlashTitle
            withAnimation(.easeOut(duration: 0.15)) { visible = true }
            hideTask?.cancel()
            hideTask = Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.3)) { visible = false }
                }
            }
        }
    }
}

private struct OverlayControlButton: View {
    let symbol: String
    var isActive: Bool = false
    var repeatWhilePressed: Bool = false
    let action: () -> Void

    var body: some View {
        // Use SwiftUI Button (not onLongPressGesture) so we benefit from
        // the macOS 15 click-through fix for non-activating panels (FB13720950).
        Button {
            if !repeatWhilePressed { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .contentShape(Circle())
        }
        .buttonStyle(
            OverlayCircleButtonStyle(
                isActive: isActive,
                repeatWhilePressed: repeatWhilePressed,
                repeatAction: action
            )
        )
    }
}

/// Button style that provides press-highlight and optional repeat-while-held.
private struct OverlayCircleButtonStyle: ButtonStyle {
    var isActive: Bool = false
    var repeatWhilePressed: Bool = false
    var repeatAction: (() -> Void)?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(Color.white.opacity(configuration.isPressed || isActive ? 0.18 : 0.10))
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .background {
                if repeatWhilePressed {
                    RepeatWhileHeldHelper(
                        isPressed: configuration.isPressed,
                        action: repeatAction ?? {}
                    )
                }
            }
    }
}

/// Zero-size helper that fires an action on press-down and repeats while held.
private struct RepeatWhileHeldHelper: View {
    let isPressed: Bool
    let action: () -> Void

    @State private var repeatTask: Task<Void, Never>?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: isPressed) { _, pressed in
                if pressed {
                    action()
                    startRepeating()
                } else {
                    stopRepeating()
                }
            }
            .onDisappear { stopRepeating() }
    }

    private func startRepeating() {
        stopRepeating()
        repeatTask = Task {
            try? await Task.sleep(nanoseconds: 280_000_000)
            while !Task.isCancelled {
                await MainActor.run { action() }
                try? await Task.sleep(nanoseconds: 85_000_000)
            }
        }
    }

    private func stopRepeating() {
        repeatTask?.cancel()
        repeatTask = nil
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

/// Transparent layer that turns trackpad scrolls over the overlay into prompter
/// actions: continuous vertical = manual scroll (normal mode); horizontal step =
/// speed (normal) / jump point (cue); vertical step = browse materials (cue).
/// Discrete steps fire a haptic (no sound). F7.
struct GestureCaptureLayer: View {
    @ObservedObject var model: PrompterModel

    var body: some View {
        TrackpadScrollCaptureView(
            onContinuousVertical: { delta in
                // Cue mode uses discrete vertical steps instead of free scrolling.
                if model.readingMode != .cue {
                    model.handleManualScroll(deltaPoints: delta)
                }
            },
            onHorizontalStep: { dir in
                guard model.gestureControlEnabled else { return }
                model.handleHorizontalGesture(dir)
                Self.haptic()
            },
            onVerticalStep: { step in
                guard model.gestureControlEnabled, model.readingMode == .cue else { return }
                model.handleVerticalDiscrete(step)
                Self.haptic()
            }
        )
    }

    private static func haptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}

/// Captures two-finger trackpad scrolling over the overlay and reports three
/// things: continuous vertical delta (for manual scrolling), and debounced
/// discrete horizontal / vertical "steps" (F7 gesture paging — one action per
/// swipe). The owner decides what each means for the current mode.
struct TrackpadScrollCaptureView: NSViewRepresentable {
    var onContinuousVertical: (CGFloat) -> Void
    var onHorizontalStep: (PrompterModel.GestureDirection) -> Void
    var onVerticalStep: (Int) -> Void

    func makeNSView(context: Context) -> ScrollCaptureNSView {
        let view = ScrollCaptureNSView()
        view.onContinuousVertical = onContinuousVertical
        view.onHorizontalStep = onHorizontalStep
        view.onVerticalStep = onVerticalStep
        return view
    }

    func updateNSView(_ nsView: ScrollCaptureNSView, context: Context) {
        nsView.onContinuousVertical = onContinuousVertical
        nsView.onHorizontalStep = onHorizontalStep
        nsView.onVerticalStep = onVerticalStep
    }
}

final class ScrollCaptureNSView: NSView {
    var onContinuousVertical: ((CGFloat) -> Void)?
    var onHorizontalStep: ((PrompterModel.GestureDirection) -> Void)?
    var onVerticalStep: ((Int) -> Void)?

    private enum Axis { case undetermined, horizontal, vertical }

    // Per-gesture state for axis-locking + discrete step detection.
    private var accX: CGFloat = 0
    private var accY: CGFloat = 0
    private var axis: Axis = .undetermined
    private var firedDiscrete = false
    private var lastEventTime: TimeInterval = 0
    private let axisDecision: CGFloat = 8      // points before we commit to an axis
    private let stepThreshold: CGFloat = 40    // points of travel before one step fires

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func scrollWheel(with event: NSEvent) {
        let rawX = event.hasPreciseScrollingDeltas ? event.scrollingDeltaX : event.deltaX * 10
        let rawY = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY * 10

        // New gesture window: on .began or after a brief idle gap.
        let now = event.timestamp
        if event.phase.contains(.began) || (now - lastEventTime) > 0.15 {
            accX = 0; accY = 0; axis = .undetermined; firedDiscrete = false
        }
        lastEventTime = now
        accX += rawX
        accY += rawY

        // Commit to a dominant axis early, then stick with it for this gesture.
        if axis == .undetermined, max(abs(accX), abs(accY)) >= axisDecision {
            axis = abs(accX) > abs(accY) ? .horizontal : .vertical
        }

        // Continuous manual scroll only for vertical gestures — a horizontal
        // (speed) swipe must NOT touch the scroll/run state (F7 fix).
        if axis == .vertical {
            let semanticY = event.isDirectionInvertedFromDevice ? rawY : -rawY
            onContinuousVertical?(semanticY)
        }

        if !firedDiscrete {
            if axis == .horizontal && abs(accX) >= stepThreshold {
                let semanticX = event.isDirectionInvertedFromDevice ? accX : -accX
                // swipe right → .right (next / speed up). Flip if it feels reversed.
                onHorizontalStep?(semanticX > 0 ? .right : .left)
                firedDiscrete = true
            } else if axis == .vertical && abs(accY) >= stepThreshold {
                let semanticY = event.isDirectionInvertedFromDevice ? accY : -accY
                // swipe up → next material (+1). Flip if it feels reversed.
                onVerticalStep?(semanticY < 0 ? 1 : -1)
                firedDiscrete = true
            }
        }

        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            accX = 0; accY = 0; axis = .undetermined; firedDiscrete = false
        }
    }
}
