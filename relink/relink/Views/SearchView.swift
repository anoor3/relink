import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [APIClient.SearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    @State private var draftTarget: (person: Person, guidance: String)?
    @State private var emailDraft: EmailDraft?
    @State private var showEmailDraft = false

    @State private var recentSearches: [String] = [
        "fintech investors",
        "product people in bangalore",
        "people from iit delhi",
        "designers in my network",
    ]

    private let userID = "user_1"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Who are you looking for?", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if isSearching {
                            ProgressView()
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                }

                if !results.isEmpty {
                    Section("Results") {
                        ForEach(results) { result in
                            NavigationLink(value: result.person) {
                                VStack(alignment: .leading, spacing: 6) {
                                    PersonRow(person: result.person)

                                    if !result.reason.isEmpty {
                                        Text(result.reason)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 52)
                                    }

                                    if !result.outreachGuidance.isEmpty {
                                        Button {
                                            draftTarget = (person: result.person, guidance: result.outreachGuidance)
                                            Task { await draftFromSearch() }
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: "sparkles")
                                                Text("Draft outreach")
                                                    .font(.system(size: 12, weight: .semibold))
                                            }
                                            .foregroundColor(.purple)
                                            .padding(.leading, 52)
                                            .padding(.vertical, 4)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Smart Suggestions")
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Button("See all") {}
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.purple)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    SuggestionCard(title: "People in fintech", subtitle: "Try: \"fintech investors\"", systemImage: "briefcase") {
                                        query = "people in fintech"
                                    }
                                    SuggestionCard(title: "People I haven’t talked to in 30+ days", subtitle: "Try: \"haven’t talked in 30 days\"", systemImage: "clock") {
                                        query = "people I haven’t talked to in 30+ days"
                                    }
                                    SuggestionCard(title: "Investors in my network", subtitle: "Try: \"investors\"", systemImage: "person.2") {
                                        query = "investors in my network"
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.vertical, 6)
                    }

                    if !recentSearches.isEmpty {
                        Section {
                            HStack {
                                Text("Recent Searches")
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Button("Clear") { recentSearches.removeAll() }
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.purple)
                            }
                            .padding(.vertical, 4)

                            ForEach(recentSearches, id: \.self) { item in
                                Button {
                                    query = item
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "clock")
                                            .foregroundColor(.secondary)
                                        Text(item)
                                            .font(.system(size: 13))
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Person.self) { person in
                PersonCardView(person: person)
            }
            .onSubmit(of: .text) {
                Task { await performSearch(addToRecents: true) }
            }
            .onChange(of: query) { _, newValue in
                debounceSearch(newValue)
            }
            .sheet(isPresented: $showEmailDraft) {
                if let emailDraft, let draftTarget {
                    EmailDraftView(draft: emailDraft, person: draftTarget.person)
                }
            }
        }
    }

    private func performSearch(addToRecents: Bool) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            errorMessage = nil
            return
        }

        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            results = try await APIClient.shared.searchPeople(userID: userID, query: trimmed)
            if addToRecents {
                recentSearches.removeAll(where: { $0 == trimmed })
                recentSearches.insert(trimmed, at: 0)
                recentSearches = Array(recentSearches.prefix(8))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func draftFromSearch() async {
        guard let draftTarget else { return }
        do {
            emailDraft = try await APIClient.shared.draftEmail(personID: draftTarget.person.id, guidance: draftTarget.guidance)
            showEmailDraft = emailDraft != nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @State private var debounceTask: Task<Void, Never>?
    private func debounceSearch(_ text: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            if Task.isCancelled { return }
            await performSearch(addToRecents: false)
        }
    }
}

private struct SuggestionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundColor(.purple)
                    .font(.system(size: 16, weight: .semibold))

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(width: 200, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SearchView()
}
