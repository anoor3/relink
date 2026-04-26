import Foundation
import UIKit

enum ImageStore {
    private static let cache = NSCache<NSString, UIImage>()

    static func savePersonPhoto(_ image: UIImage, personID: String) throws -> String {
        let maxDimension: CGFloat = 720
        let resized = resize(image: image, maxDimension: maxDimension)

        guard let data = resized.jpegData(compressionQuality: 0.82) else {
            throw ImageStoreError.encodingFailed
        }

        let url = try photosDirectoryURL()
            .appendingPathComponent("\(personID).jpg")

        try data.write(to: url, options: [.atomic])

        cache.setObject(resized, forKey: url.lastPathComponent as NSString)
        return url.lastPathComponent
    }

    static func saveGalleryImage(_ image: UIImage, personID: String) throws -> String {
        let maxDimension: CGFloat = 1080
        let resized = resize(image: image, maxDimension: maxDimension)

        guard let data = resized.jpegData(compressionQuality: 0.86) else {
            throw ImageStoreError.encodingFailed
        }

        let filename = "\(personID)_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()).jpg"
        let url = try photosDirectoryURL().appendingPathComponent(filename)
        try data.write(to: url, options: [.atomic])

        cache.setObject(resized, forKey: filename as NSString)
        return filename
    }

    static func loadPersonPhoto(filename: String) -> UIImage? {
        if let cached = cache.object(forKey: filename as NSString) {
            return cached
        }
        guard let url = try? photosDirectoryURL().appendingPathComponent(filename) else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        let image = UIImage(data: data)
        if let image {
            cache.setObject(image, forKey: filename as NSString)
        }
        return image
    }

    private static func photosDirectoryURL() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("relink").appendingPathComponent("photos")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func resize(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let largest = max(size.width, size.height)
        guard largest > maxDimension else { return image }

        let scale = maxDimension / largest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

enum ImageStoreError: Error {
    case encodingFailed
}
