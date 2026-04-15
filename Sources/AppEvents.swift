import Foundation
import Combine

enum FileOperationKind {
    case compress
    case extract
}

enum ArchiveFileClassifier {
    static let selectableArchiveExtensions = [
        "zip", "rar", "7z",
        "tar", "gz", "tgz",
        "bz2", "tbz", "tbz2",
        "xz", "txz"
    ]

    private static let archiveExtensions: Set<String> = [
        "zip", "rar", "7z",
        "tar", "gz", "tgz",
        "bz2", "tbz", "tbz2",
        "xz", "txz"
    ]

    private static let multiPartArchiveExtensions = [
        "tar.gz", "tar.bz2", "tar.xz"
    ]

    static func isArchive(_ url: URL) -> Bool {
        guard !url.hasDirectoryPath else { return false }
        let lowercasedName = url.lastPathComponent.lowercased()
        if multiPartArchiveExtensions.contains(where: { lowercasedName.hasSuffix(".\($0)") }) {
            return true
        }

        return archiveExtensions.contains(url.pathExtension.lowercased())
    }

    static func extractionFolderName(for url: URL) -> String {
        let lowercasedName = url.lastPathComponent.lowercased()
        for multiPartExtension in multiPartArchiveExtensions where lowercasedName.hasSuffix(".\(multiPartExtension)") {
            let suffixLength = multiPartExtension.count + 1
            return String(url.lastPathComponent.dropLast(suffixLength))
        }

        let trimmedName = url.deletingPathExtension().lastPathComponent
        return trimmedName.isEmpty ? url.lastPathComponent : trimmedName
    }
}
