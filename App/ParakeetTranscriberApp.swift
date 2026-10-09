import AppKit
import Sparkle
import SwiftUI

@main
@MainActor
struct ParakeetTranscriberApp: App {
    @StateObject private var store: TranscriptionStore
    private let updaterController: SPUStandardUpdaterController
    private let finderServices: FinderServices

    init() {
        let store = TranscriptionStore()
        _store = StateObject(wrappedValue: store)
        finderServices = FinderServices(store: store)
        NSApplication.shared.servicesProvider = finderServices
        NSUpdateDynamicServices()
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
                .frame(minWidth: 720, idealWidth: 820, minHeight: 460, idealHeight: 520)
                .onOpenURL { url in
                    store.add([url])
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 820, height: 520)
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
                .disabled(store.isRunning)
            }
            CommandGroup(after: .pasteboard) {
                Button("Add Files from Clipboard", action: store.addClipboardFiles)
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                    .disabled(store.isRunning)
            }
        }
    }
}
