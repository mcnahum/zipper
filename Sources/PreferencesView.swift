import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var viewModel: FolderExtractionViewModel

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Mode", selection: $viewModel.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Working Folder") {
                Text(viewModel.workingFolderURL.path)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(2)

                HStack {
                    Button("Choose Folder") {
                        viewModel.chooseWorkingFolder()
                    }

                    Button("Reset to /Volumes/BD") {
                        viewModel.resetWorkingFolder()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(18)
        .frame(width: 520, height: 220)
    }
}
