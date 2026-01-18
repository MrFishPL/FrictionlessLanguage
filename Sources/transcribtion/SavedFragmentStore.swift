import Foundation

struct SavedFragment: Codable, Equatable {
    let id: UUID
    let originalText: String
    let contextText: String
    let translationText: String
    let savedAt: Date
}

final class SavedFragmentStore {
    static let shared = SavedFragmentStore()

    private let fileManager = FileManager.default
    private let fileName = "saved_fragments.json"

    private init() {}

    func load() -> [SavedFragment] {
        guard let url = storageURL(),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([SavedFragment].self, from: data)) ?? []
    }

    func save(_ fragments: [SavedFragment]) {
        guard let url = storageURL(),
              let data = try? JSONEncoder().encode(fragments) else { return }
        try? fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try? data.write(to: url, options: [.atomic])
    }

    func find(originalText: String, contextText: String) -> SavedFragment? {
        let fragments = load()
        return fragments.first { $0.originalText == originalText && $0.contextText == contextText }
    }

    private func storageURL() -> URL? {
        guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = base.appendingPathComponent("Flungus", isDirectory: true)
        return directory.appendingPathComponent(fileName)
    }
}
