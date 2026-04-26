import Contacts
import ContactsUI
import SwiftUI

struct NewContactView: UIViewControllerRepresentable {
    let contact: CNMutableContact
    let onComplete: (CNContact?) -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = CNContactViewController(forNewContact: contact)
        controller.delegate = context.coordinator
        controller.allowsEditing = true
        controller.allowsActions = false

        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        let onComplete: (CNContact?) -> Void

        init(onComplete: @escaping (CNContact?) -> Void) {
            self.onComplete = onComplete
        }

        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            onComplete(contact)
        }
    }
}

