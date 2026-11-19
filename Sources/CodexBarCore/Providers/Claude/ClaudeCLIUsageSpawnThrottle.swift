import Foundation

/// Bounds how often background refreshes may relaunch the Claude CLI for a usage probe (#2916).
/// Each CLI usage fetch spawns the full ~280 MB Claude Code binary, so background ticks reuse the
/// last successful CLI result within a floor interval instead of respawning. User-initiated
/// refreshes always spawn so the manual Refresh action stays fresh.
enum ClaudeCLIUsageSpawnThrottle {
    struct Key: Hashable {
        let binary: String
        let accountScope: String
        let useWebExtras: Bool
        let includePrepaidBalance: Bool
    }

    struct Entry {
        let result: ProviderFetchResult
        let recordedAt: Date
    }

    /// AI Monitor checks usage every minute. A probe takes ~10 s, so the next tick finds a result ~50 s old;
    /// a 45 s floor lets every one-minute tick refresh while still absorbing back-to-back refresh triggers.
    /// Each probe launches Claude Code, so this also caps faster schedules. Token history refreshes separately.
    static let minimumBackgroundSpawnInterval: TimeInterval = 45
    /// After a failed background probe (rate limit, network error, CLI timeout, Claude Code mid-update), wait
    /// this long before spawning Claude again, doubling per consecutive failure up to `maximumFailureBackoff`.
    /// The first retry keeps the normal five-minute cadence so a one-off failure recovers on the next tick;
    /// only repeated failures slow down (5 → 10 → 20 → 40 → 60 minutes).
    static let initialFailureBackoff: TimeInterval = 5 * 60
    static let maximumFailureBackoff: TimeInterval = 60 * 60

    struct Failure {
        let error: any Error
        let failedAt: Date
        let consecutiveFailures: Int

        var backoff: TimeInterval {
            let multiplier = pow(2, Double(max(0, self.consecutiveFailures - 1)))
            return min(
                ClaudeCLIUsageSpawnThrottle.maximumFailureBackoff,
                ClaudeCLIUsageSpawnThrottle.initialFailureBackoff * multiplier)
        }
    }

    final class Store: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [Key: Entry] = [:]
        private var failures: [Key: Failure] = [:]
        /// The most recent successful result, kept past the spawn floor so a failed refresh can keep
        /// showing the last known quota (with its original timestamp) instead of blanking the card.
        private var lastSuccess: [Key: Entry] = [:]

        func insert(_ entry: Entry, for key: Key) {
            self.lock.withLock {
                self.entries[key] = entry
                self.lastSuccess[key] = entry
                self.failures.removeValue(forKey: key)
            }
        }

        /// Last good result while none of its windows has reset; nil once it would describe a past window.
        func lastKnownGood(_ key: Key, now: Date) -> Entry? {
            self.lock.withLock {
                guard let entry = self.lastSuccess[key],
                      !ClaudeCLIUsageSpawnThrottle.anyWindowHasReset(in: entry.result.usage, now: now)
                else { return nil }
                return entry
            }
        }

        func insertFailure(_ error: any Error, for key: Key, now: Date) {
            self.lock.withLock {
                let previous = self.failures[key]?.consecutiveFailures ?? 0
                self.failures[key] = Failure(error: error, failedAt: now, consecutiveFailures: previous + 1)
            }
        }

        /// The last failure while its backoff window is still open.
        func activeFailure(_ key: Key, now: Date) -> Failure? {
            self.lock.withLock {
                guard let failure = self.failures[key] else { return nil }
                return now.timeIntervalSince(failure.failedAt) < failure.backoff ? failure : nil
            }
        }

        func lookup(_ key: Key, now: Date) -> Entry? {
            self.lock.withLock {
                guard let entry = self.entries[key] else { return nil }
                guard now.timeIntervalSince(entry.recordedAt) < minimumBackgroundSpawnInterval,
                      !ClaudeCLIUsageSpawnThrottle.anyWindowHasReset(in: entry.result.usage, now: now)
                else {
                    self.entries.removeValue(forKey: key)
                    return nil
                }
                return entry
            }
        }

        func removeAll() {
            self.lock.withLock {
                self.entries.removeAll()
                self.failures.removeAll()
                self.lastSuccess.removeAll()
            }
        }
    }

    private static let log = CodexBarLog.logger(LogCategories.provider(.claude, scope: "usage"))
    private static let sharedStore = Store()
    @TaskLocal private static var storeOverrideForTesting: Store?
    @TaskLocal private static var nowOverrideForTesting: (@Sendable () -> Date)?

    private static var store: Store {
        self.storeOverrideForTesting ?? self.sharedStore
    }

    private static var now: Date {
        self.nowOverrideForTesting?() ?? Date()
    }

    /// nil when the Claude profile exposes no stable account identity
    /// (`ClaudeAccountProfile.identifiedSessionScope` returns nil) — such profiles are never cached.
    static func key(
        binary: String,
        environment: [String: String],
        useWebExtras: Bool,
        includePrepaidBalance: Bool) -> Key?
    {
        guard let accountScope = ClaudeAccountProfile.identifiedSessionScope(environment: environment) else {
            return nil
        }
        return Key(
            binary: binary,
            accountScope: accountScope,
            useWebExtras: useWebExtras,
            includePrepaidBalance: includePrepaidBalance)
    }

    /// Returns the cached result when it is younger than `minimumBackgroundSpawnInterval`.
    /// A stale or missing entry returns nil (and a stale entry is removed).
    static func cachedResult(for key: Key) -> ProviderFetchResult? {
        let now = self.now
        guard let entry = self.store.lookup(key, now: now) else { return nil }
        let ageSeconds = max(0, now.timeIntervalSince(entry.recordedAt))
        Self.log.debug(
            "Reusing cached Claude CLI usage result",
            metadata: ["ageSeconds": "\(ageSeconds)"])
        return entry.result
    }

    static func record(_ result: ProviderFetchResult, for key: Key) {
        self.store.insert(Entry(result: result, recordedAt: self.now), for: key)
    }

    /// The last successful result to keep showing after a failed background refresh, if still valid.
    static func lastKnownGoodResult(for key: Key) -> ProviderFetchResult? {
        self.store.lastKnownGood(key, now: self.now)?.result
    }

    static func recordFailure(_ error: any Error, for key: Key) {
        self.store.insertFailure(error, for: key, now: self.now)
    }

    /// The previous background failure to report again instead of respawning Claude during backoff.
    static func backoffError(for key: Key) -> (any Error)? {
        let now = self.now
        guard let failure = self.store.activeFailure(key, now: now) else { return nil }
        Self.log.debug(
            "Skipping Claude CLI usage spawn during failure backoff",
            metadata: [
                "consecutiveFailures": "\(failure.consecutiveFailures)",
                "backoffSeconds": "\(failure.backoff)",
            ])
        return failure.error
    }

    /// A cached result is unusable once any of its rate windows crosses its reset boundary: the
    /// session/weekly percentages then describe the previous window, and the reset-boundary refresh
    /// scheduler exists precisely to publish the post-reset state promptly.
    static func anyWindowHasReset(in usage: UsageSnapshot, now: Date) -> Bool {
        let windows = [usage.primary, usage.secondary, usage.tertiary]
            .compactMap(\.self)
            + (usage.extraRateWindows?.map(\.window) ?? [])
        return windows.contains { window in
            guard let resetsAt = window.resetsAt else { return false }
            return resetsAt <= now
        }
    }

    #if DEBUG
    static func withIsolatedStoreForTesting<T>(
        operation: () async throws -> T) async rethrows -> T
    {
        try await self.$storeOverrideForTesting.withValue(Store()) {
            try await operation()
        }
    }

    static func withNowOverrideForTesting<T>(
        _ now: @escaping @Sendable () -> Date,
        operation: () async throws -> T) async rethrows -> T
    {
        try await self.$nowOverrideForTesting.withValue(now) {
            try await operation()
        }
    }
    #endif
}
