import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedURL: URL?
    @State private var isDropTargeted = false
    @State private var iconBreathing = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if let url = selectedURL {
                ConfigurationView(url: url) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedURL = nil
                    }
                }
                .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted, perform: handleDrop)
                .transition(.opacity)
            } else {
                dropZone
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedURL != nil)
    }

    // MARK: - Drop Zone

    private var dropZone: some View {
        VStack(spacing: 0) {
            Text("Z I P P E R")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 32)

            Spacer()

            VStack(spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Theme.surface)
                        .frame(width: 120, height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(
                                    isDropTargeted ? Theme.accent.opacity(0.7) : Theme.border,
                                    lineWidth: isDropTargeted ? 2 : 1
                                )
                        )

                    Image(systemName: "doc.zipper")
                        .font(.system(size: 46, weight: .ultraLight))
                        .foregroundStyle(isDropTargeted ? Theme.accent : Theme.textSecondary)
                        .opacity(iconBreathing ? 1.0 : 0.65)
                        .scaleEffect(isDropTargeted ? 1.06 : 1.0)
                }
                .animation(.easeInOut(duration: 0.2), value: isDropTargeted)

                VStack(spacing: 6) {
                    Text("Drop file or folder")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }

            Spacer()

            Button("Choose Item", action: selectFile)
                .buttonStyle(GoldButtonStyle())
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted, perform: handleDrop)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                iconBreathing = true
            }
        }
    }

    // MARK: - Actions

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedURL = url
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            var droppedURL: URL?

            if let data = item as? Data {
                droppedURL = URL(dataRepresentation: data, relativeTo: nil)
            } else if let url = item as? URL {
                droppedURL = url
            }

            guard let url = droppedURL else {
                _ = provider.loadObject(ofClass: URL.self) { fallbackURL, _ in
                    guard let fallbackURL else { return }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedURL = fallbackURL
                        }
                    }
                }
                return
            }

            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedURL = url
                }
            }
        }

        return true
    }
}
