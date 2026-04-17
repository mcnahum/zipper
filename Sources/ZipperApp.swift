import AppKit
import SwiftUI

final class PowerUnRarAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct PowerUnRarApp: App {
    @NSApplicationDelegateAdaptor(PowerUnRarAppDelegate.self) private var appDelegate
    @StateObject private var viewModel = FolderExtractionViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .preferredColorScheme(viewModel.appearanceMode.colorScheme)
        }
        .defaultSize(width: 860, height: 700)
        .commands {
            CommandMenu("PowerUnRar") {
                Button("Choose Working Folder") {
                    viewModel.chooseWorkingFolder()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Refresh Archives") {
                    viewModel.refreshArchives()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Divider()

                Button("Extract Selected") {
                    viewModel.startExtraction()
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(viewModel.isExtracting || viewModel.selectedArchiveCount == 0)
            }
        }

        Settings {
            PreferencesView()
                .environmentObject(viewModel)
                .preferredColorScheme(viewModel.appearanceMode.colorScheme)
        }
    }
}
