import Foundation

/// Disk storage for user documents — exported PDFs/CSVs and scanned receipt images.
///
/// Named `FileStorageManager` rather than `FileManager` so it doesn't shadow
/// `Foundation.FileManager`, which it wraps.
final class FileStorageManager {

    static let shared = FileStorageManager()

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Sub-directories the app writes into.
    enum Directory: String {
        /// Generated reports the user can share. Not backed up — regenerable.
        case exports = "Exports"
        /// Receipt images attached to transactions.
        case receipts = "Receipts"
    }

    // MARK: - Locations

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Returns the directory URL, creating it if it doesn't exist yet.
    func url(for directory: Directory) throws -> URL {
        let url = documentsURL.appendingPathComponent(directory.rawValue, isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    func url(for filename: String, in directory: Directory) throws -> URL {
        try url(for: directory).appendingPathComponent(filename)
    }

    // MARK: - Read / write

    @discardableResult
    func write(_ data: Data, to filename: String, in directory: Directory) throws -> URL {
        let destination = try url(for: filename, in: directory)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    func read(_ filename: String, in directory: Directory) -> Data? {
        guard let source = try? url(for: filename, in: directory) else { return nil }
        return try? Data(contentsOf: source)
    }

    func delete(_ filename: String, in directory: Directory) throws {
        let target = try url(for: filename, in: directory)
        guard fileManager.fileExists(atPath: target.path) else { return }
        try fileManager.removeItem(at: target)
    }

    func contents(of directory: Directory) -> [URL] {
        guard let dir = try? url(for: directory) else { return [] }
        return (try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
    }

    /// Byte size of a stored file, for display in the UI.
    func size(of filename: String, in directory: Directory) -> Int? {
        guard let target = try? url(for: filename, in: directory),
              let attributes = try? fileManager.attributesOfItem(atPath: target.path) else { return nil }
        return attributes[.size] as? Int
    }

    /// Clears everything in a directory — used when signing out.
    func clear(_ directory: Directory) {
        contents(of: directory).forEach { try? fileManager.removeItem(at: $0) }
    }
}
