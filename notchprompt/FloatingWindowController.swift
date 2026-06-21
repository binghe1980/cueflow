//
//  FloatingWindowController.swift
//  Cueflow (随读)
//
//  F4: a free-floating, draggable & resizable prompter window that is an
//  alternative to the notch overlay (mutually exclusive with it). Honors the
//  same privacy (screen-share hiding) setting and persists its geometry.
//

import AppKit
import SwiftUI

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class FloatingWindowController {
    private let model: PrompterModel
    private let panel: NSPanel
    private var observers: [NSObjectProtocol] = []
    private var suppressPersist = false

    init(model: PrompterModel) {
        self.model = model

        let width = max(320, CGFloat(model.floatingWidth))
        let height = max(160, CGFloat(model.floatingHeight))

        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.minSize = NSSize(width: 320, height: 160)
        panel.maxSize = NSSize(width: 2200, height: 1400)
        panel.sharingType = model.privacyModeEnabled ? .none : .readOnly

        let hosting = NSHostingView(rootView: FloatingView(model: model))
        panel.contentView = hosting
        self.panel = panel

        positionInitially(width: width, height: height)

        let resize = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: panel, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.persistFrame() } }
        let move = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.persistFrame() } }
        observers = [resize, move]
    }

    deinit {
        for o in observers { NotificationCenter.default.removeObserver(o) }
    }

    func setVisible(_ visible: Bool) {
        if visible {
            panel.alphaValue = 1.0
            panel.orderFrontRegardless()
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderOut(nil)
        }
    }

    func setPrivacyMode(_ enabled: Bool) {
        panel.sharingType = enabled ? .none : .readOnly
    }

    private func positionInitially(width: CGFloat, height: CGFloat) {
        suppressPersist = true
        defer { suppressPersist = false }

        let origin: NSPoint
        if model.floatingOriginX.isFinite, model.floatingOriginY.isFinite {
            origin = NSPoint(x: model.floatingOriginX, y: model.floatingOriginY)
        } else if let screen = NSScreen.main {
            let f = screen.visibleFrame
            origin = NSPoint(x: (f.midX - width / 2).rounded(), y: (f.midY - height / 2).rounded())
        } else {
            origin = NSPoint(x: 200, y: 200)
        }
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: false)
    }

    private func persistFrame() {
        guard !suppressPersist else { return }
        let f = panel.frame
        model.floatingWidth = Double(f.size.width)
        model.floatingHeight = Double(f.size.height)
        model.floatingOriginX = Double(f.origin.x)
        model.floatingOriginY = Double(f.origin.y)
    }
}
