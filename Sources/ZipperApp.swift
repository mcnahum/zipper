import SwiftUI
import AppKit

final class ExternalFileWindowManager: NSObject, NSWindowDelegate {
    static let shared = ExternalFileWindowManager()

    private var controllers: [NSWindowController] = []

    @MainActor
    func present(_ url: URL) {
        let controller = NSWindowController(window: makeWindow(for: url))
        controllers.append(controller)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    @MainActor
    private func makeWindow(for url: URL) -> NSWindow {
        let hostingController = NSHostingController(
            rootView: ContentView(initialURL: url)
                .frame(minWidth: 380, minHeight: 520)
                .background(Theme.bg)
        )

        let window = NSWindow(contentViewController: hostingController)
        window.delegate = self
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.setContentSize(NSSize(width: 560, height: 620))
        window.minSize = NSSize(width: 380, height: 520)
        window.isReleasedWhenClosed = false
        return window
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }
        controllers.removeAll { $0.window === closingWindow }
    }
}

final class ZipperAppDelegate: NSObject, NSApplicationDelegate {
    @MainActor
    private func routeExternalOpen(urls: [URL], application: NSApplication) {
        for url in urls {
            ExternalFileWindowManager.shared.present(url)
        }

        application.activate(ignoringOtherApps: true)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        Task { @MainActor in
            routeExternalOpen(urls: [url], application: sender)
        }
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        Task { @MainActor in
            routeExternalOpen(urls: urls, application: sender)
        }
        sender.reply(toOpenOrPrint: urls.isEmpty ? .failure : .success)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor in
            routeExternalOpen(urls: urls, application: application)
        }
    }
}

@main
struct ZipperApp: App {
    @NSApplicationDelegateAdaptor(ZipperAppDelegate.self) private var appDelegate
    @AppStorage(PreferenceKeys.openArchivesByDefault) private var openArchivesByDefault = false

    var body: some Scene {
        Window("Zipper", id: "main") {
            ContentView(initialURL: nil)
                .frame(minWidth: 380, minHeight: 520)
                .background(Theme.bg)
                .onAppear {
                    FileAssociationManager.registerCurrentAppIfNeeded()
                    FileAssociationManager.setArchiveAssociation(enabled: openArchivesByDefault)
                }
                .onChange(of: openArchivesByDefault) { enabled in
                    FileAssociationManager.setArchiveAssociation(enabled: enabled)
                }
        }
        .windowResizability(.automatic)
        .windowStyle(.hiddenTitleBar)

        Settings {
            PreferencesView()
        }
    }
}
