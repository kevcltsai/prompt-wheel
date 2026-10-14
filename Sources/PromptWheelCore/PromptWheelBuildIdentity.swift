import Foundation

/// Read-only build identity shown in the menu bar menu for local runtime identification.
public struct PromptWheelBuildIdentity: Equatable {
    public let version: String
    public let buildNumber: String
    public let buildID: String
    public let bundlePath: String

    public init(infoDictionary: [String: Any], bundleURL: URL) {
        version = infoDictionary["CFBundleShortVersionString"] as? String ?? "unknown"
        buildNumber = infoDictionary["CFBundleVersion"] as? String ?? "unknown"
        buildID = infoDictionary["PromptWheelBuildID"] as? String ?? "unknown"
        bundlePath = bundleURL.standardizedFileURL.path
    }

    public static func current(bundle: Bundle = .main) -> Self {
        Self(infoDictionary: bundle.infoDictionary ?? [:], bundleURL: bundle.bundleURL)
    }

    public var versionLine: String { "Version \(version) (build \(buildNumber))" }
    public var buildIDLine: String { "Build ID: \(buildID)" }
    public var bundlePathLine: String { "Bundle: \(bundlePath)" }
}
