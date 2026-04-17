import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: FolderExtractionViewModel
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                archiveListSection
                queueSection
                footerSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .frame(minWidth: 760, minHeight: 620)
        .background(Theme.windowBackground)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(viewModel.isExtracting ? "Extracting..." : "Extract Selected", systemImage: "arrow.down.doc.fill") {
                    viewModel.startExtraction()
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.accent)
                .disabled(viewModel.isExtracting || viewModel.selectedArchiveCount == 0)
                .help("Extract the selected RAR archive sets.")
            }
        }
        .onAppear {
            viewModel.refreshArchives()
        }
        .alert("Delete Successful Original Archives?", isPresented: $isShowingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteSuccessfulArchives()
            }
        } message: {
            Text(
                "Delete only the \(viewModel.successfulOriginalFileCount) original RAR file(s) belonging to the \(viewModel.successfulArchiveSetCount) successful extraction(s). Failed archives will be kept."
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    headerCopy
                    Spacer(minLength: 12)
                    statsStrip
                }

                VStack(alignment: .leading, spacing: 16) {
                    headerCopy
                    statsStrip
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    workingFolderCopy

                    Spacer(minLength: 12)

                    workingFolderActions
                }

                VStack(alignment: .leading, spacing: 12) {
                    workingFolderCopy
                    workingFolderActions
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassEffect(.regular, in: Theme.rowShape)
            .overlay {
                Theme.rowShape
                    .strokeBorder(Theme.border, lineWidth: 1)
            }
        }
        .modifier(AppGlassPanelModifier())
    }

    private var workingFolderCopy: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "externaldrive.badge.folder")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text("Working Folder")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(viewModel.workingFolderURL.path)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(2)
            }
        }
    }

    private var workingFolderActions: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.chooseWorkingFolder()
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(.glass)
            .help("Change the working folder PowerUnRar scans for RAR archives.")

            Button {
                viewModel.refreshArchives()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.glass)
            .help("Refresh the archive list in the current working folder.")
        }
        .labelStyle(.iconOnly)
        .controlSize(.large)
        .accessibilityElement(children: .contain)
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PowerUnRar")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text("Scan one folder, select the RAR sets you want, and extract them one after another into dedicated folders.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statsStrip: some View {
        GlassEffectContainer(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    statsBadges
                }

                VStack(alignment: .leading, spacing: 10) {
                    statsBadges
                }
            }
        }
    }

    private var statsBadges: some View {
        Group {
            StatusBadge(title: "Found", value: "\(viewModel.archives.count)", tint: Theme.accent)
            StatusBadge(title: "Selected", value: "\(viewModel.selectedArchiveCount)", tint: Theme.accent)
            StatusBadge(
                title: "Queue",
                value: viewModel.isExtracting ? "Running" : "Ready",
                tint: viewModel.isExtracting ? Theme.accent : Theme.success
            )
        }
    }

    private var archiveListSection: some View {
        GlassSection(
            title: "Archives",
            systemImage: "doc.on.doc",
            accessory: {
                HStack(spacing: 12) {
                    Text("Selected \(viewModel.selectedArchiveCount) of \(viewModel.selectableArchiveCount)")
                        .foregroundStyle(.secondary)

                    Button(viewModel.allSelectableArchivesSelected ? "Unselect All" : "Select All") {
                        viewModel.toggleSelectAll()
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .disabled(viewModel.selectableArchiveCount == 0)
                    .help(viewModel.allSelectableArchivesSelected ? "Clear the current selection." : "Select every archive set that can be extracted.")
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Found \(viewModel.archives.count) archive set(s)")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if viewModel.archives.isEmpty {
                    ContentUnavailableView(
                        "No RAR archives found",
                        systemImage: "archivebox",
                        description: Text("PowerUnRar checks only the selected folder, not subfolders.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    ScrollView {
                        GlassEffectContainer(spacing: 10) {
                            LazyVStack(spacing: 10) {
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
                        .padding(.trailing, 2)
                    }
                    .frame(minHeight: 240)
                }
            }
        }
    }

    private var queueSection: some View {
        GlassSection(title: "Queue", systemImage: "list.number") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Queue Progress")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if viewModel.jobs.isEmpty {
                    ContentUnavailableView(
                        "No extraction run yet",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Start extraction to keep a live progress list here.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 150)
                } else {
                    ScrollView {
                        GlassEffectContainer(spacing: 10) {
                            LazyVStack(spacing: 10) {
                                ForEach(viewModel.jobs) { job in
                                    ExtractionJobRow(
                                        job: job,
                                        onRetry: job.status == .failed ? {
                                            viewModel.retryArchive(job.id)
                                        } : nil
                                    )
                                }
                            }
                        }
                        .padding(.trailing, 2)
                    }
                    .frame(minHeight: 180)
                }
            }
        }
    }

    private var footerSection: some View {
        GlassSection(title: "Run Details", systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 14) {
                if let message = viewModel.userMessage {
                    Label(message.text, systemImage: message.isError ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
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
                    .frame(minHeight: 96, maxHeight: 150)
                    .padding(12)
                    .glassEffect(.regular, in: Theme.rowShape)
                    .overlay {
                        Theme.rowShape
                            .strokeBorder(Theme.border, lineWidth: 1)
                    }
                }

                HStack {
                    if viewModel.canRetryFailedArchives {
                        Button("Retry Failed") {
                            viewModel.retryFailedArchives()
                        }
                        .buttonStyle(.glass)
                        .disabled(viewModel.isExtracting)
                        .help("Retry all failed archive extractions.")
                    }

                    if viewModel.canDeleteSuccessfulArchives {
                        Button("Delete Successful Originals") {
                            isShowingDeleteConfirmation = true
                        }
                        .buttonStyle(.glass)
                        .disabled(viewModel.isExtracting)
                        .help("Delete the original archives for extractions that finished successfully.")
                    }

                    Spacer()

                    Button(viewModel.isExtracting ? "Extracting..." : "Extract Selected") {
                        viewModel.startExtraction()
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.accent)
                    .disabled(viewModel.isExtracting || viewModel.selectedArchiveCount == 0)
                    .help("Extract the selected RAR archive sets.")
                }
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
        .glassEffect(archiveGlass, in: Theme.rowShape)
        .overlay {
            Theme.rowShape
                .strokeBorder(archiveBorder, lineWidth: 1)
        }
    }

    private var archiveGlass: Glass {
        archive.canExtract ? .regular : .regular.tint(Theme.failure.opacity(0.10))
    }

    private var archiveBorder: Color {
        archive.canExtract ? Theme.softBorder : Theme.failure.opacity(0.25)
    }
}

private struct ExtractionJobRow: View {
    let job: FolderExtractionViewModel.ExtractionJob
    let onRetry: (() -> Void)?

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

                    if job.originalsDeleted {
                        Text("Deleted")
                            .font(.caption)
                            .foregroundStyle(Theme.systemAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .glassEffect(.regular.tint(Theme.systemAccent.opacity(0.16)), in: Capsule(style: .continuous))
                    }

                    if let onRetry {
                        Button("Retry") {
                            onRetry()
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .help("Retry this failed archive extraction.")
                    }
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
        .glassEffect(rowGlass, in: Theme.rowShape)
        .overlay {
            Theme.rowShape
                .strokeBorder(rowBorder, lineWidth: 1)
        }
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

    private var rowGlass: Glass {
        job.originalsDeleted ? .regular.tint(Theme.systemAccent.opacity(0.14)).interactive() : .regular.interactive()
    }

    private var rowBorder: Color {
        job.originalsDeleted ? Theme.systemAccent.opacity(0.30) : Theme.softBorder
    }
}

private struct GlassSection<Accessory: View, Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let accessory: () -> Accessory
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accessory = accessory
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label(title, systemImage: systemImage)
                    .font(.headline)

                Spacer()

                accessory()
            }

            content()
        }
        .modifier(AppGlassPanelModifier())
    }
}

private struct StatusBadge: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(tint.opacity(0.12)), in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        }
    }
}

private struct AppGlassPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background {
                Theme.panelShape
                    .fill(.white.opacity(0.025))
            }
            .glassEffect(.regular, in: Theme.panelShape)
            .overlay {
                Theme.panelShape
                    .strokeBorder(Theme.border, lineWidth: 1)
            }
            .shadow(color: Theme.panelShadow, radius: 24, y: 12)
    }
}
