//
//  SettingsWindowController.swift
//  notchprompt
//
//  Created by Saif on 2026-02-09.
//

import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init() {
        // F6: visualized settings center (sidebar + grouped cards).
        let root = SettingsCenterView()
        let hosting = NSHostingController(rootView: root)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L(.winSettingsTitle)
        window.contentViewController = hosting
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 720, height: 520)
        // Sit above the overlay panel (.screenSaver) so the notch never blocks this window.
        window.level = NSWindow.Level(Int(NSWindow.Level.screenSaver.rawValue) + 1)
        window.setFrameAutosaveName("NotchpromptSettingsWindow")
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
        // Last-resort if another always-on-top window exists.
        window?.orderFrontRegardless()
    }
}
