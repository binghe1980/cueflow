//
//  CueCardView.swift
//  Cueflow (随读)
//
//  随讲 (cue card) mode rendering. Shows the current outline point: progress,
//  title, optional time budget, must-say (●) / optional (○) materials, and a
//  one-line preview of the next point. Navigation is keyboard-only (see
//  ShortcutCommand.cueToggle / .cueNext / .cuePrev); this view is display-only.
//
//  Used by both the notch overlay and the floating window.
//

import SwiftUI

struct CueCardView: View {
    @ObservedObject var model: PrompterModel
    @ObservedObject private var lm = LocalizationManager.shared
    var fontSize: CGFloat = 18

    var body: some View {
        let doc = model.cueScript
        Group {
            if doc.canUseCueMode {
                if model.cueShowingOverview {
                    overview(doc)
                } else {
                    card(doc)
                }
            } else {
                hint
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(.white)
    }

    // MARK: Overview (bird's-eye, ⌥⌘L)

    private func overview(_ doc: CueScript) -> some View {
        let count = doc.sections.count
        let idx = min(max(0, model.activeSectionIndex), count - 1)
        return VStack(alignment: .leading, spacing: 8) {
            Text(lm.l(.cueOverviewTitle, count))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(doc.sections.enumerated()), id: \.offset) { i, section in
                            overviewRow(i: i, current: idx, section: section)
                                .id(i)
                        }
                    }
                }
                // Keep the highlighted point in view as ← → moves it, and jump to
                // the current point when the overview first opens.
                .onAppear {
                    DispatchQueue.main.async { proxy.scrollTo(idx, anchor: .center) }
                }
                .onChange(of: model.activeSectionIndex) { _, newIdx in
                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo(min(max(0, newIdx), count - 1), anchor: .center)
                    }
                }
            }

            Text(lm.l(.cueOverviewHint))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func overviewRow(i: Int, current: Int, section: CueSection) -> some View {
        let isCurrent = i == current
        let isPast = i < current
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(i + 1)")
                .font(.system(size: fontSize - 4, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isCurrent ? Color.white : .white.opacity(0.5))
                .frame(minWidth: 18, alignment: .trailing)
            Text(displayTitle(section))
                .font(.system(size: fontSize - 2, weight: isCurrent ? .semibold : .regular))
                .foregroundStyle(.white.opacity(isCurrent ? 1.0 : (isPast ? 0.4 : 0.78)))
                .lineLimit(1)
            Spacer(minLength: 8)
            if let budget = section.timeBudgetSeconds {
                Text(Self.formatTime(budget))
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(isCurrent ? 0.14 : 0))
        )
    }

    // MARK: No-outline hint

    private var hint: some View {
        VStack(spacing: 10) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.55))
            Text(lm.l(.cueNoOutlineHint))
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 14)
    }

    // MARK: Card

    private func card(_ doc: CueScript) -> some View {
        let count = doc.sections.count
        let idx = min(max(0, model.activeSectionIndex), count - 1)
        let section = doc.sections[idx]
        return VStack(alignment: .leading, spacing: 8) {
            metaStrip(idx: idx, count: count, section: section)

            title(section)

            Divider().overlay(Color.white.opacity(0.15))

            materialsList(section)

            Spacer(minLength: 0)

            footer(doc: doc, idx: idx, count: count)

            positionIndicator(idx: idx, count: count)
        }
    }

    /// Small context strip: progress + (optional) total timer on the left, the
    /// live per-point timer on the right.
    private func metaStrip(idx: Int, count: Int, section: CueSection) -> some View {
        // One ticking schedule drives both timers.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(idx + 1)/\(count)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()

                if model.showCueTotalTimer, let start = model.cueStartedAt {
                    Text("· " + Self.formatTime(Self.elapsed(since: start, now: context.date)))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .monospacedDigit()
                }

                Spacer(minLength: 8)

                sectionTimer(section: section, now: context.date)
            }
        }
    }

    /// The point's headline — the dominant element you glance at.
    private func title(_ section: CueSection) -> some View {
        Text(displayTitle(section))
            .font(.system(size: fontSize + 6, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func sectionTimer(section: CueSection, now: Date) -> some View {
        if let start = model.cueSectionStartedAt {
            let elapsed = Self.elapsed(since: start, now: now)
            let over = section.timeBudgetSeconds.map { elapsed > $0 } ?? false
            let text: String = {
                if let budget = section.timeBudgetSeconds {
                    return "\(Self.formatTime(elapsed)) / \(Self.formatTime(budget))"
                }
                return Self.formatTime(elapsed)
            }()
            Label(text, systemImage: "timer")
                .font(.system(size: 12, weight: over ? .bold : .medium))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(over ? Color.red : Color.white.opacity(0.6))
                .monospacedDigit()
                .fixedSize()
        }
    }

    @ViewBuilder
    private func materialsList(_ section: CueSection) -> some View {
        if section.materials.isEmpty {
            Text(lm.l(.cueSectionNoMaterial))
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))
        } else {
            // ↑↓ (cueMaterialIndex) scroll within the point when its materials
            // overflow the notch height — hands-free, no trackpad needed.
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 11) {
                        ForEach(Array(section.materials.enumerated()), id: \.offset) { i, material in
                            materialRow(material)
                                .id(i)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: model.cueMaterialIndex) { _, newIdx in
                    let target = min(max(0, newIdx), max(0, section.materials.count - 1))
                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
            }
        }
    }

    private func materialRow(_ material: CueMaterial) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: material.isOptional ? "circle" : "circle.fill")
                .font(.system(size: material.isOptional ? 7 : 8))
                .foregroundStyle(.white.opacity(material.isOptional ? 0.5 : 0.95))
                .padding(.top, fontSize * 0.34)
            Text(material.text)
                .font(.system(size: material.isOptional ? fontSize - 2 : fontSize,
                              weight: material.isOptional ? .regular : .medium))
                .foregroundStyle(.white.opacity(material.isOptional ? 0.55 : 1.0))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Footer: a preview of the next point, or a clear "last point" cue at the end.
    @ViewBuilder
    private func footer(doc: CueScript, idx: Int, count: Int) -> some View {
        if idx + 1 < count {
            Label(lm.l(.cueNextPoint, displayTitle(doc.sections[idx + 1])), systemImage: "arrow.turn.down.right")
                .font(.system(size: 12))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
        } else {
            Label(lm.l(.cueLastPoint), systemImage: "flag.checkered")
                .font(.system(size: 12, weight: .medium))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    /// Glanceable "where am I" strip: a filmstrip of dots for small decks
    /// (past dim · current wide & bright · upcoming faint), or a fill bar when
    /// there are too many points to show as dots.
    @ViewBuilder
    private func positionIndicator(idx: Int, count: Int) -> some View {
        if count <= 14 {
            HStack(spacing: 4) {
                ForEach(0..<count, id: \.self) { i in
                    Capsule()
                        .fill(Color.white.opacity(i == idx ? 0.9 : (i < idx ? 0.4 : 0.18)))
                        .frame(width: i == idx ? 16 : 6, height: 4)
                }
            }
        } else {
            GeometryReader { geo in
                let fraction = CGFloat(idx + 1) / CGFloat(max(1, count))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule().fill(Color.white.opacity(0.55))
                        .frame(width: max(3, geo.size.width * fraction))
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: Helpers

    private func displayTitle(_ section: CueSection) -> String {
        section.title.isEmpty ? lm.l(.libUntitled) : section.title
    }

    static func elapsed(since start: Date, now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(start)))
    }

    static func formatTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Shown in auto/voice (normal) mode when the active script is a pure cue
/// outline (no read-aloud lines), so the notch never looks blank — it points
/// the user to ⌥⌘G instead.
struct CueEnterHintView: View {
    @ObservedObject private var lm = LocalizationManager.shared

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.55))
            Text(lm.l(.cueEnterHint))
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.78))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 14)
    }
}
