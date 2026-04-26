import SwiftUI

struct PeopleView: View {
    @State private var persons: [Person] = []
    @State private var isLoading = true
    @State private var query = ""
    @State private var errorMessage: String?

    private let userID = "user_1"

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }

                ForEach(filteredPersons) { person in
                    NavigationLink(value: person) {
                        PersonRow(person: person)
                    }
                }
            }
            .navigationTitle("People")
            .navigationDestination(for: Person.self) { person in
                PersonCardView(person: person)
            }
            .overlay {
                if isLoading {
                    ProgressView()
                } else if persons.isEmpty {
                    ContentUnavailableView(
                        "No people yet",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Use Record to add your first person.")
                    )
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private var filteredPersons: [Person] {
        guard !query.isEmpty else { return persons }
        let lowered = query.lowercased()
        return persons.filter {
            $0.name.lowercased().contains(lowered)
            || ($0.company ?? "").lowercased().contains(lowered)
            || ($0.role ?? "").lowercased().contains(lowered)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            persons = try await APIClient.shared.getPersons(userID: userID)
        } catch {
            errorMessage = "Failed to load people: \(error.localizedDescription)"
        }
    }
}

#Preview {
    PeopleView()
}

