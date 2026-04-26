import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var tabRouter: TabRouter

    @State private var nudges: [Nudge] = []
    @State private var isLoading = true

    @State private var showSettings = false

    @AppStorage("relink_user_name") private var userName = "Arjun"

    private let userID = "user_1"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                        .padding(.horizontal)
                        .padding(.top, 12)

                    HStack {
                        Text("Needs your attention")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Button("See all") {}
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.purple)
                    }
                    .padding(.horizontal)

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    } else if nudges.isEmpty {
                        ContentUnavailableView(
                            "No nudges yet",
                            systemImage: "sparkles",
                            description: Text("Add people via Record to start.")
                        )
                        .padding(.top, 24)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(nudges) { nudge in
                                NavigationLink(value: nudge.person) {
                                    NudgeCard(nudge: nudge)
                                        .padding(.horizontal)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button {
                        tabRouter.selectedTab = .record
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                            Text("Record New Person")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    Spacer(minLength: 14)
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationDestination(for: Person.self) { person in
                PersonCardView(person: person)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showSettings = false }
                            }
                        }
                }
            }
            .task { await loadData() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Relink")
                        .font(.system(size: 34, weight: .bold))
                    Text("Your AI Relationship Memory Agent")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "bell")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }

            Text("\(greetingText()), \(userName) 👋")
                .font(.system(size: 20, weight: .semibold))

            Text("Here are your top nudges for today.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    private func loadData() async {
        isLoading = true
        nudges = (try? await APIClient.shared.getNudges(userID: userID)) ?? []
        isLoading = false
    }

    private func greetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(TabRouter())
}
