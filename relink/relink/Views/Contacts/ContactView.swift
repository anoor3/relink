import Contacts
import ContactsUI
import SwiftUI

struct ContactView: UIViewControllerRepresentable {
    let contactIdentifier: String
    let onDone: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactViewController.descriptorForRequiredKeys(),
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactUrlAddressesKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
        ]

        let contact = (try? store.unifiedContact(withIdentifier: contactIdentifier, keysToFetch: keys))
            ?? CNContact()

        let controller = CNContactViewController(for: contact)
        controller.allowsEditing = true
        controller.allowsActions = true
        controller.contactStore = store
        controller.delegate = context.coordinator

        let done = UIBarButtonItem(title: "Done", style: .done, target: context.coordinator, action: #selector(Coordinator.doneTapped))
        controller.navigationItem.leftBarButtonItem = done

        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDone: onDone)
    }

    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        let onDone: () -> Void

        init(onDone: @escaping () -> Void) {
            self.onDone = onDone
        }

        @objc func doneTapped() {
            onDone()
        }

        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            onDone()
        }
    }
}
