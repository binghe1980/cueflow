//
//  ScriptEditorWindowController.swift
//  notchprompt
//
//  Created by Codex on 2026-02-23.
//

import AppKit
import SwiftUI

@MainActor
final class ScriptEditorWindowController: NSWindowController {
    init() {
        let root = ScriptEditorView()
        let hosting = NSHostingController(rootView: root)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L(.winScriptEditorTitle)
        window.contentViewController = hosting
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 780, height: 500)
        // Sit above the overlay panel (.screenSaver) so the notch never blocks this window.
        window.level = NSWindow.Level(Int(NSWindow.Level.screenSaver.rawValue) + 1)
        // New autosave name so any previously-saved (tiny) frame is ignored.
        window.setFrameAutosaveName("CueflowScriptEditorWindow")
        window.setFrame(NSRect(x: 0, y: 0, width: 880, height: 600), display: false)
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

