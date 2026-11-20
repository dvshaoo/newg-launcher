// NEWG Launcher pilot. Copyright 2026 NEWG contributors. AGPL-3.0-only.
import Foundation
import CryptoKit

struct NEWGRelease: Codable, Sendable {
    let version: String
    let bundleIdentifier: String
    let downloadURL: URL
    let size: Int64
    let sha256: String

    static let downloadHost = "811acbf171b933b5aee32cca80daa34c.r2.cloudflarestorage.com"

    static func validateURL(_ url: URL) throws {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == downloadHost,
              url.user == nil, url.password == nil,
              url.port == nil || url.port == 443,
              url.path.hasPrefix("/ros-new-gen-builds/builds/ios-") else {
            throw NEWGReleaseError.invalidURL
        }
    }

    func validated() throws -> Self {
        try Self.validateURL(downloadURL)
        guard !version.isEmpty, version.count <= 40,
              bundleIdentifier == "com.netease.chiji.rcs",
              size > 0, size <= 8 * 1024 * 1024 * 1024,
              sha256.count == 64, sha256.allSatisfy({ "0123456789abcdefABCDEF".contains($0) }) else {
            throw NEWGReleaseError.invalidManifest
        }
        return self
    }

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= 65_536 else { throw NEWGReleaseError.invalidManifest }
        return try JSONDecoder().decode(Self.self, from: data).validated()
    }

    static func verify(_ file: URL, size: Int64, sha256: String, shouldCancel: () -> Bool = { false }) throws {
        let values = try file.resourceValues(forKeys: [.fileSizeKey])
        guard Int64(values.fileSize ?? -1) == size else { throw NEWGReleaseError.wrongSize }
        let input = try FileHandle(forReadingFrom: file)
        defer { try? input.close() }
        var digest = SHA256()
        while let data = try input.read(upToCount: 4 * 1024 * 1024), !data.isEmpty {
            if shouldCancel() { throw URLError(.cancelled) }
            digest.update(data: data)
        }
        if shouldCancel() { throw URLError(.cancelled) }
        let actual = digest.finalize().map { String(format: "%02x", $0) }.joined()
        guard actual == sha256.lowercased() else { throw NEWGReleaseError.wrongHash }
    }
}

enum NEWGReleaseError: LocalizedError {
    case invalidURL, invalidManifest, wrongSize, wrongHash, http(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Use a NEWG HTTPS release link from the NEWG portal."
        case .invalidManifest: return "This is not a valid NEWG ROS release file."
        case .wrongSize: return "The download is incomplete. Please try again."
        case .wrongHash: return "The IPA did not pass verification. It was not sent for installation."
        case .http(let status): return "The release link returned HTTP \(status). Get a fresh link from NEWG."
        }
    }
}
