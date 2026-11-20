// NEWG Launcher pilot. Copyright 2026 NEWG contributors. AGPL-3.0-only.
import Foundation

final class NEWGDownload: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let release: NEWGRelease
    private let progress: @Sendable (Double) -> Void
    private let completion: @Sendable (Result<URL, Error>) -> Void
    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    // Delegate callbacks run on one serial queue, including terminal delivery.
    private var finished = false
    private let stateLock = NSLock()
    private var cancelled = false

    init(release: NEWGRelease,
         progress: @escaping @Sendable (Double) -> Void,
         completion: @escaping @Sendable (Result<URL, Error>) -> Void) {
        self.release = release
        self.progress = progress
        self.completion = completion
    }

    func start() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 7200
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
        self.session = session
        let task = session.downloadTask(with: release.downloadURL)
        self.task = task
        task.resume()
    }

    func cancel() {
        stateLock.lock()
        cancelled = true
        stateLock.unlock()
        task?.cancel()
    }

    private func isCancelled() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return cancelled
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        guard let url = request.url, (try? NEWGRelease.validateURL(url)) != nil else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > release.size { downloadTask.cancel(); return }
        progress(min(1, Double(totalBytesWritten) / Double(release.size)))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        do {
            guard let response = downloadTask.response as? HTTPURLResponse, response.statusCode == 200 else {
                throw NEWGReleaseError.http((downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0)
            }
            try NEWGRelease.verify(location, size: release.size, sha256: release.sha256, shouldCancel: { self.isCancelled() })
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("NEWG-Verified", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appendingPathComponent(UUID().uuidString + ".ipa")
            try FileManager.default.moveItem(at: location, to: destination)
            finish(.success(destination))
        } catch { finish(.failure(error)) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { finish(.failure(error)) }
    }

    private func finish(_ result: Result<URL, Error>) {
        guard !finished else { return }
        finished = true
        completion(result)
        session?.finishTasksAndInvalidate()
    }
}
