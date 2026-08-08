import UIKit

/// On-disk storage for receipt images attached to an `Expense`.
///
/// Images never touch SwiftData directly — a JPEG saved to disk and referenced by filename
/// keeps the database small and avoids loading photo bytes just to read an expense's amount.
enum ReceiptStorage {

    private static let directory: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Receipts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Saves `image` as a new JPEG and returns its filename for storage on the `Expense`,
    /// or `nil` if it couldn't be written.
    @discardableResult
    static func save(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.75) else { return nil }
        let filename = "\(UUID().uuidString).jpg"
        do {
            try data.write(to: directory.appendingPathComponent(filename))
            return filename
        } catch {
            Log.error(error, context: "Saving receipt image", category: .database)
            return nil
        }
    }

    static func load(_ filename: String) -> UIImage? {
        guard !filename.isEmpty else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(filename).path)
    }

    static func delete(_ filename: String) {
        guard !filename.isEmpty else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename))
    }

    /// Bytes on disk, for a "Size: 245 KB" row — `nil` if the file is missing.
    static func fileSize(_ filename: String) -> Int? {
        guard !filename.isEmpty else { return nil }
        let attrs = try? FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent(filename).path)
        return attrs?[.size] as? Int
    }
}
