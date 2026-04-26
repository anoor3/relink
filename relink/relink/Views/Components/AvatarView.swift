import SwiftUI
import UIKit

struct AvatarView: View {
    let name: String
    let size: CGFloat
    var photoFilename: String? = nil

    var body: some View {
        ZStack {
            if let photoFilename, let image = ImageStore.loadPersonPhoto(filename: photoFilename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundColor(.purple)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(name)
    }

    private var initials: String {
        let parts = name
            .split(separator: " ")
            .map { String($0) }

        let first = parts.first?.first.map(String.init) ?? "?"
        let second = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + second).uppercased()
    }
}

#Preview {
    AvatarView(name: "David Kim", size: 52)
}
