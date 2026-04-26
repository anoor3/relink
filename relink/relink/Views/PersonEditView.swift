import SwiftUI
import PhotosUI
import UIKit

struct PersonEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var person: Person

    @State private var profilePhotoItem: PhotosPickerItem?
    @State private var galleryItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false

    init(person: Person) {
        _person = State(initialValue: person)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    HStack(spacing: 12) {
                        AvatarView(name: person.name, size: 56, photoFilename: person.photoFilename)

                        VStack(alignment: .leading, spacing: 6) {
                            PhotosPicker(selection: $profilePhotoItem, matching: .images) {
                                Text("Change profile photo")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .disabled(isLoadingPhotos)

                            if person.photoFilename != nil {
                                Button(role: .destructive) {
                                    person.photoFilename = nil
                                } label: {
                                    Text("Remove")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .disabled(isLoadingPhotos)
                            }
                        }

                        Spacer()
                    }
                }

                Section("Gallery") {
                    PhotosPicker(selection: $galleryItems, matching: .images) {
                        Text("Add photos")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .disabled(isLoadingPhotos)

                    if let gallery = person.galleryFilenames, !gallery.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(gallery, id: \.self) { filename in
                                    ZStack(alignment: .topTrailing) {
                                        if let img = ImageStore.loadPersonPhoto(filename: filename) {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 90, height: 90)
                                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        } else {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(Color(.secondarySystemBackground))
                                                .frame(width: 90, height: 90)
                                        }

                                        Button {
                                            person.galleryFilenames?.removeAll(where: { $0 == filename })
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .background(Color.black.opacity(0.45))
                                                .clipShape(Circle())
                                        }
                                        .offset(x: 8, y: -8)
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    } else {
                        Text("No photos yet")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    if isLoadingPhotos {
                        HStack {
                            ProgressView()
                            Text("Processing photos...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Basics") {
                    TextField("Name", text: $person.name)
                    TextField("Company", text: Binding($person.company, replacingNilWith: ""))
                    TextField("Role", text: Binding($person.role, replacingNilWith: ""))
                }

                Section("Contact") {
                    TextField("Email", text: Binding($person.email, replacingNilWith: ""))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)

                    TextField("Phone", text: Binding($person.phoneNumber, replacingNilWith: ""))
                        .keyboardType(.phonePad)

                    TextField("LinkedIn URL", text: Binding($person.linkedInURL, replacingNilWith: ""))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        normalizeFields()
                        LocalStore.shared.upsertPerson(person)
                        if NiaClient.shared.isConfigured {
                            Task { try? await NiaClient.shared.savePersonContext(person: person) }
                        }
                        dismiss()
                    }
                }
            }
            .onChange(of: profilePhotoItem) { newItem in
                guard let newItem else { return }
                Task { await setProfilePhoto(from: newItem) }
            }
            .onChange(of: galleryItems) { newItems in
                guard !newItems.isEmpty else { return }
                Task { await addGalleryPhotos(from: newItems) }
            }
        }
    }

    private func setProfilePhoto(from item: PhotosPickerItem) async {
        isLoadingPhotos = true
        defer { isLoadingPhotos = false }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }

        if let filename = try? ImageStore.savePersonPhoto(image, personID: person.id) {
            person.photoFilename = filename
        }
    }

    private func addGalleryPhotos(from items: [PhotosPickerItem]) async {
        isLoadingPhotos = true
        defer {
            isLoadingPhotos = false
            galleryItems = []
        }

        var filenames = person.galleryFilenames ?? []
        for item in items.prefix(8) {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                continue
            }
            if let filename = try? ImageStore.saveGalleryImage(image, personID: person.id) {
                filenames.append(filename)
            }
        }
        person.galleryFilenames = filenames
    }

    private func normalizeFields() {
        person.company = person.company?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        person.role = person.role?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        person.email = person.email?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        person.phoneNumber = person.phoneNumber?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        person.linkedInURL = person.linkedInURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

private extension Binding where Value == String? {
    init(_ source: Binding<String?>) {
        self = source
    }
}

private extension Binding where Value == String {
    init(_ source: Binding<String?>, replacingNilWith defaultValue: String) {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { newValue in
                source.wrappedValue = newValue
            }
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    PersonEditView(
        person: Person(
            id: "p_1",
            userID: "user_1",
            name: "Jordan Miller",
            company: "FinEdge",
            role: "Co-founder",
            topicsDiscussed: [],
            personalDetails: [],
            signals: [],
            sentiment: "warm",
            followUpIntent: nil,
            relationshipStrength: 8,
            tags: ["Fintech"],
            email: "jordan@example.com",
            phoneNumber: "+1 555 123 4567",
            linkedInURL: "https://linkedin.com/in/jordan",
            photoFilename: nil,
            galleryFilenames: [],
            lastContact: Date(),
            createdAt: Date(),
            interactions: []
        )
    )
}
