//
//  FilePanelCoordinator.swift
//  notchprompt
//
//  Created by Codex on 2026-02-14.
//

import AppKit
import UniformTypeIdentifiers

@MainActor
enum FilePanelCoordinator {
    static func presentImportPanel(from window: NSWindow?) async -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowsOtherFileTypes = true
        panel.prompt = L(.panelImport)
        panel.message = L(.panelImportMsg)
        return await present(panel: panel, from: window)
    }

    static func presentExportPanel(from window: NSWindow?) async -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "script.txt"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowedContentTypes = exportTypes
        panel.prompt = L(.panelExport)
        panel.message = L(.panelExportMsg)
        return await present(panel: panel, from: window)
    }

    static var exportTypes: [UTType] {
        [
            .plainText,
            .utf8PlainText,
            .text,
            .rtf,
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "docx") ?? .data,
            UTType(filenameExtension: "odt") ?? .data
        ]
    }

    private static func present(panel: NSSavePanel, from window: NSWindow?) async -> URL? {
        await withCheckedContinuation { continuation in
            let handler: (NSApplication.ModalResponse) -> Void = { response in
                continuation.resume(returning: response == .OK ? panel.url : nil)
            }

            // Cueflow is a menu-bar agent whose overlay sits at `.screenSaver`
            // level; make sure the picker is frontmost and not hidden behind it.
            NSApp.activate(ignoringOtherApps: true)

            if let window {
                panel.beginSheetModal(for: window, completionHandler: handler)
            } else {
                panel.level = .screenSaver
                panel.begin(completionHandler: handler)
                panel.makeKeyAndOrderFront(nil)
            }
        }
    }
}
