import Foundation

final class LocalStore {
    static let shared = LocalStore()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private var cache: Storage = .init(persons: [])
    private var loaded = false

    func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true

        do {
            let data = try Data(contentsOf: fileURL)
            cache = try decoder.decode(Storage.self, from: data)
        } catch {
            cache = .init(persons: [])
        }
    }

    func getPersons(userID: String) -> [Person] {
        loadIfNeeded()
        return cache.persons
            .filter { $0.userID == userID }
            .sorted { ($0.lastContact ?? .distantPast) > ($1.lastContact ?? .distantPast) }
    }

    func getPerson(id: String) -> Person? {
        loadIfNeeded()
        return cache.persons.first(where: { $0.id == id })
    }

    func upsertPerson(_ person: Person) {
        loadIfNeeded()
        if let idx = cache.persons.firstIndex(where: { $0.id == person.id }) {
            cache.persons[idx] = person
        } else {
            cache.persons.append(person)
        }
        persist()
    }

    func addInteraction(personID: String, interaction: Interaction) {
        loadIfNeeded()
        guard let idx = cache.persons.firstIndex(where: { $0.id == personID }) else { return }

        var person = cache.persons[idx]
        var interactions = person.interactions ?? []
        interactions.insert(interaction, at: 0)
        person.interactions = interactions
        person.lastContact = interaction.createdAt ?? Date()
        cache.persons[idx] = person
        persist()
    }

    func deletePerson(id: String) {
        loadIfNeeded()
        cache.persons.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        do {
            let data = try encoder.encode(cache)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Best-effort local persistence
        }
    }

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("relink").appendingPathComponent("store.json")
    }

    private struct Storage: Codable {
        var persons: [Person]
    }
}
