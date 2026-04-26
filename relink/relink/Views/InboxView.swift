import SwiftUI

struct InboxView: View {
    @StateObject private var model = InboxViewModel()

    @State private var selectedTab: InboxTab = .primary

    @State private var showInboxPicker = false

    enum InboxTab: String, CaseIterable, Identifiable {
        case all = "All"
        case primary = "Primary"
        case replies = "Replies"
        case mentions = "Mentions"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Agent Inbox")
                        .font(.system(size: 22, weight: .bold))
                    Text(model.inboxEmail ?? "")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    tabBar
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 12)

                Group {
                    if model.isLoading && model.threads.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage = model.errorMessage {
                        ContentUnavailableView(
                            "Failed to load inbox",
                            systemImage: "tray",
                            description: Text(errorMessage)
                        )
                    } else if model.threads.isEmpty {
                        ContentUnavailableView(
                            "No threads yet",
                            systemImage: "tray",
                            description: Text("Send an email to start a conversation.")
                        )
                    } else {
                        List {
                            ForEach(model.threads) { thread in
                                NavigationLink {
                                    InboxThreadView(inboxID: thread.inboxID, threadID: thread.threadID)
                                } label: {
                                    InboxRow(thread: thread)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .refreshable { await model.refresh() }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showInboxPicker = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task { await model.load() }
            .sheet(isPresented: $showInboxPicker) {
                NavigationStack {
                    InboxPickerView(onSelect: { inbox in
                        AgentMailClient.shared.setActiveInbox(inbox)
                        Task { await model.refresh() }
                        showInboxPicker = false
                    })
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showInboxPicker = false }
                        }
                    }
                }
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(InboxTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .medium))
                            .foregroundColor(selectedTab == tab ? .purple : .secondary)
                            .frame(maxWidth: .infinity)

                        Rectangle()
                            .fill(selectedTab == tab ? Color.purple : Color.clear)
                            .frame(height: 2)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)
    }
}

private struct InboxRow: View {
    let thread: AgentMailThreadItem

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: senderName, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(senderName)
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text(thread.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Text(thread.subject ?? "(no subject)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(thread.preview ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var senderName: String {
        let from = thread.senders.first ?? "Unknown"
        return from
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
    }
}

@MainActor
private final class InboxViewModel: ObservableObject {
    @Published var threads: [AgentMailThreadItem] = []
    @Published var inboxEmail: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let agentMail = AgentMailClient.shared

    func load() async {
        threads = AgentMailCache.shared.loadThreads()
        inboxEmail = agentMail.getCachedInboxEmail()
        await refresh()
    }

    func refresh() async {
        guard agentMail.isConfigured else {
            errorMessage = "Missing AGENTMAIL_API_KEY."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let displayName = UserDefaults.standard.string(forKey: "relink_user_name") ?? "Relink Agent"
            let inbox = try await agentMail.ensureInbox(displayName: displayName)
            inboxEmail = inbox.email

            let response = try await agentMail.listThreads(inboxID: inbox.inboxID, limit: 30)
            threads = response.threads
            AgentMailCache.shared.saveThreads(response.threads)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct InboxPickerView: View {
    let onSelect: (AgentMailInbox) -> Void

    @State private var inboxes: [AgentMailInbox] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }

            ForEach(inboxes, id: \.inboxID) { inbox in
                Button {
                    onSelect(inbox)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(inbox.displayName ?? "Agent Inbox")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(inbox.email)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Choose Inbox")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .task {
            await load()
        }
    }

    private func load() async {
        guard AgentMailClient.shared.isConfigured else {
            errorMessage = "Missing AGENTMAIL_API_KEY."
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await AgentMailClient.shared.listInboxes(limit: 50)
            inboxes = response.inboxes
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct InboxThreadView: View {
    let inboxID: String
    let threadID: String

    @State private var thread: AgentMailThread?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let thread {
                List {
                    ForEach(thread.messages) { message in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(message.from)
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            Text(message.extractedText ?? message.text ?? "")
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.plain)
            } else if let errorMessage {
                ContentUnavailableView("Failed to load thread", systemImage: "envelope", description: Text(errorMessage))
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                thread = try await AgentMailClient.shared.getThread(inboxID: inboxID, threadID: threadID)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    InboxView()
}
