import AppKit

@MainActor
final class FinderServices: NSObject {
    private let store: TranscriptionStore

    init(store: TranscriptionStore) {
        self.store = store
    }

    @objc func transcribeFiles(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard !store.isRunning else {
            error.pointee = "Wait for the current transcription to finish."
            return
        }
        let files = TranscriptionStore.fileURLs(from: pasteboard).filter(SupportedMedia.contains)
        guard !files.isEmpty else {
            error.pointee = "Select supported audio or video files in Finder."
            return
        }
        store.add(files)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
