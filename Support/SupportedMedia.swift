import UniformTypeIdentifiers

enum SupportedMedia {
    // Keep the picker and drop validation aligned with macparakeet-cli.
    static let extensions = ["avi", "flac", "m4a", "mkv", "mov", "mp3", "mp4", "ogg", "opus", "wav", "webm"]
    static let contentTypes = extensions.compactMap { UTType(filenameExtension: $0) }

    static func contains(_ url: URL) -> Bool {
        url.isFileURL && extensions.contains(url.pathExtension.lowercased())
    }
}
