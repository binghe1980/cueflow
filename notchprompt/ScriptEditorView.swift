//
//  ScriptEditorView.swift
//  Cueflow (随读)
//
//  Script editor + library. A permanent "Current" entry edits the live
//  prompter text (model.script) so pasted/imported content shows immediately;
//  saved records (the library) can be edited, renamed, deleted, used, exported.
//

import AppKit
import SwiftUI

private enum EditorSelection: Hashable {
    case current
    case record(UUID)
}

struct ScriptEditorView: View {
    @ObservedObject private var model = PrompterModel.shared
    @ObservedObject private var lm = LocalizationManager.shared
    @ObservedObject private var library = ScriptLibrary.shared

    @State private var selection: EditorSelection? = .current
    @State private var draftTitle: String = ""
    @State private var draftContent: String = ""
    @State private var fileErrorMessage: String?

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 210, idealWidth: 250, maxWidth: 360)
            detail
                .frame(minWidth: 460)
        }
        .frame(minWidth: 780, minHeight: 500)
        .onChange(of: selection) { _, sel in loadDraft(for: sel) }
        .onChange(of: draftTitle) { _, value in
            if case .record(let id) = selection, library.title(for: id) != value {
                library.setTitle(value, for: id)
            }
        }
        .onChange(of: draftContent) { _, value in
            if case .record(let id) = selection, library.content(for: id) != value {
                library.setContent(value, for: id)
            }
        }
        .alert(lm.l(.edFileOpFailed), isPresented: Binding(
            get: { fileErrorMessage != nil },
            set: { _ in fileErrorMessage = nil }
        )) {
            Button(lm.l(.edOK), role: .cancel) {}
        } message: {
            Text(fileErrorMessage ?? lm.l(.edFileOpFailedMsg))
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                Section {
                    Label(lm.l(.libCurrent), systemImage: "dot.radiowaves.left.and.right")
                        .lineLimit(1)
                        .tag(EditorSelection.current)
                }
                Section(lm.l(.libSavedRecords)) {
                    ForEach(library.items) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(item.title.isEmpty ? lm.l(.libUntitled) : item.title)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                typeBadge(for: item)
                            }
                            Text(item.updatedAt, format: .dateTime.year().month().day().hour().minute())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .tag(EditorSelection.record(item.id))
                    }
                    .onDelete { offsets in
                        library.delete(atOffsets: offsets)
                        selection = .current
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                Menu {
                    Button(lm.l(.libNewBlank)) { addNew() }
                    Button(lm.l(.libNewCue)) { addNewCue() }
                } label: {
                    Image(systemName: "plus")
                }
                .menuIndicator(.hidden)
                .fixedSize()
                .help(lm.l(.libNewScript))
                Button { deleteSelected() } label: { Image(systemName: "minus") }
                    .disabled(!isRecordSelected)
                    .help(lm.l(.libDelete))
                Spacer()
                Button(lm.l(.edImport)) { Task { await importScriptAsync() } }
            }
            .padding(8)
        }
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        if case .record(let id) = selection, library.item(id) != nil {
            recordEditor(id: id)
        } else {
            currentEditor
        }
    }

    private var currentEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lm.l(.libCurrent))
                .font(.headline)

            TextEditor(text: $model.script)
                .font(.system(size: 13, design: .monospaced))

            syntaxHint

            HStack {
                Button(lm.l(.edExport)) { Task { await exportText(model.script) } }
                    .disabled(model.script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
                Button(lm.l(.libSaveToLibrary)) { saveCurrentToLibrary() }
                    .disabled(model.script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
    }

    private func recordEditor(id: UUID) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(lm.l(.libTitle), text: $draftTitle)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $draftContent)
                .font(.system(size: 13, design: .monospaced))

            syntaxHint

            HStack {
                Button(lm.l(.edExport)) { Task { await exportText(draftContent) } }
                    .disabled(draftContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
                Button(lm.l(.libUseInPrompter)) { model.loadLibraryScript(id) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draftContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
    }

    private var syntaxHint: some View {
        Text(lm.l(.cueSyntaxHint))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func typeBadge(for item: ScriptItem) -> some View {
        let isCue = CueParser.parse(item.content).hasStructure
        Text(isCue ? lm.l(.badgeCue) : lm.l(.badgeRead))
            .font(.system(size: 9, weight: .medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background((isCue ? Color.orange : Color.secondary).opacity(0.20), in: Capsule())
            .foregroundStyle(isCue ? Color.orange : Color.secondary)
    }

    // MARK: Helpers

    private var isRecordSelected: Bool {
        if case .record = selection { return true }
        return false
    }

    private func loadDraft(for sel: EditorSelection?) {
        if case .record(let id) = sel, let item = library.item(id) {
            draftTitle = item.title
            draftContent = item.content
        } else {
            draftTitle = ""
            draftContent = ""
        }
    }

    private func addNew() {
        let id = library.add(title: lm.l(.libUntitled), content: "")
        selection = .record(id)
    }

    private func addNewCue() {
        let id = library.add(title: lm.l(.libCueTemplateTitle), content: lm.l(.libCueTemplateBody))
        selection = .record(id)
    }

    private func deleteSelected() {
        if case .record(let id) = selection {
            library.delete(id: id)
            selection = .current
        }
    }

    private func saveCurrentToLibrary() {
        let text = model.script
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let id = library.add(title: deriveTitle(from: text), content: text)
        selection = .record(id)
    }

    private func deriveTitle(from text: String) -> String {
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? lm.l(.libUntitled) : String(trimmed.prefix(30))
    }

    @MainActor
    private func importScriptAsync() async {
        let url = await FilePanelCoordinator.presentImportPanel(from: NSApp.keyWindow)
        guard let url else { return }
        do {
            let text = try await ScriptFileIO.importText(from: url)
            model.pasteScript(text)   // load into prompter; shows under "Current"
            selection = .current
        } catch {
            fileErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func exportText(_ content: String) async {
        guard !content.isEmpty else { return }
        let url = await FilePanelCoordinator.presentExportPanel(from: NSApp.keyWindow)
        guard let url else { return }
        do {
            try await ScriptFileIO.exportText(content, to: url)
        } catch {
            fileErrorMessage = error.localizedDescription
        }
    }
}
