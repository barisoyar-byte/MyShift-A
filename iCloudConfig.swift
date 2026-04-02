import Foundation

/// Global iCloud configuration used by the app.
///
/// IMPORTANT: Replace the placeholder with your actual iCloud container identifier
/// that you enabled under Signing & Capabilities > iCloud > Containers.
/// Examples:
/// - "iCloud.com.company.myshiftA"
/// - nil  // to use the default container (not recommended for CI)
public enum ICloudConfig {
    /// The iCloud container identifier to use for ubiquity container lookups.
    public static let containerID: String? = "iCloud.com.company.myshiftA"
}
