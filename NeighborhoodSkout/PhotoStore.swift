import UIKit

struct PhotoStore {

    static let dir: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("NeighborhoodSkout/photos", isDirectory: true)
    }()

    static func houseURL(_ id: UUID)  -> URL { dir.appendingPathComponent("house_\(id.uuidString).jpg") }
    static func personURL(_ id: UUID) -> URL { dir.appendingPathComponent("person_\(id.uuidString).jpg") }

    static func save(_ image: UIImage, to url: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let resized = resize(image, maxDimension: 800)
        if let data = resized.jpegData(compressionQuality: 0.75) {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func load(_ url: URL) -> UIImage? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func delete(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Resize

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let w = image.size.width, h = image.size.height
        let scale = min(maxDimension / w, maxDimension / h, 1.0)
        guard scale < 1.0 else { return image }
        let newSize = CGSize(width: w * scale, height: h * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
