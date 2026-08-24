import AppKit
import Sparkle
import SwiftUI

@main
struct ParakeetTranscriberApp: App {
    @StateObject private var store = TranscriptionStore()
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 860, idealWidth: 940, minHeight: 650, idealHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updaterController.checkForUpdates(nil)
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("Add Files…") {
                    store.chooseFiles()
                }
                .keyboardShortcut("o")
            }
        }
    }
}
