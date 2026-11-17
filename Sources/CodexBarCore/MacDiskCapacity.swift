import Foundation

/// Startup-volume capacity measured the way Finder and "About This Mac" report it.
///
/// `FileManager.attributesOfFileSystem(.systemFreeSize)` excludes purgeable space (caches, iCloud
/// local copies), so it can read tens of GB lower than Finder. "Available for important usage" includes
/// space macOS frees on demand, matching what users compare the card against.
public struct MacDiskCapacity: Equatable, Sendable {
    public let availableBytes: Double
    public let totalBytes: Double

    public init(availableBytes: Double, totalBytes: Double) {
        self.availableBytes = availableBytes
        self.totalBytes = totalBytes
    }

    /// Decimal GB, as Finder displays storage.
    public var availableGB: Double { self.availableBytes / 1_000_000_000 }
    public var totalGB: Double { self.totalBytes / 1_000_000_000 }

    public var usedPercent: Double? {
        guard self.totalBytes > 0 else { return nil }
        return min(100, max(0, (1 - self.availableBytes / self.totalBytes) * 100))
    }

    /// Prefers the Finder-equivalent value and falls back to raw free space when it is unavailable.
    public static func resolve(important: Int64?, raw: Int?, total: Int?) -> MacDiskCapacity? {
        guard let total, total > 0 else { return nil }
        let available: Double
        if let important, important > 0 {
            available = Double(important)
        } else if let raw {
            available = Double(raw)
        } else {
            return nil
        }
        return MacDiskCapacity(availableBytes: min(available, Double(total)), totalBytes: Double(total))
    }

    /// Any path on the startup volume works, including a sandboxed widget's container home.
    public static func current(path: String = NSHomeDirectory()) -> MacDiskCapacity? {
        let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
            .volumeTotalCapacityKey,
        ])
        return self.resolve(
            important: values?.volumeAvailableCapacityForImportantUsage,
            raw: values?.volumeAvailableCapacity,
            total: values?.volumeTotalCapacity)
    }
}
