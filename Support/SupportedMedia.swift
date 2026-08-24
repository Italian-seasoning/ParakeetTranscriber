import UniformTypeIdentifiers

enum SupportedMedia {
    static let contentTypes: [UTType] = [.audio, .movie, .audiovisualContent]

    static func contains(_ url: URL) -> Bool {
        guard url.isFileURL,
              let type = UTType(filenameExtension: url.pathExtension)
        else { return false }

        return contentTypes.contains { type.conforms(to: $0) }
    }
}
