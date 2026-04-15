import SwiftUI

@main
struct ZipperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 380, minHeight: 520)
                .background(Theme.bg)
        }
        .windowResizability(.automatic)
        .windowStyle(.hiddenTitleBar)
    }
}
