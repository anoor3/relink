import SwiftUI
import Contacts

struct PersonCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let person: Person

    @State private var currentPerson: Person

    @State private var emailDraft: EmailDraft?
    @State private var isDraftingEmail = false
    @State private var showEmailDraft = false

    @State private var messageDraft: TextMessageDraft?
    @State private var isDraftingMessage = false
    @State private var showMessageDraft = false

    @State private var showMoreMenu = false
    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    @State private var showContactPicker = false
    @State private var showContactView = false
    @State private var showNewContact = false

    @State private var selectedTab: ProfileTab = .overview

    enum ProfileTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case history = "History"
        case notes = "Notes"
        case files = "Files"

        var id: String { rawValue }
    }

    init(person: Person) {
        self.person = person
        _currentPerson = State(initialValue: person)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header

                actions
                    .padding(.horizontal)

                quickContactRow
                    .padding(.horizontal)
                    .padding(.top, -4)

                tabBar
                    .padding(.horizontal)
                    .padding(.top, 2)

                content
                    .padding(.horizontal)

                tagsRow
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(.darkGray))
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showMoreMenu = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(.darkGray))
                }
            }
        }
        .confirmationDialog("More", isPresented: $showMoreMenu) {
            Button("Edit") { showEdit = true }
            Button("Create New Contact") { showNewContact = true }
            Button(currentPerson.contactIdentifier == nil ? "Link to Contact" : "Change Linked Contact") {
                showContactPicker = true
            }
            if currentPerson.contactIdentifier != nil {
                Button("Open Contact") { showContactView = true }
            }
            Button("Delete Person", role: .destructive) { showDeleteConfirm = true }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete this person?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                LocalStore.shared.deletePerson(id: person.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove them and their memories from this device.")
        }
        .sheet(isPresented: $showEmailDraft) {
            if let emailDraft {
                EmailDraftView(draft: emailDraft, person: currentPerson)
            }
        }
        .sheet(isPresented: $showMessageDraft) {
            if let messageDraft {
                TextMessageDraftView(draft: messageDraft, person: currentPerson)
            }
        }
        .sheet(isPresented: $showEdit) {
            PersonEditView(person: LocalStore.shared.getPerson(id: person.id) ?? person)
        }
        .onChange(of: showEdit) { _, newValue in
            if newValue == false {
                currentPerson = LocalStore.shared.getPerson(id: person.id) ?? currentPerson
            }
        }
        .sheet(isPresented: $showContactPicker) {
            ContactPicker {
                link(contact: $0)
                showContactPicker = false
            } onCancel: {
                showContactPicker = false
            }
        }
        .sheet(isPresented: $showContactView) {
            if let id = currentPerson.contactIdentifier {
                ContactView(contactIdentifier: id) {
                    showContactView = false
                    currentPerson = LocalStore.shared.getPerson(id: person.id) ?? currentPerson
                }
            }
        }
        .sheet(isPresented: $showNewContact) {
            NewContactView(contact: makeNewContact()) { savedContact in
                if let savedContact, !savedContact.identifier.isEmpty {
                    var updated = LocalStore.shared.getPerson(id: person.id) ?? currentPerson
                    updated.contactIdentifier = savedContact.identifier
                    LocalStore.shared.upsertPerson(updated)
                    currentPerson = updated
                }
                showNewContact = false
            }
        }
        .onChange(of: showNewContact) { _, newValue in
            if newValue == false {
                currentPerson = LocalStore.shared.getPerson(id: person.id) ?? currentPerson
            }
        }
        .task {
            currentPerson = LocalStore.shared.getPerson(id: person.id) ?? person
        }
    }

    private func loadEmailDraft() async {
        isDraftingEmail = true
        defer { isDraftingEmail = false }

        emailDraft = try? await APIClient.shared.draftEmail(personID: currentPerson.id)
        showEmailDraft = emailDraft != nil
    }

    private func loadMessageDraft() async {
        isDraftingMessage = true
        defer { isDraftingMessage = false }

        messageDraft = try? await APIClient.shared.draftTextMessage(personID: currentPerson.id)
        showMessageDraft = messageDraft != nil
    }
}

private extension PersonCardView {
    func makeNewContact() -> CNMutableContact {
        let contact = CNMutableContact()

        let parts = currentPerson.name
            .split(separator: " ")
            .map { String($0) }
        contact.givenName = parts.first ?? currentPerson.name
        contact.familyName = parts.dropFirst().joined(separator: " ")

        if let company = currentPerson.company {
            contact.organizationName = company
        }
        if let role = currentPerson.role {
            contact.jobTitle = role
        }

        if let email = currentPerson.email, !email.isEmpty {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)]
        }

        if let phone = currentPerson.phoneNumber, !phone.isEmpty {
            let number = CNPhoneNumber(stringValue: phone)
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: number)]
        }

        if let linkedIn = currentPerson.linkedInURL, let url = normalizedURL(linkedIn) {
            contact.urlAddresses = [CNLabeledValue(label: "LinkedIn", value: url.absoluteString as NSString)]
        }

        if let photoFilename = currentPerson.photoFilename,
           let image = ImageStore.loadPersonPhoto(filename: photoFilename),
           let data = image.jpegData(compressionQuality: 0.9) {
            contact.imageData = data
        }

        return contact
    }

    func link(contact: CNContact) {
        var updated = LocalStore.shared.getPerson(id: person.id) ?? currentPerson
        updated.contactIdentifier = contact.identifier

        if updated.email == nil || updated.email?.isEmpty == true {
            let email = contact.emailAddresses.first?.value as String?
            updated.email = email
        }
        if updated.phoneNumber == nil || updated.phoneNumber?.isEmpty == true {
            let phone = contact.phoneNumbers.first?.value.stringValue
            updated.phoneNumber = phone
        }

        LocalStore.shared.upsertPerson(updated)
        currentPerson = updated
        showContactView = true
    }
}

private extension PersonCardView {
    var header: some View {
        VStack(spacing: 10) {
            AvatarView(name: currentPerson.name, size: 72, photoFilename: currentPerson.photoFilename)
                .padding(.top, 14)

            VStack(spacing: 6) {
                Text(currentPerson.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)

                HStack(spacing: 6) {
                    Text("\(currentPerson.role ?? "Unknown") at \(currentPerson.company ?? "Unknown")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    if let linkedInURL = currentPerson.linkedInURL, let url = normalizedURL(linkedInURL) {
                        Button {
                            openURL(url)
                        } label: {
                            Image(systemName: "link")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open LinkedIn")
                    }
                }

                if (currentPerson.relationshipStrength ?? 0) >= 8 {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Close Connection")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.10))
                    .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    var actions: some View {
        HStack(spacing: 14) {
            NavigationLink {
                BriefView(person: currentPerson)
            } label: {
                ActionSquare(title: "Brief Me", systemImage: "sparkles")
            }

            Button {
                Task { await loadMessageDraft() }
            } label: {
                ActionSquare(title: "Message (AI)", systemImage: "message")
            }
            .disabled(isDraftingMessage)

            Button {
                Task { await loadEmailDraft() }
            } label: {
                ActionSquare(title: "Email (AI)", systemImage: "envelope")
            }
            .disabled(isDraftingEmail)

            NavigationLink {
                PlanView(personID: currentPerson.id)
            } label: {
                ActionSquare(title: "Plan", systemImage: "calendar")
            }

            // More actions are handled by the top-right ellipsis.
        }
    }

    var quickContactRow: some View {
        HStack(spacing: 10) {
            if let email = currentPerson.email?.trimmingCharacters(in: .whitespacesAndNewlines),
               !email.isEmpty,
               let url = mailtoURL(email: email) {
                QuickIconButton(systemImage: "envelope.fill", tint: .purple) {
                    openURL(url)
                }
            }

            if let phone = currentPerson.phoneNumber?.trimmingCharacters(in: .whitespacesAndNewlines),
               !phone.isEmpty,
               let url = telURL(phone: phone) {
                QuickIconButton(systemImage: "phone.fill", tint: .green) {
                    openURL(url)
                }
            }

            QuickIconButton(systemImage: "person.crop.circle", tint: .blue) {
                if currentPerson.contactIdentifier != nil {
                    showContactView = true
                } else {
                    showNewContact = true
                }
            }

            Spacer()
        }
        .opacity((currentPerson.email?.isEmpty == false || currentPerson.phoneNumber?.isEmpty == false || currentPerson.contactIdentifier != nil) ? 1 : 0)
        .frame(height: 44)
    }

    var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases) { tab in
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

    var content: some View {
        Group {
            switch selectedTab {
            case .overview:
                overview
            case .history:
                history
            case .notes:
                placeholder(title: "Notes", subtitle: "Add notes and reminders here.")
            case .files:
                placeholder(title: "Files", subtitle: "Attach business cards, photos, and docs.")
            }
        }
    }

    var tagsRow: some View {
        Group {
            if let tags = currentPerson.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    var overview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("About")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button("Edit") { showEdit = true }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.purple)
            }

            VStack(alignment: .leading, spacing: 8) {
                if let topics = currentPerson.topicsDiscussed, !topics.isEmpty {
                    InfoLine(systemImage: "message", text: topics.joined(separator: ", "))
                }
                if let personalDetails = currentPerson.personalDetails, !personalDetails.isEmpty {
                    InfoLine(systemImage: "person.text.rectangle", text: personalDetails.joined(separator: ", "))
                }
                if let signals = currentPerson.signals, !signals.isEmpty {
                    InfoLine(systemImage: "sparkle", text: signals.joined(separator: ", "))
                }

                InfoLine(systemImage: "clock", text: "Last connected \(currentPerson.daysSinceContact) days ago")
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)

            if let gallery = currentPerson.galleryFilenames, !gallery.isEmpty {
                Text("Photos")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(gallery, id: \.self) { filename in
                            if let img = ImageStore.loadPersonPhoto(filename: filename) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 160, height: 110)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            } else {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                                    .frame(width: 160, height: 110)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let interactions = currentPerson.interactions, !interactions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(interactions) { interaction in
                        InteractionRow(interaction: interaction)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                placeholder(title: "History", subtitle: "No memories yet. Use Record to add one.")
            }
        }
    }

    func placeholder(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)
    }
}

private struct ActionSquare: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.purple)
                .frame(width: 40, height: 40)
                .background(Color.purple.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct QuickIconButton: View {
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct InfoLine: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.purple)
                .frame(width: 18)

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension PersonCardView {
    func normalizedURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        if let url = URL(string: "https://\(trimmed)") {
            return url
        }
        return nil
    }

    func mailtoURL(email: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        return components.url
    }

    func telURL(phone: String) -> URL? {
        let digits = phone.filter { "+0123456789".contains($0) }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel:\(digits)")
    }
}

#Preview {
    PersonCardView(
        person: Person(
            id: "p_1",
            userID: "user_1",
            name: "David",
            company: "a16z",
            role: "Partner",
            topicsDiscussed: ["AI infrastructure"],
            personalDetails: ["Daughter starting college"],
            signals: ["Frustrated about enterprise adoption"],
            sentiment: "warm",
            followUpIntent: "Send a paper about adoption playbooks",
            relationshipStrength: 7,
            tags: ["AI", "a16z"],
            email: "david@example.com",
            lastContact: Date().addingTimeInterval(-60 * 60 * 24 * 90),
            createdAt: Date(),
            interactions: [
                Interaction(id: "i_1", personID: "p_1", type: "voice_memo", content: "Met at the demo day.", createdAt: Date())
            ]
        )
    )
}
