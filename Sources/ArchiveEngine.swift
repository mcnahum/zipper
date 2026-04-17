import Foundation

final class ArchiveTask: @unchecked Sendable {
    var process: Process?
    private(set) var isCancelled = false

    func cancel() {
        isCancelled = true
        if process?.isRunning == true {
            process?.terminate()
        }
    }
}

struct ArchiveProgressUpdate: Sendable {
    let fractionCompleted: Double?
    let detail: String?
}

private final class ProcessOutputState: @unchecked Sendable {
    var log = ""
    var buffer = ""
}

final class ArchiveEngine: @unchecked Sendable {
    static let shared = ArchiveEngine()

    enum ErrorCode {
        static let bundledSevenZipMissing = -1
        static let cancelled = -999
    }

    private let sevenZipPercentRegex = try! NSRegularExpression(pattern: #"(\\d{1,3})%"#)

    @discardableResult
    func extract(
        archiveURL: URL,
        destinationURL: URL,
        progress: @escaping @Sendable (ArchiveProgressUpdate) -> Void,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) -> ArchiveTask {
        let task = ArchiveTask()

        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default

            do {
                let sevenZipURL = try self.bundledSevenZipURL()
                try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)

                let process = Process()
                let pipe = Pipe()
                let outputState = ProcessOutputState()
                let outputStateQueue = DispatchQueue(label: "PowerUnRar.ArchiveEngine.Output")

                process.executableURL = sevenZipURL
                process.currentDirectoryURL = archiveURL.deletingLastPathComponent()
                process.standardOutput = pipe
                process.standardError = pipe
                process.arguments = [
                    "x",
                    "-y",
                    "-bsp1",
                    "-bb1",
                    archiveURL.path,
                    "-o\(destinationURL.path)"
                ]

                task.process = process

                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }

                    outputStateQueue.sync {
                        outputState.log += chunk
                        outputState.buffer += chunk.replacingOccurrences(of: "\r", with: "\n")

                        let lines = outputState.buffer.components(separatedBy: "\n")
                        outputState.buffer = lines.last ?? ""

                        for line in lines.dropLast() {
                            self.reportProgress(from: line, progress: progress)
                        }
                    }
                }

                try process.run()
                process.waitUntilExit()
                pipe.fileHandleForReading.readabilityHandler = nil

                let outputLog = outputStateQueue.sync { outputState.log }
                let outputBuffer = outputStateQueue.sync { outputState.buffer }

                if !outputBuffer.isEmpty {
                    self.reportProgress(from: outputBuffer, progress: progress)
                }

                if task.isCancelled {
                    try? fileManager.removeItem(at: destinationURL)
                    completion(.failure(NSError(
                        domain: "ArchiveError",
                        code: ErrorCode.cancelled,
                        userInfo: [NSLocalizedDescriptionKey: "Extraction cancelled."]
                    )))
                    return
                }

                guard process.terminationStatus == 0 else {
                    try? fileManager.removeItem(at: destinationURL)
                    completion(.failure(NSError(
                        domain: "ArchiveError",
                        code: Int(process.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: self.failureDescription(
                            archiveURL: archiveURL,
                            output: outputLog,
                            terminationStatus: process.terminationStatus
                        )]
                    )))
                    return
                }

                progress(ArchiveProgressUpdate(fractionCompleted: 1.0, detail: "Done"))
                completion(.success(()))
            } catch {
                try? fileManager.removeItem(at: destinationURL)
                completion(.failure(error))
            }
        }

        return task
    }

    private func bundledSevenZipURL() throws -> URL {
        guard let sevenZipURL = Bundle.main.url(forResource: "7zz", withExtension: nil) else {
            throw NSError(
                domain: "ArchiveError",
                code: ErrorCode.bundledSevenZipMissing,
                userInfo: [NSLocalizedDescriptionKey: "Bundled 7zz executable was not found."]
            )
        }

        return sevenZipURL
    }

    private func reportProgress(
        from rawLine: String,
        progress: @escaping @Sendable (ArchiveProgressUpdate) -> Void
    ) {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return }

        if let percentage = percentage(from: line) {
            progress(ArchiveProgressUpdate(fractionCompleted: percentage / 100.0, detail: nil))
        }

        if let detail = progressDetail(from: line) {
            progress(ArchiveProgressUpdate(fractionCompleted: nil, detail: detail))
        }
    }

    private func percentage(from line: String) -> Double? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = sevenZipPercentRegex.firstMatch(in: line, range: range),
              let valueRange = Range(match.range(at: 1), in: line),
              let value = Double(line[valueRange]) else {
            return nil
        }

        return min(max(value, 0), 100)
    }

    private func progressDetail(from line: String) -> String? {
        if line.hasPrefix("- ") {
            return String(line.dropFirst(2))
        }

        if line.lowercased().hasPrefix("extracting") {
            return line
        }

        if line.lowercased().hasPrefix("inflating") {
            return line
        }

        return nil
    }

    private func failureDescription(
        archiveURL: URL,
        output: String,
        terminationStatus: Int32
    ) -> String {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedOutput.isEmpty {
            return "Failed to extract \(archiveURL.lastPathComponent) with exit code \(terminationStatus)."
        }

        return "Failed to extract \(archiveURL.lastPathComponent): \(trimmedOutput)"
    }
}
