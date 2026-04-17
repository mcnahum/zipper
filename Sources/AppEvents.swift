import Foundation

enum ArchiveKind: String {
    case singleRAR = "Single RAR"
    case multipartRAR = "Multi-part RAR"
    case legacyMultipartRAR = "Legacy multi-part RAR"
    case incompleteMultipartRAR = "Incomplete multi-part RAR"
}

struct ArchiveItem: Identifiable, Hashable {
    let id: String
    let rootURL: URL
    let relatedPartURLs: [URL]
    let kind: ArchiveKind
    let canExtract: Bool
    let detailText: String

    var fileName: String {
        rootURL.lastPathComponent
    }

    var extractionFolderName: String {
        ArchiveFileClassifier.extractionFolderName(for: rootURL)
    }

    var partCount: Int {
        relatedPartURLs.count
    }
}

enum ArchiveFileClassifier {
    private static let multipartRegex = try! NSRegularExpression(pattern: #"(?i)^(.*)\.part(\d+)\.rar$"#)
    private static let legacyPartRegex = try! NSRegularExpression(pattern: #"(?i)^(.*)\.r(\d{2,3})$"#)

    struct MultipartMatch {
        let stem: String
        let partNumber: Int
    }

    static func multipartMatch(for url: URL) -> MultipartMatch? {
        let fileName = url.lastPathComponent
        let range = NSRange(fileName.startIndex..<fileName.endIndex, in: fileName)

        guard let match = multipartRegex.firstMatch(in: fileName, range: range),
              let stemRange = Range(match.range(at: 1), in: fileName),
              let numberRange = Range(match.range(at: 2), in: fileName),
              let partNumber = Int(fileName[numberRange]) else {
            return nil
        }

        return MultipartMatch(
            stem: String(fileName[stemRange]).lowercased(),
            partNumber: partNumber
        )
    }

    static func legacyStem(for url: URL) -> String? {
        let fileName = url.lastPathComponent
        let range = NSRange(fileName.startIndex..<fileName.endIndex, in: fileName)

        guard let match = legacyPartRegex.firstMatch(in: fileName, range: range),
              let stemRange = Range(match.range(at: 1), in: fileName) else {
            return nil
        }

        return String(fileName[stemRange]).lowercased()
    }

    static func legacyPartNumber(for url: URL) -> Int? {
        let fileName = url.lastPathComponent
        let range = NSRange(fileName.startIndex..<fileName.endIndex, in: fileName)

        guard let match = legacyPartRegex.firstMatch(in: fileName, range: range),
              let numberRange = Range(match.range(at: 2), in: fileName) else {
            return nil
        }

        return Int(fileName[numberRange])
    }

    static func rarStem(for url: URL) -> String {
        url.deletingPathExtension().lastPathComponent.lowercased()
    }

    static func isRARFile(_ url: URL) -> Bool {
        !url.hasDirectoryPath && url.pathExtension.lowercased() == "rar"
    }

    static func extractionFolderName(for url: URL) -> String {
        let fileName = url.lastPathComponent

        if let match = multipartMatch(for: url) {
            return match.stem
        }

        if fileName.lowercased().hasSuffix(".rar") {
            return url.deletingPathExtension().lastPathComponent
        }

        return fileName
    }
}

enum FolderArchiveScanner {
    static func scan(in folderURL: URL) throws -> [ArchiveItem] {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        let files = contents.filter { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            return values?.isDirectory != true
        }

        var multipartSets: [String: [(url: URL, part: Int)]] = [:]
        var legacySets: [String: [URL]] = [:]
        var rootRARs: [String: URL] = [:]

        for url in files {
            if let multipartMatch = ArchiveFileClassifier.multipartMatch(for: url) {
                multipartSets[multipartMatch.stem, default: []].append((url, multipartMatch.partNumber))
                continue
            }

            if let legacyStem = ArchiveFileClassifier.legacyStem(for: url) {
                legacySets[legacyStem, default: []].append(url)
                continue
            }

            guard ArchiveFileClassifier.isRARFile(url) else { continue }
            rootRARs[ArchiveFileClassifier.rarStem(for: url)] = url
        }

        var items: [ArchiveItem] = []
        var consumedRootRARStems = Set<String>()

        for stem in multipartSets.keys.sorted() {
            let sortedParts = multipartSets[stem, default: []].sorted { lhs, rhs in
                lhs.part < rhs.part
            }

            guard let firstPart = sortedParts.first else { continue }

            let hasPartOne = sortedParts.contains(where: { $0.part == 1 })
            let rootURL = (sortedParts.first { $0.part == 1 }?.url) ?? firstPart.url
            let partURLs = sortedParts.map(\.url)
            let detailText: String
            let kind: ArchiveKind

            if hasPartOne {
                kind = .multipartRAR
                detailText = "\(partURLs.count) parts detected"
            } else {
                kind = .incompleteMultipartRAR
                detailText = "Missing part 1"
            }

            items.append(
                ArchiveItem(
                    id: rootURL.path,
                    rootURL: rootURL,
                    relatedPartURLs: partURLs,
                    kind: kind,
                    canExtract: hasPartOne,
                    detailText: detailText
                )
            )
        }

        for stem in legacySets.keys.sorted() {
            guard let rootURL = rootRARs[stem] else { continue }

            let partURLs = legacySets[stem, default: []].sorted { lhs, rhs in
                (ArchiveFileClassifier.legacyPartNumber(for: lhs) ?? 0) < (ArchiveFileClassifier.legacyPartNumber(for: rhs) ?? 0)
            }

            let urls = [rootURL] + partURLs
            consumedRootRARStems.insert(stem)

            items.append(
                ArchiveItem(
                    id: rootURL.path,
                    rootURL: rootURL,
                    relatedPartURLs: urls,
                    kind: .legacyMultipartRAR,
                    canExtract: true,
                    detailText: "\(urls.count) parts detected"
                )
            )
        }

        for stem in rootRARs.keys.sorted() where !consumedRootRARStems.contains(stem) {
            guard let rootURL = rootRARs[stem] else { continue }

            items.append(
                ArchiveItem(
                    id: rootURL.path,
                    rootURL: rootURL,
                    relatedPartURLs: [rootURL],
                    kind: .singleRAR,
                    canExtract: true,
                    detailText: "Ready to extract"
                )
            )
        }

        return items.sorted {
            $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending
        }
    }
}
