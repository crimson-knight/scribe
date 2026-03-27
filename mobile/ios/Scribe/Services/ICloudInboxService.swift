import Foundation
import Combine

// MARK: - iCloud Inbox Service

/// Discovers and monitors thread .md files in iCloud Drive `Scribe/inbox/` directory.
/// Uses NSMetadataQuery to watch for iCloud file changes (new/modified/deleted).
/// Publishes parsed ThreadMetadata array for SwiftUI consumption.
@MainActor
final class ICloudInboxService: ObservableObject {

    @Published var threads: [ThreadMetadata] = []
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published var iCloudAvailable = false

    private var metadataQuery: NSMetadataQuery?
    private var notificationObservers: [NSObjectProtocol] = []

    // MARK: - Public

    /// The inbox directory URL. Checks for a custom folder first, then falls back to iCloud container.
    var inboxDirectoryURL: URL? {
        // Check if a custom folder is configured
        let defaults = UserDefaults.standard
        let location = defaults.string(forKey: "saveLocation") ?? "localOnly"

        if location == "customFolder",
           let bookmarkData = defaults.data(forKey: "customFolderBookmark") {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData,
                                   options: [],
                                   relativeTo: nil,
                                   bookmarkDataIsStale: &isStale) {
                return url.appendingPathComponent("inbox")
            }
        }

        // Fallback: standard iCloud container
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            return nil
        }
        return container
            .appendingPathComponent("Documents")
            .appendingPathComponent("Scribe")
            .appendingPathComponent("inbox")
    }

    /// Start monitoring the iCloud inbox directory.
    func startMonitoring() {
        guard let inboxURL = inboxDirectoryURL else {
            iCloudAvailable = false
            isLoading = false
            errorMessage = "iCloud Drive is not available. Sign in to iCloud in Settings."
            return
        }

        iCloudAvailable = true

        // Ensure the inbox directory exists
        ensureDirectoryExists(at: inboxURL)

        // Initial scan
        loadThreadsFromDisk(at: inboxURL)

        // Set up NSMetadataQuery for live updates
        setupMetadataQuery(inboxURL: inboxURL)
    }

    /// Stop monitoring and clean up.
    func stopMonitoring() {
        metadataQuery?.stop()
        metadataQuery = nil

        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
    }

    /// Create a new thread file in the iCloud inbox.
    /// Returns the file URL on success, nil on failure.
    func createThread(transcription: String) -> URL? {
        guard let inboxURL = inboxDirectoryURL else {
            errorMessage = "iCloud Drive is not available."
            return nil
        }

        ensureDirectoryExists(at: inboxURL)

        let threadID = UUID().uuidString.lowercased()
        let now = Date()
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime]
        let timestamp = iso8601.string(from: now)

        // Title: first 50 characters of transcription
        let titleRaw = transcription.prefix(50)
        let title = titleRaw.count < transcription.count
            ? String(titleRaw).trimmingCharacters(in: .whitespaces) + "..."
            : String(titleRaw).trimmingCharacters(in: .whitespaces)

        // Time for message header
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = timeFormatter.string(from: now)

        let content = """
        ---
        id: \(threadID)
        title: "\(title)"
        agent: default
        status: active
        created: \(timestamp)
        updated: \(timestamp)
        ---

        ## User \u{2014} \(timeString)
        \(transcription)
        """

        let fileURL = inboxURL.appendingPathComponent("\(threadID).md")

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            errorMessage = "Failed to create thread: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Private

    private func ensureDirectoryExists(at url: URL) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private func loadThreadsFromDisk(at inboxURL: URL) {
        let fm = FileManager.default

        guard let files = try? fm.contentsOfDirectory(
            at: inboxURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else {
            isLoading = false
            return
        }

        let mdFiles = files.filter { $0.pathExtension.lowercased() == "md" }
        let parsed = mdFiles.compactMap { ThreadMetadata.parse(from: $0) }
        threads = parsed.sorted { $0.updated > $1.updated }
        isLoading = false
    }

    private func setupMetadataQuery(inboxURL: URL) {
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE '*.md'", NSMetadataItemFSNameKey)

        // Observe initial results
        let initialObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { [weak self] notification in
            self?.handleQueryResults(notification)
        }
        notificationObservers.append(initialObserver)

        // Observe updates
        let updateObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] notification in
            self?.handleQueryResults(notification)
        }
        notificationObservers.append(updateObserver)

        self.metadataQuery = query
        query.start()
    }

    private func handleQueryResults(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else { return }

        query.disableUpdates()
        defer { query.enableUpdates() }

        var updatedThreads: [ThreadMetadata] = []

        for i in 0..<query.resultCount {
            guard let item = query.result(at: i) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else {
                continue
            }

            let fileURL = URL(fileURLWithPath: path)

            // Only process files in our inbox directory
            guard fileURL.pathComponents.contains("inbox") else { continue }

            if let thread = ThreadMetadata.parse(from: fileURL) {
                updatedThreads.append(thread)
            }
        }

        if !updatedThreads.isEmpty {
            threads = updatedThreads.sorted { $0.updated > $1.updated }
        }

        isLoading = false
    }

    deinit {
        // Note: stopMonitoring should be called explicitly before deinit
        // since deinit may not run on MainActor
        metadataQuery?.stop()
    }
}
