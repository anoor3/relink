import SwiftUI

struct PlanView: View {
    let personID: String

    @Environment(\.scenePhase) private var scenePhase

    @State private var person: Person?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var guidance = ""
    @State private var showPrompt = false

    @State private var selectedItem: OutreachPlanItem?
    @State private var autoSendTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                if let plan = person?.outreachPlan, !plan.items.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Planned touchpoints")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        ForEach(plan.items.sorted(by: { $0.sendAt < $1.sendAt })) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                PlanCard(item: item)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No plan yet",
                        systemImage: "calendar",
                        description: Text("Create an outreach plan and optionally schedule it in AgentMail.")
                    )
                    .padding(.top, 18)
                }

                Button {
                    showPrompt = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                        Text(isGenerating ? "Making plan..." : "Make / Update Plan")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal)
                .disabled(isGenerating || person == nil)

                Spacer(minLength: 18)
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showPrompt = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .disabled(person == nil)
            }
        }
        .refreshable {
            await syncStatuses(force: true)
        }
        .sheet(isPresented: $showPrompt) {
            if let person {
                PlanPromptView(person: person, guidance: $guidance) {
                    Task { await generatePlan() }
                }
            }
        }
        .sheet(item: $selectedItem) { item in
            if let person {
                PlanItemDetailView(person: person, item: item) {
                    Task { await syncStatuses(force: true) }
                }
            }
        }
        .task {
            load()
            await syncStatuses(force: false)
            scheduleAutoSendIfNeeded()
        }
        .onDisappear {
            autoSendTask?.cancel()
            autoSendTask = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                autoSendTask?.cancel()
                autoSendTask = nil
            } else {
                scheduleAutoSendIfNeeded()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Outreach plan")
                .font(.system(size: 22, weight: .bold))
                .padding(.horizontal)
                .padding(.top, 12)

            if let person {
                Text("For \(person.name)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
    }

    private func load() {
        person = LocalStore.shared.getPerson(id: personID)
        guidance = person?.outreachPlan?.guidance ?? ""
    }

    private func generatePlan() async {
        guard let person else { return }

        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        do {
            if (person.email ?? "").isEmpty {
                throw PlanError.missingEmail
            }

            _ = try await APIClient.shared.generateOutreachPlan(personID: person.id, guidance: guidance)
            load()
            await syncStatuses(force: true)
            scheduleAutoSendIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func syncStatuses(force: Bool) async {
        guard var person = LocalStore.shared.getPerson(id: personID) else { return }
        guard var plan = person.outreachPlan else { return }
        guard AgentMailClient.shared.isConfigured else { return }

        do {
            let displayName = UserDefaults.standard.string(forKey: "relink_user_name") ?? "Relink Agent"
            let inbox = try await AgentMailClient.shared.ensureInbox(displayName: displayName)

            let toEmail = person.email ?? ""
            let sentMessages = (try? await AgentMailClient.shared.listMessages(inboxID: inbox.inboxID, limit: 60, labels: ["sent"]).messages) ?? []

            var changed = false
            for idx in plan.items.indices {
                let localStatus = (plan.items[idx].status ?? "").lowercased()
                if localStatus == "cancelled" {
                    continue
                }
                guard let draftID = plan.items[idx].agentMailDraftID else { continue }
                do {
                    let draft = try await AgentMailClient.shared.getDraft(inboxID: inbox.inboxID, draftID: draftID)
                    let status = draft.sendStatus ?? "scheduled"
                    if plan.items[idx].status != status {
                        plan.items[idx].status = status
                        changed = true
                    }

                    // If AgentMail says it's sending, we can still detect a sent message and close the loop.
                    if status == "sending" {
                        if let match = findSentMessage(for: plan.items[idx], toEmail: toEmail, messages: sentMessages) {
                            plan.items[idx].status = "sent"
                            plan.items[idx].agentMailThreadID = match.threadID
                            plan.items[idx].agentMailMessageID = match.messageID
                            changed = true
                        }
                    }
                } catch {
                    // If the draft no longer exists, it's most likely been sent.
                    if let match = findSentMessage(for: plan.items[idx], toEmail: toEmail, messages: sentMessages) {
                        plan.items[idx].status = "sent"
                        plan.items[idx].agentMailThreadID = match.threadID
                        plan.items[idx].agentMailMessageID = match.messageID
                        changed = true
                    }
                }
            }

            if changed {
                person.outreachPlan = plan
                LocalStore.shared.upsertPerson(person)
                self.person = person
            }
        } catch {
            // non-fatal
        }
    }

    private func scheduleAutoSendIfNeeded() {
        autoSendTask?.cancel()
        autoSendTask = nil

        guard scenePhase == .active else { return }
        guard let person, let plan = person.outreachPlan else { return }
        guard AgentMailClient.shared.isConfigured else { return }

        let now = Date()
        let upcoming = plan.items
            .filter { item in
                let status = (item.status ?? "").lowercased()
                guard status == "scheduled" || status == "sending" else { return false }
                guard item.agentMailDraftID != nil else { return false }
                return item.sendAt <= now.addingTimeInterval(15 * 60)
            }
            .sorted { $0.sendAt < $1.sendAt }

        guard let next = upcoming.first else { return }

        autoSendTask = Task {
            let delay = max(0, next.sendAt.timeIntervalSinceNow + 10)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await attemptAutoSendDueItems()
            scheduleAutoSendIfNeeded()
        }
    }

    private func attemptAutoSendDueItems() async {
        guard var person = LocalStore.shared.getPerson(id: personID) else { return }
        guard var plan = person.outreachPlan else { return }
        guard AgentMailClient.shared.isConfigured else { return }

        let now = Date()

        do {
            let displayName = UserDefaults.standard.string(forKey: "relink_user_name") ?? "Relink Agent"
            let inbox = try await AgentMailClient.shared.ensureInbox(displayName: displayName)
            let sentMessages = (try? await AgentMailClient.shared.listMessages(inboxID: inbox.inboxID, limit: 80, labels: ["sent"]).messages) ?? []

            var changed = false
            for idx in plan.items.indices {
                let status = (plan.items[idx].status ?? "").lowercased()
                if status == "cancelled" || status == "sent" { continue }
                guard plan.items[idx].sendAt <= now else { continue }
                guard let draftID = plan.items[idx].agentMailDraftID else { continue }

                if let match = findSentMessage(for: plan.items[idx], toEmail: person.email ?? "", messages: sentMessages) {
                    plan.items[idx].status = "sent"
                    plan.items[idx].agentMailThreadID = match.threadID
                    plan.items[idx].agentMailMessageID = match.messageID
                    changed = true
                    continue
                }

                do {
                    let resp = try await AgentMailClient.shared.sendDraft(inboxID: inbox.inboxID, draftID: draftID)
                    plan.items[idx].status = "sent"
                    plan.items[idx].agentMailThreadID = resp.threadID
                    plan.items[idx].agentMailMessageID = resp.messageID
                    changed = true
                } catch {
                    plan.items[idx].status = "failed"
                    changed = true
                }
            }

            if changed {
                person.outreachPlan = plan
                LocalStore.shared.upsertPerson(person)
                self.person = person
            }
        } catch {
            // non-fatal
        }
    }

    private func findSentMessage(for item: OutreachPlanItem, toEmail: String, messages: [AgentMailMessageItem]) -> AgentMailMessageItem? {
        let subject = item.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subject.isEmpty else { return nil }

        return messages.first { message in
            guard let msgSubject = message.subject?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
            guard msgSubject == subject else { return false }
            if !toEmail.isEmpty {
                let tos = (message.to ?? []).joined(separator: ",")
                if !tos.localizedCaseInsensitiveContains(toEmail) { return false }
            }
            // Allow a wide window.
            return abs(message.timestamp.timeIntervalSince(item.sendAt)) < 6 * 60 * 60
        }
    }
}

private enum PlanError: Error {
    case missingEmail
}

extension PlanError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingEmail:
            return "Add an email address for this person before scheduling a plan."
        }
    }
}

private struct PlanCard: View {
    let item: OutreachPlanItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.sendAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.purple)
                Spacer()
                if let status = item.status, !status.isEmpty {
                    Text(status.capitalized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.10))
                        .clipShape(Capsule())
                }
            }

            Text(item.subject)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            Text(item.body)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineLimit(4)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)
    }

    private var statusColor: Color {
        switch (item.status ?? "").lowercased() {
        case "sent":
            return .green
        case "sending":
            return .orange
        case "failed":
            return .red
        case "cancelled":
            return .gray
        default:
            return .purple
        }
    }
}

private struct PlanItemDetailView: View {
    let person: Person
    let item: OutreachPlanItem
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let to = person.email, !to.isEmpty {
                        InfoRow(title: "To", value: to)
                    }
                    InfoRow(title: "Send at", value: item.sendAt.formatted(date: .abbreviated, time: .shortened))
                    InfoRow(title: "Status", value: (item.status ?? "scheduled").capitalized)

                    InfoRow(title: "Subject", value: item.subject)

                    Text("Body")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.top, 4)

                    Text(item.body)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("Plan Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }

            if let draftID = item.agentMailDraftID {
                VStack(spacing: 10) {
                    Button {
                        Task { await sendNow(draftID: draftID) }
                    } label: {
                        Text(isWorking ? "Working..." : "Send Now")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isWorking)

                    Button(role: .destructive) {
                        Task { await cancelDraft(draftID: draftID) }
                    } label: {
                        Text("Cancel Scheduled Email")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .disabled(isWorking)
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
                .background(Color(.systemBackground))
                .overlay(alignment: .top) { Divider() }
            }
        }
    }

    private func sendNow(draftID: String) async {
        guard AgentMailClient.shared.isConfigured else {
            errorMessage = "AgentMail not configured."
            return
        }
        guard let toEmail = person.email, !toEmail.isEmpty else {
            errorMessage = "Missing recipient email."
            return
        }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let displayName = UserDefaults.standard.string(forKey: "relink_user_name") ?? "Relink Agent"
            let inbox = try await AgentMailClient.shared.ensureInbox(displayName: displayName)
            _ = try await AgentMailClient.shared.sendDraft(inboxID: inbox.inboxID, draftID: draftID)
            onChanged()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancelDraft(draftID: String) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let displayName = UserDefaults.standard.string(forKey: "relink_user_name") ?? "Relink Agent"
            let inbox = try await AgentMailClient.shared.ensureInbox(displayName: displayName)
            try await AgentMailClient.shared.deleteDraft(inboxID: inbox.inboxID, draftID: draftID)

            // Update local plan immediately so the UI reflects cancellation.
            if var stored = LocalStore.shared.getPerson(id: person.id), var plan = stored.outreachPlan {
                if let idx = plan.items.firstIndex(where: { $0.id == item.id }) {
                    plan.items[idx].status = "cancelled"
                    plan.items[idx].agentMailDraftID = nil
                }
                stored.outreachPlan = plan
                LocalStore.shared.upsertPerson(stored)
            }

            onChanged()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    NavigationStack {
        PlanView(personID: "p_1")
    }
}
