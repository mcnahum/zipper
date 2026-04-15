import Foundation
import AppKit
import CoreServices

enum FileAssociationManager {
    private static let archiveTypeIdentifiers = [
        "public.zip-archive",
        "com.rarlab.rar-archive",
        "org.7-zip.7-zip-archive"
    ]

    private static let previousHandlersKey = "preferences.archivePreviousHandlers"

    static func registerCurrentAppIfNeeded() {
        LSRegisterURL(Bundle.main.bundleURL as CFURL, true)
    }

    static func setArchiveAssociation(enabled: Bool) {
        enabled ? registerAsDefaultArchiveHandler() : restorePreviousArchiveHandlers()
    }

    private static func registerAsDefaultArchiveHandler() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }

        var previousHandlers = UserDefaults.standard.dictionary(forKey: previousHandlersKey) as? [String: String] ?? [:]

        for typeIdentifier in archiveTypeIdentifiers {
            let currentHandler = LSCopyDefaultRoleHandlerForContentType(typeIdentifier as CFString, .all)?.takeRetainedValue() as String?
            if let currentHandler, currentHandler != bundleID {
                previousHandlers[typeIdentifier] = currentHandler
            }

            LSSetDefaultRoleHandlerForContentType(typeIdentifier as CFString, .all, bundleID as CFString)
        }

        UserDefaults.standard.set(previousHandlers, forKey: previousHandlersKey)
    }

    private static func restorePreviousArchiveHandlers() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let previousHandlers = UserDefaults.standard.dictionary(forKey: previousHandlersKey) as? [String: String] ?? [:]

        for typeIdentifier in archiveTypeIdentifiers {
            let currentHandler = LSCopyDefaultRoleHandlerForContentType(typeIdentifier as CFString, .all)?.takeRetainedValue() as String?
            guard currentHandler == bundleID, let previousHandler = previousHandlers[typeIdentifier] else { continue }
            LSSetDefaultRoleHandlerForContentType(typeIdentifier as CFString, .all, previousHandler as CFString)
        }
    }
}
