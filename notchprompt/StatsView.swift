//
//  StatsView.swift
//  Cueflow (随读)
//
//  F6-D: Rehearsal stats window (opened from the menu bar). Read-only view over
//  StatsStore with a "clear" action. Independently authored; no third-party code.
//

import SwiftUI
import AppKit

struct StatsView: View {
    @ObservedObject private var store = StatsStore.shared
    @ObservedObject private var lm = LocalizationManager.shared
    @State private var confirmingClear = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if store.sessions.isEmpty {
                    emptyState
                } else {
                    latestCard
                    totalsCard
                    recentList
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 460, minHeight: 480)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(lm.l(.statsTitle)).font(.title2.weight(.semibold))
                Text(lm.l(.statsSubtitle)).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if !store.sessions.isEmpty {
                Button(role: .destructive) { confirmingClear = true } label: {
                    Label(lm.l(.statsClear), systemImage: "trash")
                }
                .confirmationDialog(lm.l(.statsClearConfirmTitle), isPresented: $confirmingClear) {
                    Button(lm.l(.statsClear), role: .destructive) { store.clearAll() }
                    Button(lm.l(.statsCancel), role: .cancel) {}
                } message: {
                    Text(lm.l(.statsClearConfirmMsg))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis").font(.system(size: 34)).foregroundStyle(.secondary)
            Text(lm.l(.statsEmpty)).font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    @ViewBuilder
    private var latestCard: some View {
        if let s = store.latest {
            GroupBox(lm.l(.statsThisSession)) {
                HStack(spacing: 0) {
                    metric(lm.l(.statsDuration), TimeFormat.clock(s.duration))
                    Divider().frame(height: 36)
                    metric(lm.l(.statsWords), "\(s.words)")
                    Divider().frame(height: 36)
                    metric(lm.l(.statsAvgSpeed), "\(Int(s.avgWordsPerMin)) \(lm.l(.statsWordsPerMin))")
                    Divider().frame(height: 36)
                    metric(lm.l(.statsCompletion), "\(Int(s.completion * 100))%")
                }
                .padding(.vertical, 6)
            }
        }
    }

    private var totalsCard: some View {
        GroupBox(lm.l(.statsTotals)) {
            HStack(spacing: 0) {
                metric(lm.l(.statsTotalSessions), "\(store.totalSessions)")
                Divider().frame(height: 36)
                metric(lm.l(.statsTotalTime), TimeFormat.clock(store.totalDuration))
            }
            .padding(.vertical, 6)
        }
    }

    private var recentList: some View {
        GroupBox(lm.l(.statsRecent)) {
            VStack(spacing: 0) {
                ForEach(store.sessions.prefix(30)) { s in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.scriptTitle).font(.subheadline).lineLimit(1)
                            Text(Self.dateFormatter.string(from: s.startedAt))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(TimeFormat.clock(s.duration))
                            .font(.callout.monospacedDigit())
                        Text("\(Int(s.avgWordsPerMin)) \(lm.l(.statsWordsPerMin))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 78, alignment: .trailing)
                        if s.reachedEnd {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green).font(.caption)
                        }
                    }
                    .padding(.vertical, 7)
                    if s.id != store.sessions.prefix(30).last?.id { Divider() }
                }
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.weight(.semibold).monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()
}

@MainActor
final class StatsWindowController: NSWindowController {
    init() {
        let hosting = NSHostingController(rootView: StatsView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = L(.winStatsTitle)
        window.contentViewController = hosting
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 460, height: 480)
        window.level = NSWindow.Level(Int(NSWindow.Level.screenSaver.rawValue) + 1)
        window.setFrameAutosaveName("CueflowStatsWindow")
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}
