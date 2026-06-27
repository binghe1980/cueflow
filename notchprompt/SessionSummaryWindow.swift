//
//  SessionSummaryWindow.swift
//  Cueflow (随读)
//
//  F6-D: Small floating card shown after a prompting session finishes
//  (default on; toggle via showSessionSummary). Auto-dismisses, or click OK.
//  Independently authored; no third-party code.
//

import SwiftUI
import AppKit

struct SessionSummaryCard: View {
    let session: RehearsalSession
    let onDismiss: () -> Void
    @ObservedObject private var lm = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                Text(lm.l(.summaryTitle)).font(.headline)
                Spacer()
            }
            HStack(spacing: 0) {
                metric(lm.l(.statsDuration), TimeFormat.clock(session.duration))
                Divider().frame(height: 34)
                metric(lm.l(.statsWords), "\(session.words)")
                Divider().frame(height: 34)
                metric(lm.l(.statsAvgSpeed), "\(Int(session.avgWordsPerMin))")
                Divider().frame(height: 34)
                metric(lm.l(.statsCompletion), "\(Int(session.completion * 100))%")
            }
            Button(action: onDismiss) {
                Text(lm.l(.summaryDismiss)).frame(maxWidth: .infinity)
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(18)
        .frame(width: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.title3.weight(.semibold).monospacedDigit())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

@MainActor
final class SessionSummaryWindowController: NSWindowController {
    private var dismissTask: Task<Void, Never>?

    init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 160),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered, defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = NSWindow.Level(Int(NSWindow.Level.screenSaver.rawValue) + 1)
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present(_ session: RehearsalSession) {
        guard let window else { return }
        let card = SessionSummaryCard(session: session) { [weak self] in self?.dismiss() }
        let hosting = NSHostingController(rootView: card)
        window.contentViewController = hosting
        window.setContentSize(hosting.view.fittingSize)

        // Center on the screen that hosts the menu bar (built-in / main).
        if let screen = NSScreen.main {
            let f = window.frame
            let x = screen.frame.midX - f.width / 2
            let y = screen.frame.midY - f.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        window.orderFrontRegardless()

        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 7_000_000_000)
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    private func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        window?.orderOut(nil)
    }
}
