import AppKit
import Foundation

@MainActor
final class FolderExtractionViewModel: ObservableObject {
    struct UserMessage: Identifiable {
        let id = UUID()
        let text: String
        let isError: Bool
    }

    struct ExtractionJob: Identifiable {
        enum Status {
            case pending
            case running
            case succeeded
            case failed
        }

        let id: String
        let archiveName: String
        var status: Status
        var detail: String
        var fractionCompleted: Double
    }

    let defaultFolderPath = "/Volumes/BD"

    @Published var workingFolderURL: URL
    @Published var archives: [ArchiveItem] = []
    @Published var selectedIDs: Set<String> = []
    @Published var jobs: [ExtractionJob] = []
    @Published var isExtracting = false
    @Published var progressMessage = "Choose a folder and refresh the archive list."
    @Published var lastReport: String?
    @Published var userMessage: UserMessage?
    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: PreferenceKeys.appearanceMode)
        }
    }

    private var activeTask: ArchiveTask?

    init() {
        let savedPath = UserDefaults.standard.string(forKey: PreferenceKeys.workingFolderPath)
        let initialPath = savedPath?.isEmpty == false ? savedPath! : defaultFolderPath
        self.workingFolderURL = URL(fileURLWithPath: initialPath, isDirectory: true)

        let savedAppearance = UserDefaults.standard.string(forKey: PreferenceKeys.appearanceMode)
        self.appearanceMode = AppearanceMode(rawValue: savedAppearance ?? "") ?? .auto

        refreshArchives()
    }

    var selectableArchiveCount: Int {
        archives.filter(\.canExtract).count
    }

    var selectedArchiveCount: Int {
        archives.filter { selectedIDs.contains($0.id) }.count
    }

    var allSelectableArchivesSelected: Bool {
        let selectable = Set(archives.filter(\.canExtract).map(\.id))
        return !selectable.isEmpty && selectable.isSubset(of: selectedIDs)
    }

    func isSelected(_ archive: ArchiveItem) -> Bool {
        selectedIDs.contains(archive.id)
    }

    func setSelected(_ isSelected: Bool, for archive: ArchiveItem) {
        guard archive.canExtract else { return }

        if isSelected {
            selectedIDs.insert(archive.id)
        } else {
            selectedIDs.remove(archive.id)
        }
    }

    func toggleSelectAll() {
        let selectableIDs = Set(archives.filter(\.canExtract).map(\.id))

        if selectableIDs.isSubset(of: selectedIDs) {
            selectedIDs.subtract(selectableIDs)
        } else {
            selectedIDs.formUnion(selectableIDs)
        }
    }

    func chooseWorkingFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Working Folder"
        panel.message = "PowerUnRar scans only the selected folder, not its subfolders."
        panel.prompt = "Choose Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            setWorkingFolder(url)
        }
    }

    func resetWorkingFolder() {
        setWorkingFolder(URL(fileURLWithPath: defaultFolderPath, isDirectory: true))
    }

    func refreshArchives() {
        do {
            let refreshedArchives = try FolderArchiveScanner.scan(in: workingFolderURL)
            archives = refreshedArchives

            let selectableIDs = Set(refreshedArchives.filter(\.canExtract).map(\.id))
            if selectedIDs.isEmpty {
                selectedIDs = selectableIDs
            } else {
                selectedIDs = selectedIDs.intersection(selectableIDs)
                if selectedIDs.isEmpty {
                    selectedIDs = selectableIDs
                }
            }

            if refreshedArchives.isEmpty {
                progressMessage = "No RAR archives were found in \(workingFolderURL.path)."
            } else {
                progressMessage = "Found \(refreshedArchives.count) archive set(s) in \(workingFolderURL.lastPathComponent)."
            }
        } catch {
            archives = []
            selectedIDs = []
            progressMessage = "Could not read \(workingFolderURL.path)."
            userMessage = UserMessage(text: error.localizedDescription, isError: true)
        }
    }

    func startExtraction() {
        guard !isExtracting else { return }

        let queue = archives.filter { selectedIDs.contains($0.id) && $0.canExtract }
        guard !queue.isEmpty else {
            userMessage = UserMessage(text: "Select at least one extractable archive.", isError: true)
            return
        }

        lastReport = nil
        jobs = queue.map {
            ExtractionJob(
                id: $0.id,
                archiveName: $0.fileName,
                status: .pending,
                detail: $0.detailText,
                fractionCompleted: 0
            )
        }
        isExtracting = true
        progressMessage = "Preparing extraction queue..."
        userMessage = nil

        Task {
            await processQueue(queue)
        }
    }

    private func processQueue(_ queue: [ArchiveItem]) async {
        var successCount = 0
        var failureMessages: [String] = []
        var renamedCount = 0
        var createdFolders: [String] = []

        for (index, archive) in queue.enumerated() {
            markJob(archiveID: archive.id, status: .running, detail: "Starting extraction...", fraction: 0)
            progressMessage = "Extracting \(index + 1) of \(queue.count): \(archive.fileName)"

            let destinationURL = uniqueDestinationFolder(
                in: workingFolderURL,
                preferredName: archive.extractionFolderName
            )

            do {
                try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
                try await extractArchive(
                    archiveURL: archive.rootURL,
                    destinationURL: destinationURL,
                    archiveID: archive.id
                )

                let renamedItems = cleanupLeadingZZZNames(in: destinationURL)
                renamedCount += renamedItems
                successCount += 1
                createdFolders.append(destinationURL.lastPathComponent)

                let successDetail: String
                if renamedItems > 0 {
                    successDetail = "Done. Renamed \(renamedItems) extracted item(s)."
                } else {
                    successDetail = "Done."
                }

                markJob(archiveID: archive.id, status: .succeeded, detail: successDetail, fraction: 1.0)
            } catch {
                failureMessages.append("\(archive.fileName): \(error.localizedDescription)")
                markJob(
                    archiveID: archive.id,
                    status: .failed,
                    detail: error.localizedDescription,
                    fraction: 0
                )
            }
        }

        activeTask = nil
        isExtracting = false
        progressMessage = "Finished \(queue.count) archive extraction task(s)."
        lastReport = buildReport(
            queueCount: queue.count,
            successCount: successCount,
            renamedCount: renamedCount,
            createdFolders: createdFolders,
            failures: failureMessages
        )
        refreshArchives()
    }

    private func extractArchive(
        archiveURL: URL,
        destinationURL: URL,
        archiveID: String
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            activeTask = ArchiveEngine.shared.extract(
                archiveURL: archiveURL,
                destinationURL: destinationURL,
                progress: { [weak self] update in
                    Task { @MainActor [weak self] in
                        guard let self else { return }

                        let detail = update.detail ?? self.currentDetail(for: archiveID)
                        let fraction = update.fractionCompleted ?? self.currentFraction(for: archiveID)
                        self.markJob(
                            archiveID: archiveID,
                            status: .running,
                            detail: detail,
                            fraction: fraction
                        )
                    }
                },
                completion: { result in
                    Task { @MainActor in
                        switch result {
                        case .success:
                            continuation.resume()
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                }
            )
        }
    }

    private func setWorkingFolder(_ url: URL) {
        workingFolderURL = url
        UserDefaults.standard.set(url.path, forKey: PreferenceKeys.workingFolderPath)
        refreshArchives()
    }

    private func uniqueDestinationFolder(in parentURL: URL, preferredName: String) -> URL {
        let fileManager = FileManager.default
        var candidate = parentURL.appendingPathComponent(preferredName, isDirectory: true)
        var suffix = 2

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = parentURL.appendingPathComponent("\(preferredName) \(suffix)", isDirectory: true)
            suffix += 1
        }

        return candidate
    }

    private func cleanupLeadingZZZNames(in folderURL: URL) -> Int {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        let urls = (enumerator.allObjects as? [URL] ?? []).sorted {
            $0.path.count > $1.path.count
        }

        var renameCount = 0

        for url in urls {
            let fileName = url.lastPathComponent
            let lowercased = fileName.lowercased()

            guard lowercased.hasPrefix("zz") else { continue }

            let trimmedName = fileName.replacingOccurrences(
                of: #"^(?i)z{2,3}"#,
                with: "",
                options: .regularExpression
            )

            guard !trimmedName.isEmpty, trimmedName != fileName else { continue }

            let destinationURL = url.deletingLastPathComponent().appendingPathComponent(trimmedName)
            guard !fileManager.fileExists(atPath: destinationURL.path) else { continue }

            do {
                try fileManager.moveItem(at: url, to: destinationURL)
                renameCount += 1
            } catch {
                continue
            }
        }

        return renameCount
    }

    private func currentDetail(for archiveID: String) -> String {
        jobs.first(where: { $0.id == archiveID })?.detail ?? "Extracting..."
    }

    private func currentFraction(for archiveID: String) -> Double {
        jobs.first(where: { $0.id == archiveID })?.fractionCompleted ?? 0
    }

    private func markJob(
        archiveID: String,
        status: ExtractionJob.Status,
        detail: String,
        fraction: Double
    ) {
        guard let index = jobs.firstIndex(where: { $0.id == archiveID }) else { return }
        jobs[index].status = status
        jobs[index].detail = detail
        jobs[index].fractionCompleted = min(max(fraction, 0), 1)
    }

    private func buildReport(
        queueCount: Int,
        successCount: Int,
        renamedCount: Int,
        createdFolders: [String],
        failures: [String]
    ) -> String {
        var lines = [
            "Processed \(queueCount) archive set(s).",
            "Succeeded: \(successCount).",
            "Failed: \(failures.count)."
        ]

        if renamedCount > 0 {
            lines.append("Renamed \(renamedCount) extracted item(s) to remove leading zz/zzz prefixes.")
        }

        if !createdFolders.isEmpty {
            let joinedFolders = createdFolders.joined(separator: ", ")
            lines.append("Created folders: \(joinedFolders)")
        }

        if !failures.isEmpty {
            lines.append("Failures:")
            lines.append(contentsOf: failures.map { "• \($0)" })
        }

        return lines.joined(separator: "\n")
    }
}
