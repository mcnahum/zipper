import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: FolderExtractionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            archiveListSection
            queueSection
            footerSection
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 620)
        .background(.background)
        .onAppear {
            viewModel.refreshArchives()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PowerUnRar")
                .font(.system(size: 28, weight: .bold))

            Text("Scan one folder, select the RAR sets you want, and extract them one after another into dedicated folders.")
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Working Folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(viewModel.workingFolderURL.path)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(2)
                }

                Spacer()

                Button("Choose Folder") {
                    viewModel.chooseWorkingFolder()
                }
                .buttonStyle(AppSecondaryButtonStyle())

                Button("Refresh") {
                    viewModel.refreshArchives()
                }
                .buttonStyle(AppSecondaryButtonStyle())
            }
        }
    }

    private var archiveListSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Found \(viewModel.archives.count) archive set(s)")
                        .font(.headline)

                    Spacer()

                    Text("Selected \(viewModel.selectedArchiveCount) of \(viewModel.selectableArchiveCount)")
                        .foregroundStyle(.secondary)

                    Button(viewModel.allSelectableArchivesSelected ? "Unselect All" : "Select All") {
                        viewModel.toggleSelectAll()
                    }
                    .buttonStyle(AppSecondaryButtonStyle(compact: true))
                    .disabled(viewModel.selectableArchiveCount == 0)
                }

                Divider()

                if viewModel.archives.isEmpty {
                    ContentUnavailableView(
                        "No RAR archives found",
                        systemImage: "archivebox",
                        description: Text("PowerUnRar checks only the selected folder, not subfolders.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.archives) { archive in
                                ArchiveRow(
                                    archive: archive,
                                    isSelected: Binding(
                                        get: { viewModel.isSelected(archive) },
                                        set: { viewModel.setSelected($0, for: archive) }
                                    )
                                )
                            }
                        }
                    }
                    .frame(minHeight: 220)
                }
            }
            .padding(6)
        } label: {
            Label("Archives", systemImage: "doc.on.doc")
        }
    }

    private var queueSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("Queue Progress")
                    .font(.headline)

                if viewModel.jobs.isEmpty {
                    ContentUnavailableView(
                        "No extraction run yet",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Start extraction to keep a live progress list here.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 150)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.jobs) { job in
                                ExtractionJobRow(job: job)
                            }
                        }
                    }
                    .frame(minHeight: 180)
                }
            }
            .padding(6)
        } label: {
            Label("Queue", systemImage: "list.number")
        }
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let message = viewModel.userMessage {
                Text(message.text)
                    .foregroundStyle(message.isError ? Theme.failure : Theme.accent)
            }

            Text(viewModel.progressMessage)
                .font(.headline)

            if let report = viewModel.lastReport {
                ScrollView {
                    Text(report)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
                .frame(minHeight: 90, maxHeight: 140)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.panelBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
            }

            HStack {
                Spacer()

                Button(viewModel.isExtracting ? "Extracting..." : "Extract Selected") {
                    viewModel.startExtraction()
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .disabled(viewModel.isExtracting || viewModel.selectedArchiveCount == 0)
            }
        }
    }
}

private struct ArchiveRow: View {
    let archive: ArchiveItem
    @Binding var isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: $isSelected)
                .labelsHidden()
                .disabled(!archive.canExtract)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(archive.fileName)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Text(archive.kind.rawValue)
                        .font(.caption)
                        .foregroundStyle(archive.canExtract ? .secondary : Theme.failure)
                }

                Text("Destination folder: \(archive.extractionFolderName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(archive.detailText)
                    .font(.caption)
                    .foregroundStyle(archive.canExtract ? .secondary : Theme.failure)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

private struct ExtractionJobRow: View {
    let job: FolderExtractionViewModel.ExtractionJob

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(job.archiveName)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Text(statusLabel)
                        .font(.caption)
                        .foregroundStyle(iconColor)
                }

                Text(job.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)

                ProgressView(value: job.fractionCompleted)
                    .tint(iconColor)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private var iconName: String {
        switch job.status {
        case .pending:
            return "circle"
        case .running:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .succeeded:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch job.status {
        case .pending:
            return .secondary
        case .running:
            return Theme.accent
        case .succeeded:
            return Theme.success
        case .failed:
            return Theme.failure
        }
    }

    private var statusLabel: String {
        switch job.status {
        case .pending:
            return "Pending"
        case .running:
            return "Running"
        case .succeeded:
            return "Done"
        case .failed:
            return "Failed"
        }
    }
}
