import XCTest
@testable import Voxt

final class OnboardingPreferenceManagerTests: XCTestCase {
    func testResolvedCompletionStateDefaultsToFalseForFreshInstall() throws {
        let (defaults, suiteName) = makeIsolatedDefaults()
        let directory = try TemporaryDirectory()
        let fileManager = TestAppSupportFileManager(applicationSupportDirectory: directory.url)

        let completed = OnboardingPreferenceManager.resolvedCompletionState(
            defaults: defaults,
            fileManager: fileManager,
            bundleIdentifier: suiteName
        )

        XCTAssertFalse(completed)
        XCTAssertEqual(defaults.object(forKey: AppPreferenceKey.onboardingCompleted) as? Bool, false)
    }

    func testResolvedCompletionStateTreatsExistingPersistentDomainAsCompleted() throws {
        let (defaults, suiteName) = makeIsolatedDefaults()
        let directory = try TemporaryDirectory()
        let fileManager = TestAppSupportFileManager(applicationSupportDirectory: directory.url)
        defaults.setPersistentDomain(
            [AppPreferenceKey.translationTargetLanguage: TranslationTargetLanguage.english.rawValue],
            forName: suiteName
        )

        let completed = OnboardingPreferenceManager.resolvedCompletionState(
            defaults: defaults,
            fileManager: fileManager,
            bundleIdentifier: suiteName
        )

        XCTAssertTrue(completed)
        XCTAssertEqual(defaults.object(forKey: AppPreferenceKey.onboardingCompleted) as? Bool, true)
    }

    func testResolvedCompletionStateTreatsExistingAppSupportDirectoryAsCompleted() throws {
        let (defaults, suiteName) = makeIsolatedDefaults()
        let directory = try TemporaryDirectory()
        let appSupportDirectory = directory.url.appendingPathComponent("Voxt", isDirectory: true)
        try FileManager.default.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
        let fileManager = TestAppSupportFileManager(applicationSupportDirectory: directory.url)

        let completed = OnboardingPreferenceManager.resolvedCompletionState(
            defaults: defaults,
            fileManager: fileManager,
            bundleIdentifier: suiteName
        )

        XCTAssertTrue(completed)
        XCTAssertEqual(defaults.object(forKey: AppPreferenceKey.onboardingCompleted) as? Bool, true)
    }

    func testMarkCompletedClearsSavedStep() {
        let defaults = TestDoubles.makeUserDefaults()
        OnboardingPreferenceManager.saveLastStep(.finish, defaults: defaults)

        OnboardingPreferenceManager.markCompleted(defaults: defaults)

        XCTAssertEqual(defaults.object(forKey: AppPreferenceKey.onboardingCompleted) as? Bool, true)
        XCTAssertNil(defaults.string(forKey: AppPreferenceKey.onboardingLastStepID))
    }

    private func makeIsolatedDefaults() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "VoxtTests.Onboarding.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}

final class ModelStorageDirectoryManagerMigrationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ModelStorageDirectoryManager.resetForTesting()
    }

    override func tearDown() {
        ModelStorageDirectoryManager.resetForTesting()
        super.tearDown()
    }

    func testMigrationMovesLegacyDefaultRootWhenStoredPathMatchesLegacyLocation() throws {
        let defaults = TestDoubles.makeUserDefaults(testName: "ModelStorageDirectoryManagerTests.legacyStoredPath")
        let directory = try TemporaryDirectory()
        let fileManager = TestModelStorageFileManager(baseDirectory: directory.url)
        let legacyRoot = fileManager.cachesRoot
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("hub", isDirectory: true)
        let legacyModelFile = legacyRoot
            .appendingPathComponent("mlx-audio", isDirectory: true)
            .appendingPathComponent("model", isDirectory: true)
            .appendingPathComponent("config.json")
        let legacyHubFile = legacyRoot
            .appendingPathComponent("models--mlx-community--demo", isDirectory: true)
            .appendingPathComponent("refs", isDirectory: true)
            .appendingPathComponent("main")
        let legacyMetadataFile = legacyRoot
            .appendingPathComponent(".metadata", isDirectory: true)
            .appendingPathComponent("models--mlx-community--demo", isDirectory: true)
            .appendingPathComponent("config.json")
        try createFile(at: legacyModelFile, contents: Data("{}".utf8))
        try createFile(at: legacyHubFile, contents: Data("commit".utf8))
        try createFile(at: legacyMetadataFile, contents: Data("metadata".utf8))
        defaults.set(legacyRoot.path, forKey: AppPreferenceKey.modelStorageRootPath)

        let migrated = ModelStorageDirectoryManager.migrateLegacyDefaultRootIfNeeded(
            defaults: defaults,
            fileManager: fileManager
        )

        let newRoot = fileManager.applicationSupportRoot
            .appendingPathComponent("Voxt", isDirectory: true)
            .appendingPathComponent("model-storage", isDirectory: true)
        XCTAssertTrue(migrated)
        XCTAssertTrue(fileManager.fileExists(atPath: newRoot.appendingPathComponent("mlx-audio/model/config.json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: newRoot.appendingPathComponent("models--mlx-community--demo/refs/main").path))
        XCTAssertTrue(fileManager.fileExists(atPath: newRoot.appendingPathComponent(".metadata/models--mlx-community--demo/config.json").path))
        XCTAssertFalse(fileManager.fileExists(atPath: legacyRoot.path))
        XCTAssertNil(defaults.string(forKey: AppPreferenceKey.modelStorageRootPath))
        XCTAssertEqual(defaults.integer(forKey: AppPreferenceKey.modelStorageRootMigrationVersion), 1)
    }

    func testMigrationMovesLegacyDefaultRootWhenNoStoredPathExists() throws {
        let defaults = TestDoubles.makeUserDefaults(testName: "ModelStorageDirectoryManagerTests.implicitLegacyPath")
        let directory = try TemporaryDirectory()
        let fileManager = TestModelStorageFileManager(baseDirectory: directory.url)
        let legacyRoot = fileManager.cachesRoot
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("hub", isDirectory: true)
        let legacyModelFile = legacyRoot.appendingPathComponent("whisperkit/demo/model.bin")
        try createFile(at: legacyModelFile, contents: Data("demo".utf8))

        let migrated = ModelStorageDirectoryManager.migrateLegacyDefaultRootIfNeeded(
            defaults: defaults,
            fileManager: fileManager
        )

        let newRoot = fileManager.applicationSupportRoot
            .appendingPathComponent("Voxt", isDirectory: true)
            .appendingPathComponent("model-storage", isDirectory: true)
        XCTAssertTrue(migrated)
        XCTAssertTrue(fileManager.fileExists(atPath: newRoot.appendingPathComponent("whisperkit/demo/model.bin").path))
        XCTAssertNil(defaults.string(forKey: AppPreferenceKey.modelStorageRootPath))
    }

    func testMigrationSkipsBookmarkedCustomLocation() throws {
        let defaults = TestDoubles.makeUserDefaults(testName: "ModelStorageDirectoryManagerTests.bookmarkedPath")
        let directory = try TemporaryDirectory()
        let fileManager = TestModelStorageFileManager(baseDirectory: directory.url)
        let legacyRoot = fileManager.cachesRoot
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("hub", isDirectory: true)
        try fileManager.createDirectory(at: legacyRoot, withIntermediateDirectories: true)
        defaults.set(legacyRoot.path, forKey: AppPreferenceKey.modelStorageRootPath)
        defaults.set(Data([1, 2, 3]), forKey: AppPreferenceKey.modelStorageRootBookmark)

        let migrated = ModelStorageDirectoryManager.migrateLegacyDefaultRootIfNeeded(
            defaults: defaults,
            fileManager: fileManager
        )

        let newRoot = fileManager.applicationSupportRoot
            .appendingPathComponent("Voxt", isDirectory: true)
            .appendingPathComponent("model-storage", isDirectory: true)
        XCTAssertFalse(migrated)
        XCTAssertTrue(fileManager.fileExists(atPath: legacyRoot.path))
        XCTAssertFalse(fileManager.fileExists(atPath: newRoot.path))
        XCTAssertEqual(defaults.integer(forKey: AppPreferenceKey.modelStorageRootMigrationVersion), 1)
    }

    func testMigrationFailurePinsLegacyPathWithoutDeletingData() throws {
        let defaults = TestDoubles.makeUserDefaults(testName: "ModelStorageDirectoryManagerTests.failedMove")
        let directory = try TemporaryDirectory()
        let fileManager = TestModelStorageFileManager(baseDirectory: directory.url, shouldFailMove: true)
        let legacyRoot = fileManager.cachesRoot
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("hub", isDirectory: true)
        let legacyModelFile = legacyRoot.appendingPathComponent("mlx-llm/model/config.json")
        try createFile(at: legacyModelFile, contents: Data("{}".utf8))

        let migrated = ModelStorageDirectoryManager.migrateLegacyDefaultRootIfNeeded(
            defaults: defaults,
            fileManager: fileManager
        )

        let newRoot = fileManager.applicationSupportRoot
            .appendingPathComponent("Voxt", isDirectory: true)
            .appendingPathComponent("model-storage", isDirectory: true)
        XCTAssertFalse(migrated)
        XCTAssertTrue(fileManager.fileExists(atPath: legacyModelFile.path))
        XCTAssertFalse(fileManager.fileExists(atPath: newRoot.path))
        XCTAssertEqual(defaults.string(forKey: AppPreferenceKey.modelStorageRootPath), legacyRoot.path)
        XCTAssertEqual(defaults.integer(forKey: AppPreferenceKey.modelStorageRootMigrationVersion), 0)
    }

    func testMigrationConflictDoesNotLeavePartiallyCopiedNewRootContents() throws {
        let defaults = TestDoubles.makeUserDefaults(testName: "ModelStorageDirectoryManagerTests.mergeConflict")
        let directory = try TemporaryDirectory()
        let fileManager = TestModelStorageFileManager(baseDirectory: directory.url)
        let legacyRoot = fileManager.cachesRoot
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("hub", isDirectory: true)
        let legacyCopiedFile = legacyRoot.appendingPathComponent("a-missing/model/config.json")
        let legacyConflictingFile = legacyRoot.appendingPathComponent("z-conflict/config.json")
        try createFile(at: legacyCopiedFile, contents: Data("{}".utf8))
        try createFile(at: legacyConflictingFile, contents: Data("legacy".utf8))

        let newRoot = fileManager.applicationSupportRoot
            .appendingPathComponent("Voxt", isDirectory: true)
            .appendingPathComponent("model-storage", isDirectory: true)
        let newRootConflictingFile = newRoot.appendingPathComponent("z-conflict/config.json")
        try createFile(at: newRootConflictingFile, contents: Data("existing".utf8))

        let migrated = ModelStorageDirectoryManager.migrateLegacyDefaultRootIfNeeded(
            defaults: defaults,
            fileManager: fileManager
        )

        XCTAssertFalse(migrated)
        XCTAssertTrue(fileManager.fileExists(atPath: legacyCopiedFile.path))
        XCTAssertTrue(fileManager.fileExists(atPath: legacyConflictingFile.path))
        XCTAssertFalse(fileManager.fileExists(atPath: newRoot.appendingPathComponent("a-missing").path))
        XCTAssertTrue(fileManager.fileExists(atPath: newRootConflictingFile.path))
        XCTAssertEqual(defaults.string(forKey: AppPreferenceKey.modelStorageRootPath), legacyRoot.path)
        XCTAssertEqual(defaults.integer(forKey: AppPreferenceKey.modelStorageRootMigrationVersion), 0)
    }

    private func createFile(at url: URL, contents: Data) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url)
    }
}

private final class TestAppSupportFileManager: FileManager {
    private let applicationSupportDirectory: URL

    init(applicationSupportDirectory: URL) {
        self.applicationSupportDirectory = applicationSupportDirectory
        super.init()
    }

    override func url(
        for directory: SearchPathDirectory,
        in domain: SearchPathDomainMask,
        appropriateFor url: URL?,
        create shouldCreate: Bool
    ) throws -> URL {
        if directory == .applicationSupportDirectory, domain == .userDomainMask {
            return applicationSupportDirectory
        }
        return try super.url(
            for: directory,
            in: domain,
            appropriateFor: url,
            create: shouldCreate
        )
    }
}

private final class TestModelStorageFileManager: FileManager {
    let cachesRoot: URL
    let applicationSupportRoot: URL
    private let shouldFailMove: Bool

    init(baseDirectory: URL, shouldFailMove: Bool = false) {
        self.cachesRoot = baseDirectory.appendingPathComponent("Caches", isDirectory: true)
        self.applicationSupportRoot = baseDirectory.appendingPathComponent("Application Support", isDirectory: true)
        self.shouldFailMove = shouldFailMove
        super.init()
    }

    override func urls(for directory: SearchPathDirectory, in domainMask: SearchPathDomainMask) -> [URL] {
        guard domainMask == .userDomainMask else {
            return super.urls(for: directory, in: domainMask)
        }

        switch directory {
        case .cachesDirectory:
            return [cachesRoot]
        case .applicationSupportDirectory:
            return [applicationSupportRoot]
        default:
            return super.urls(for: directory, in: domainMask)
        }
    }

    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        if shouldFailMove {
            throw NSError(domain: "ModelStorageDirectoryManagerTests", code: 1)
        }
        try super.moveItem(at: srcURL, to: dstURL)
    }

    override func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: DirectoryEnumerationOptions = []
    ) throws -> [URL] {
        try super.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: mask)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
