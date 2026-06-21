//
//  ScriptLibrary.swift
//  Cueflow (随读)
//
//  Persistent library of saved scripts (records). Each item can be edited,
//  renamed, deleted, imported, exported, and pushed to the prompter.
//

import Foundation
import Combine

struct ScriptItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var content: String
    var updatedAt: Date = Date()
}

@MainActor
final class ScriptLibrary: ObservableObject {
    static let shared = ScriptLibrary()

    @Published private(set) var items: [ScriptItem] = []

    private static let key = "scriptLibraryV1"

    private init() {
        load()
    }

    // MARK: Lookups

    func item(_ id: UUID) -> ScriptItem? { items.first { $0.id == id } }
    func title(for id: UUID) -> String? { item(id)?.title }
    func content(for id: UUID) -> String? { item(id)?.content }
    func index(of id: UUID) -> Int? { items.firstIndex { $0.id == id } }

    /// Next/previous item id for hands-free cycling (⌥⌘] / ⌥⌘[). Wraps around.
    /// When nothing is active (or the id is gone) returns the first/last item.
    func cycledID(from current: UUID?, forward: Bool) -> UUID? {
        guard !items.isEmpty else { return nil }
        guard let current, let i = index(of: current) else {
            return forward ? items.first?.id : items.last?.id
        }
        let n = items.count
        let j = forward ? (i + 1) % n : (i - 1 + n) % n
        return items[j].id
    }

    // MARK: Mutations

    @discardableResult
    func add(title: String, content: String) -> UUID {
        let item = ScriptItem(title: title, content: content)
        items.insert(item, at: 0)
        save()
        return item.id
    }

    func setTitle(_ newTitle: String, for id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }), items[i].title != newTitle else { return }
        items[i].title = newTitle
        items[i].updatedAt = Date()
        save()
    }

    func setContent(_ newContent: String, for id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }), items[i].content != newContent else { return }
        items[i].content = newContent
        items[i].updatedAt = Date()
        save()
    }

    func delete(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func delete(atOffsets offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        save()
    }

    // MARK: Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([ScriptItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
