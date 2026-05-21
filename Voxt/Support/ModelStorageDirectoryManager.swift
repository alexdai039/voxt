import Foundation
import AppKit

enum ModelStorageDirectoryManager {
    private enum MigrationError: Error {
        case unableToMergeConflictingFile(URL)
    }

    private struct ResolvedRootCache {
        let bookmarkData: Data?
        let path: String?
        let rootURL: URL
    }

    private static let modelStorageMigrationVersion = 1
    private static let lock = NSLock()
    private static var securityScopedURL: URL?
    private static var resolvedRootCache: ResolvedRootCache?
    private static let fileManager = FileManager.default

    static var defaultRootURL: URL {
        defaultRootURL(fileManager: fileManager)
    }

    static var legacyDefaultRootURL: URL {
        legacyDefaultRootURL(fileManager: fileManager)
    }

    static func resolvedRootURL() -> URL {
        resolvedRootURL(defaults: .standard)
    }

    static func resolvedRootURL(defaults: UserDefaults) -> URL {
        let bookmarkData = defaults.data(forKey: AppPreferenceKey.modelStorageRootBookmark)
        let storedPath = normalizedStoredPath(defaults.string(forKey: AppPreferenceKey.modelStorageRootPath))
        lock.lock()
        if let resolvedRootCache,
           resolvedRootCache.bookmarkData == bookmarkData,
           resolvedRootCache.path == storedPath {
            let cachedRootURL = resolvedRootCache.rootURL
            lock.unlock()
            return cachedRootURL
        }
        lock.unlock()

        let rootURL: URL
        if let bookmarkData,
           let bookmarkedURL = resolveSecurityScopedURL(from: bookmarkData, defaults: defaults) {
            rootURL = bookmarkedURL
        } else if let storedPath {
            rootURL = URL(fileURLWithPath: storedPath, isDirectory: true)
        } else {
            rootURL = defaultRootURL
        }

        updateResolvedRootCache(
            bookmarkData: bookmarkData,
            path: storedPath,
            rootURL: rootURL
        )
        return rootURL
    }

    static func saveUserSelectedRootURL(_ url: URL) throws {
        let normalized = url.standardizedFileURL
        let bookmark = try normalized.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let defaults = UserDefaults.standard
        defaults.set(normalized.path, forKey: AppPreferenceKey.modelStorageRootPath)
        defaults.set(bookmark, forKey: AppPreferenceKey.modelStorageRootBookmark)
        updateResolvedRootCache(
            bookmarkData: bookmark,
            path: normalized.path,
            rootURL: normalized
        )

        _ = resolveSecurityScopedURL(from: bookmark, defaults: defaults)
    }

    static func openRootInFinder() {
        let url = resolvedRootURL()
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @discardableResult
    static func migrateLegacyDefaultRootIfNeeded(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) -> Bool {
        let currentVersion = defaults.integer(forKey: AppPreferenceKey.modelStorageRootMigrationVersion)
        let legacyRoot = legacyDefaultRootURL(fileManager: fileManager).standardizedFileURL
        let newRoot = defaultRootURL(fileManager: fileManager).standardizedFileURL

        let bookmarkData = defaults.data(forKey: AppPreferenceKey.modelStorageRootBookmark)
        guard bookmarkData == nil else {
            if currentVersion < modelStorageMigrationVersion {
                defaults.set(modelStorageMigrationVersion, forKey: AppPreferenceKey.modelStorageRootMigrationVersion)
            }
            return false
        }

        let storedPath = normalizedStoredPath(defaults.string(forKey: AppPreferenceKey.modelStorageRootPath))
        let isLegacyAutomaticLocation = storedPath == nil || storedPath == legacyRoot.path
        guard isLegacyAutomaticLocation else {
            if currentVersion < modelStorageMigrationVersion {
                defaults.set(modelStorageMigrationVersion, forKey: AppPreferenceKey.modelStorageRootMigrationVersion)
            }
            return false
        }

        guard fileManager.fileExists(atPath: legacyRoot.path) else {
            defaults.removeObject(forKey: AppPreferenceKey.modelStorageRootPath)
            defaults.removeObject(forKey: AppPreferenceKey.modelStorageRootBookmark)
            defaults.set(modelStorageMigrationVersion, forKey: AppPreferenceKey.modelStorageRootMigrationVersion)
            updateResolvedRootCache(bookmarkData: nil, path: nil, rootURL: newRoot)
            return false
        }

        do {
            try fileManager.createDirectory(
                at: newRoot.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if fileManager.fileExists(atPath: newRoot.path) {
                try mergeDirectoryContents(from: legacyRoot, to: newRoot, fileManager: fileManager)
                try? fileManager.removeItem(at: legacyRoot)
            } else {
                try fileManager.moveItem(at: legacyRoot, to: newRoot)
            }

            defaults.removeObject(forKey: AppPreferenceKey.modelStorageRootPath)
            defaults.removeObject(forKey: AppPreferenceKey.modelStorageRootBookmark)
            defaults.set(modelStorageMigrationVersion, forKey: AppPreferenceKey.modelStorageRootMigrationVersion)
            updateResolvedRootCache(bookmarkData: nil, path: nil, rootURL: newRoot)
            return true
        } catch {
            defaults.set(legacyRoot.path, forKey: AppPreferenceKey.modelStorageRootPath)
            defaults.removeObject(forKey: AppPreferenceKey.modelStorageRootBookmark)
            updateResolvedRootCache(bookmarkData: nil, path: legacyRoot.path, rootURL: legacyRoot)
            return false
        }
    }

    static func resetForTesting() {
        lock.lock()
        resolvedRootCache = nil
        lock.unlock()
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
    }

    private static func resolveSecurityScopedURL(from bookmarkData: Data, defaults: UserDefaults) -> URL? {
        var isStale = false
        guard let resolved = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        if securityScopedURL?.path != resolved.path {
            securityScopedURL?.stopAccessingSecurityScopedResource()
            if resolved.startAccessingSecurityScopedResource() {
                securityScopedURL = resolved
            }
        }

        if isStale,
           let refreshed = try? resolved.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
           ) {
            defaults.set(refreshed, forKey: AppPreferenceKey.modelStorageRootBookmark)
            updateResolvedRootCache(
                bookmarkData: refreshed,
                path: normalizedStoredPath(defaults.string(forKey: AppPreferenceKey.modelStorageRootPath)),
                rootURL: resolved
            )
        }

        return resolved
    }

    private static func defaultRootURL(fileManager: FileManager) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return appSupport
            .appendingPathComponent("Voxt", isDirectory: true)
            .appendingPathComponent("model-storage", isDirectory: true)
    }

    private static func legacyDefaultRootURL(fileManager: FileManager) -> URL {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches", isDirectory: true)
        return caches
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("hub", isDirectory: true)
    }

    private static func normalizedStoredPath(_ path: String?) -> String? {
        guard let path,
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
    }

    private static func mergeDirectoryContents(from source: URL, to destination: URL, fileManager: FileManager) throws {
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        try validateMergeCompatibility(from: source, to: destination, fileManager: fileManager)

        var copiedItems: [URL] = []
        do {
            try copyMissingDirectoryContents(
                from: source,
                to: destination,
                fileManager: fileManager,
                copiedItems: &copiedItems
            )
        } catch {
            rollbackCopiedItems(copiedItems, fileManager: fileManager)
            throw error
        }
    }

    private static func validateMergeCompatibility(from source: URL, to destination: URL, fileManager: FileManager) throws {
        let children = try fileManager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )

        for child in children {
            let target = destination.appendingPathComponent(child.lastPathComponent, isDirectory: false)
            guard fileManager.fileExists(atPath: target.path) else {
                continue
            }

            let childValues = try child.resourceValues(forKeys: [.isDirectoryKey])
            let targetValues = try target.resourceValues(forKeys: [.isDirectoryKey])
            if childValues.isDirectory == true && targetValues.isDirectory == true {
                try validateMergeCompatibility(from: child, to: target, fileManager: fileManager)
                continue
            }

            throw MigrationError.unableToMergeConflictingFile(target)
        }
    }

    private static func copyMissingDirectoryContents(
        from source: URL,
        to destination: URL,
        fileManager: FileManager,
        copiedItems: inout [URL]
    ) throws {
        let children = try fileManager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )

        for child in children {
            let target = destination.appendingPathComponent(child.lastPathComponent, isDirectory: false)
            if !fileManager.fileExists(atPath: target.path) {
                try copyItemRecursively(from: child, to: target, fileManager: fileManager)
                copiedItems.append(target)
                continue
            }

            let childValues = try child.resourceValues(forKeys: [.isDirectoryKey])
            let targetValues = try target.resourceValues(forKeys: [.isDirectoryKey])
            if childValues.isDirectory == true && targetValues.isDirectory == true {
                try copyMissingDirectoryContents(
                    from: child,
                    to: target,
                    fileManager: fileManager,
                    copiedItems: &copiedItems
                )
                continue
            }

            throw MigrationError.unableToMergeConflictingFile(target)
        }
    }

    private static func copyItemRecursively(from source: URL, to destination: URL, fileManager: FileManager) throws {
        do {
            try fileManager.copyItem(at: source, to: destination)
        } catch {
            let values = try source.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else {
                throw error
            }

            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            let children = try fileManager.contentsOfDirectory(
                at: source,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            )
            for child in children {
                let nestedDestination = destination.appendingPathComponent(child.lastPathComponent, isDirectory: false)
                try copyItemRecursively(from: child, to: nestedDestination, fileManager: fileManager)
            }
        }
    }

    private static func rollbackCopiedItems(_ copiedItems: [URL], fileManager: FileManager) {
        for item in copiedItems.reversed() {
            try? fileManager.removeItem(at: item)
        }
    }

    private static func updateResolvedRootCache(bookmarkData: Data?, path: String?, rootURL: URL) {
        lock.lock()
        resolvedRootCache = ResolvedRootCache(
            bookmarkData: bookmarkData,
            path: path,
            rootURL: rootURL
        )
        lock.unlock()
    }
}
