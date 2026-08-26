//
// IPADownloadManager.swift
// KINDA
//

import Foundation
import SwiftUI

final class IPADownloadManager: NSObject, ObservableObject {
    @Published var downloadItems: [DownloadItem] = []

    var activeItems: [DownloadItem] { downloadItems.filter { !$0.isFinished } }
    var finishedItems: [DownloadItem] { downloadItems.filter { $0.isFinished } }

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 3600
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    }()

    private var tasks: [Int: UUID] = [:]

    override init() {
        super.init()
        restoreFiles()
    }

    /// Re-scans the Downloads directory and refreshes completed IPA entries.
    /// DownloaderView calls this whenever another download finishes.
    @MainActor
    func loadDownloadedIPAs() {
        let directory = URL.documentsDirectory
            .appendingPathComponent("Downloads", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let existingFinishedPaths = Set(
            downloadItems
                .filter { $0.isFinished }
                .map { $0.localPath.standardizedFileURL.path }
        )

        for file in files where isIPAFile(file) {
            let normalized = file.standardizedFileURL.path
            guard !existingFinishedPaths.contains(normalized) else {
                continue
            }

            let size = Int64(
                (try? file.resourceValues(
                    forKeys: [.fileSizeKey]
                ).fileSize) ?? 0
            )

            downloadItems.append(
                DownloadItem(
                    title: file.deletingPathExtension().lastPathComponent,
                    url: file,
                    localPath: file,
                    isFinished: true,
                    progress: 1,
                    totalBytes: size,
                    bytesDownloaded: size
                )
            )
        }

        downloadItems.sort {
            if $0.isFinished != $1.isFinished {
                return !$0.isFinished
            }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    func isIPAFile(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "ipa"
    }

    @discardableResult
    func startDownload(url: URL, filename: String? = nil) -> UUID {
        let directory = URL.documentsDirectory.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let requested = (filename?.isEmpty == false ? filename! : url.lastPathComponent)
        let clean = sanitize(requested.isEmpty ? "app.ipa" : requested)
        let finalName = clean.lowercased().hasSuffix(".ipa") ? clean : clean + ".ipa"
        let destination = uniqueURL(directory, finalName)

        let item = DownloadItem(
            title: destination.deletingPathExtension().lastPathComponent,
            url: url,
            localPath: destination,
            isFinished: false,
            progress: 0,
            totalBytes: 0,
            bytesDownloaded: 0
        )

        downloadItems.insert(item, at: 0)

        let task = session.downloadTask(with: url)
        tasks[task.taskIdentifier] = item.id
        task.resume()

        return item.id
    }

    func cancelDownload(_ item: DownloadItem) {
        session.getAllTasks { [weak self] all in
            guard let self else { return }
            all.first(where: { self.tasks[$0.taskIdentifier] == item.id })?.cancel()
        }
    }

    func checkFileTypeAndDownload(
        url: URL,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            completion(.failure(error("الرابط يجب أن يكون HTTP أو HTTPS.")))
            return
        }

        let id = startDownload(url: url, filename: url.lastPathComponent.isEmpty ? "app.ipa" : url.lastPathComponent)
        completion(.success(id.uuidString))
    }

    func handleITMSServicesURL(
        _ url: URL,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name.lowercased() == "url" })?.value,
              let manifestURL = URL(string: value) else {
            completion(.failure(error("رابط itms-services غير صالح.")))
            return
        }

        URLSession.shared.dataTask(with: manifestURL) { [weak self] data, response, requestError in
            guard let self else { return }
            if let requestError {
                completion(.failure(requestError))
                return
            }

            guard let response = response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode),
                  let data else {
                completion(.failure(error("تعذر تحميل manifest.")))
                return
            }

            do {
                let ipa = try self.parseManifest(data)
                let id = self.startDownload(url: ipa, filename: ipa.lastPathComponent.isEmpty ? "app.ipa" : ipa.lastPathComponent)
                completion(.success(id.uuidString))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func parseManifest(_ data: Data) throws -> URL {
        let object = try PropertyListSerialization.propertyList(from: data, format: nil)

        guard let plist = object as? [String: Any],
              let items = plist["items"] as? [[String: Any]] else {
            throw error("ملف manifest غير صالح.")
        }

        for item in items {
            guard let assets = item["assets"] as? [[String: Any]] else { continue }

            for asset in assets {
                if asset["kind"] as? String == "software-package",
                   let string = asset["url"] as? String,
                   let url = URL(string: string) {
                    return url
                }
            }
        }

        throw error("لم يتم العثور على رابط IPA داخل manifest.")
    }

    private func restoreFiles() {
        let directory = URL.documentsDirectory.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for file in files where isIPAFile(file) {
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            downloadItems.append(
                DownloadItem(
                    title: file.deletingPathExtension().lastPathComponent,
                    url: file,
                    localPath: file,
                    isFinished: true,
                    progress: 1,
                    totalBytes: size,
                    bytesDownloaded: size
                )
            )
        }
    }

    private func uniqueURL(_ directory: URL, _ filename: String) -> URL {
        let first = directory.appendingPathComponent(filename)
        if !FileManager.default.fileExists(atPath: first.path) { return first }

        let ext = first.pathExtension
        let base = first.deletingPathExtension().lastPathComponent

        for n in 2...9999 {
            let candidate = directory.appendingPathComponent("\(base)-\(n).\(ext)")
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }

        return directory.appendingPathComponent("\(UUID().uuidString).ipa")
    }

    private func sanitize(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let result = value.components(separatedBy: invalid).joined(separator: "_")
        return result.isEmpty ? "app.ipa" : result
    }

    private func error(_ message: String) -> NSError {
        NSError(domain: "KINDA.IPA", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

extension IPADownloadManager: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let id = tasks[downloadTask.taskIdentifier],
              let index = downloadItems.firstIndex(where: { $0.id == id }) else { return }

        let destination = downloadItems[index].localPath

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }

            try FileManager.default.moveItem(at: location, to: destination)

            let size = (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            downloadItems[index].isFinished = true
            downloadItems[index].progress = 1
            downloadItems[index].totalBytes = size
            downloadItems[index].bytesDownloaded = size
        } catch {
            downloadItems.remove(at: index)
        }

        tasks.removeValue(forKey: downloadTask.taskIdentifier)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let id = tasks[downloadTask.taskIdentifier],
              let index = downloadItems.firstIndex(where: { $0.id == id }) else { return }

        downloadItems[index].bytesDownloaded = totalBytesWritten
        downloadItems[index].totalBytes = totalBytesExpectedToWrite
        downloadItems[index].progress = totalBytesExpectedToWrite > 0
            ? min(max(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 0), 1)
            : 0
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error,
           let id = tasks[task.taskIdentifier],
           let index = downloadItems.firstIndex(where: { $0.id == id }) {
            downloadItems.remove(at: index)
            print("IPA download error:", error)
        }

        tasks.removeValue(forKey: task.taskIdentifier)
    }
}
