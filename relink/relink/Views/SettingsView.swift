import SwiftUI

struct SettingsView: View {
    @AppStorage("relink_user_name") private var userName = "Arjun Verma"
    @AppStorage("relink_user_email") private var userEmail = ""

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.purple)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(userName.isEmpty ? "Your Name" : userName)
                            .font(.system(size: 15, weight: .semibold))
                        Text(userEmail.isEmpty ? "Add your email" : userEmail)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("Active")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                }
                .padding(.vertical, 6)
            }

            Section("Profile") {
                TextField("Name", text: $userName)
                    .textInputAutocapitalization(.words)

                TextField("Email", text: $userEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
            }

            Section {
                SettingsRow(systemImage: "gearshape", title: "Account Settings")
                SettingsRow(systemImage: "envelope", title: "Email Preferences")
                SettingsRow(systemImage: "hand.raised", title: "Privacy & Data")
                SettingsRow(systemImage: "bolt.horizontal.circle", title: "Integrations", subtitle: "Nozomio, AgentMail, OpenAI")
                SettingsRow(systemImage: "info.circle", title: "About Relink")
            }

            Section {
                Button(role: .destructive) {
                } label: {
                    Text("Log Out")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SettingsRow: View {
    let systemImage: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundColor(.purple)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
