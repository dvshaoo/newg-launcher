import Foundation
import CryptoKit

func require(_ value: @autoclosure () -> Bool, _ message: String) {
    precondition(value(), message)
}
func rejects(_ body: () throws -> Void) {
    do { try body(); fatalError("Invalid input was accepted") } catch {}
}

let sample = Data("NEWG release validation fixture".utf8)
let hash = SHA256.hash(data: sample).map { String(format: "%02x", $0) }.joined()
let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
let file = root.appendingPathComponent("sample.ipa")
try sample.write(to: file)
try NEWGRelease.verify(file, size: Int64(sample.count), sha256: hash)
rejects { try NEWGRelease.verify(file, size: Int64(sample.count + 1), sha256: hash) }
rejects { try NEWGRelease.verify(file, size: Int64(sample.count), sha256: String(repeating: "0", count: 64)) }

let validURL = URL(string: "https://\(NEWGRelease.downloadHost)/ros-new-gen-builds/builds/ios-owner-pilot/ROS.ipa?X-Amz-Signature=test")!
let release = NEWGRelease(version: "v59", bundleIdentifier: "com.netease.chiji.rcs", downloadURL: validURL, size: Int64(sample.count), sha256: hash)
let encoded = try JSONEncoder().encode(release)
let decoded = try NEWGRelease.decode(encoded)
require(decoded.version == "v59", "Release JSON round trip")
for text in ["http://\(NEWGRelease.downloadHost)/ros-new-gen-builds/builds/ios-pilot/app.ipa",
             "https://example.com/app.ipa", "https://user:password@\(NEWGRelease.downloadHost)/ros-new-gen-builds/builds/ios-pilot/app.ipa",
             "https://\(NEWGRelease.downloadHost)/other/app.ipa"] {
    rejects { try NEWGRelease.validateURL(URL(string: text)!) }
}
rejects { _ = try NEWGRelease.decode(Data(repeating: 0, count: 65_537)) }
rejects { _ = try NEWGRelease(version: "v59", bundleIdentifier: "other.app", downloadURL: validURL, size: 10, sha256: hash).validated() }
rejects { _ = try NEWGRelease(version: "v59", bundleIdentifier: release.bundleIdentifier, downloadURL: validURL, size: 0, sha256: hash).validated() }
rejects { _ = try NEWGRelease(version: "v59", bundleIdentifier: release.bundleIdentifier, downloadURL: validURL, size: 10, sha256: "bad").validated() }
print("NEWG release tests PASS: valid manifest/file, truncation, corruption, HTTPS/host/path/userinfo, size and target identity.")
