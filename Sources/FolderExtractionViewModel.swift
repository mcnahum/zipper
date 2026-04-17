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
        var originalsDeleted: Bool
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
    @Published private(set) var successfulArchiveIDs: Set<String> = []
    @Published private(set) var failedArchiveIDs: Set<String> = []
    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: PreferenceKeys.appearanceMode)
        }
    }

    private var activeTask: ArchiveTask?
    private var knownArchivesByID: [String: ArchiveItem] = [:]

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

    var successfulArchiveSetCount: Int {
        successfulArchiveIDs.count
    }

    var successfulOriginalFileCount: Int {
        successfulArchiveIDs.reduce(into: 0) { total, archiveID in
            total += currentArchive(for: archiveID)?.relatedPartURLs.count ?? 0
        }
    }

    var canDeleteSuccessfulArchives: Bool {
        !successfulArchiveIDs.isEmpty
    }

    var canRetryFailedArchives: Bool {
        !failedArchiveIDs.isEmpty
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
            knownArchivesByID.merge(
                Dictionary(uniqueKeysWithValues: refreshedArchives.map { ($0.id, $0) }),
                uniquingKeysWith: { _, new in new }
            )

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

            successfulArchiveIDs = successfulArchiveIDs.intersection(Set(refreshedArchives.map(\.id)))
            failedArchiveIDs = failedArchiveIDs.intersection(Set(refreshedArchives.map(\.id)))
        } catch {
            archives = []
            selectedIDs = []
            progressMessage = "Could not read \(workingFolderURL.path)."
            userMessage = UserMessage(text: error.localizedDescription, isError: true)
        }
    }

    func startExtraction() {
        let queue = archives.filter { selectedIDs.contains($0.id) && $0.canExtract }
        beginProcessing(queue, replaceJobs: true)
    }

    func retryFailedArchives() {
        let queue = archives.filter { failedArchiveIDs.contains($0.id) && $0.canExtract }
        beginProcessing(queue, replaceJobs: false)
    }

    func retryArchive(_ archiveID: String) {
        guard let archive = archives.first(where: { $0.id == archiveID && $0.canExtract }) else {
            userMessage = UserMessage(
                text: "That archive is no longer available in the working folder.",
                isError: true
            )
            return
        }

        beginProcessing([archive], replaceJobs: false)
    }

    func deleteSuccessfulArchives() {
        guard !isExtracting else { return }
        guard canDeleteSuccessfulArchives else { return }

        let archiveIDs = successfulArchiveIDs
        let archiveItems = archiveIDs.compactMap { currentArchive(for: $0) }

        guard !archiveItems.isEmpty else {
            userMessage = UserMessage(
                text: "No extracted archives are available to delete anymore.",
                isError: true
            )
            successfulArchiveIDs = []
            return
        }

        let fileManager = FileManager.default
        var deletedFileCount = 0
        var failureMessages: [String] = []
        var fullyDeletedArchiveIDs = Set<String>()

        for archive in archiveItems {
            var archiveDeletedSuccessfully = true

            for url in archive.relatedPartURLs {
                guard fileManager.fileExists(atPath: url.path) else { continue }

                do {
                    try fileManager.removeItem(at: url)
                    deletedFileCount += 1
                } catch {
                    archiveDeletedSuccessfully = false
                    failureMessages.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }

            if archiveDeletedSuccessfully {
                fullyDeletedArchiveIDs.insert(archive.id)
                updateJobDetail(
                    archiveID: archive.id,
                    appendedText: "Original archive files deleted."
                )
            }
        }

        successfulArchiveIDs.subtract(fullyDeletedArchiveIDs)
        selectedIDs.subtract(fullyDeletedArchiveIDs)
        refreshArchives()

        if failureMessages.isEmpty {
            userMessage = UserMessage(
                text: "Deleted \(deletedFileCount) original archive file(s) from successful extractions only.",
                isError: false
            )
        } else {
            userMessage = UserMessage(
                text: "Deleted \(deletedFileCount) successful archive file(s), but some selected originals could not be removed.",
                isError: true
            )
            lastReport = failureMessages.joined(separator: "\n")
        }
    }

    private func beginProcessing(_ queue: [ArchiveItem], replaceJobs: Bool) {
        guard !isExtracting else { return }
        guard !queue.isEmpty else {
            userMessage = UserMessage(text: "Select at least one extractable archive.", isError: true)
            return
        }

        lastReport = nil
        userMessage = nil

        if replaceJobs {
            jobs = queue.map { job(for: $0) }
        } else {
            for archive in queue {
                if let index = jobs.firstIndex(where: { $0.id == archive.id }) {
                    jobs[index] = job(for: archive)
                } else {
                    jobs.append(job(for: archive))
                }
            }
        }

        isExtracting = true
        progressMessage = "Preparing extraction queue..."

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

                successfulArchiveIDs.insert(archive.id)
                failedArchiveIDs.remove(archive.id)
                markJob(archiveID: archive.id, status: .succeeded, detail: successDetail, fraction: 1.0)
            } catch {
                failureMessages.append("\(archive.fileName): \(error.localizedDescription)")
                failedArchiveIDs.insert(archive.id)
                successfulArchiveIDs.remove(archive.id)
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

    private func currentArchive(for archiveID: String) -> ArchiveItem? {
        archives.first(where: { $0.id == archiveID }) ?? knownArchivesByID[archiveID]
    }

    private func job(for archive: ArchiveItem) -> ExtractionJob {
        ExtractionJob(
            id: archive.id,
            archiveName: archive.fileName,
            status: .pending,
            detail: archive.detailText,
            fractionCompleted: 0,
            originalsDeleted: false
        )
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

        if status != .succeeded {
            jobs[index].originalsDeleted = false
        }
    }

    private func updateJobDetail(archiveID: String, appendedText: String) {
        guard let index = jobs.firstIndex(where: { $0.id == archiveID }) else { return }

        if !jobs[index].detail.contains(appendedText) {
            jobs[index].detail += " \(appendedText)"
        }

        if appendedText.localizedCaseInsensitiveContains("original archive files deleted") {
            jobs[index].originalsDeleted = true
        }
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
