import AIMonitorQuotaUI
import AppKit
import CodexBarCore
import SwiftUI
import Testing
@testable import CodexBar

@MainActor
struct LiveQuotaCardTests {
    private static func snapshot(providers: [UsageProvider]) -> WidgetSnapshot {
        let now = Date()
        let entries = providers.map { provider in
            WidgetSnapshot.ProviderEntry(
                provider: provider,
                updatedAt: now.addingTimeInterval(-7 * 60),
                primary: RateWindow(
                    usedPercent: 5, windowMinutes: 300, resetsAt: now.addingTimeInterval(4 * 3600),
                    resetDescription: nil),
                secondary: RateWindow(
                    usedPercent: 46, windowMinutes: 10080, resetsAt: now.addingTimeInterval(3 * 86400),
                    resetDescription: nil),
                tertiary: nil,
                creditsRemaining: nil,
                codeReviewRemainingPercent: nil,
                tokenUsage: nil,
                dailyUsage: [
                    .init(dayKey: "2026-11-12", totalTokens: 25_000_000, costUSD: nil),
                    .init(dayKey: "2026-11-15", totalTokens: 27_000_000, costUSD: nil),
                    .init(dayKey: "2026-11-16", totalTokens: 163_000_000, costUSD: nil),
                    .init(dayKey: "2026-11-17", totalTokens: 150_000_000, costUSD: nil),
                    .init(dayKey: "2026-11-18", totalTokens: 32_000_000, costUSD: nil),
                ])
        }
        return WidgetSnapshot(entries: entries, generatedAt: now)
    }

    @Test func `card pages only through Codex and Claude present in the snapshot`() {
        #expect(AIMonitorQuotaCardView.providers(in: Self.snapshot(providers: [.claude, .codex])) == [.claude, .codex])
        #expect(AIMonitorQuotaCardView.providers(in: Self.snapshot(providers: [.claude])) == [.claude])
        #expect(AIMonitorQuotaCardView.providers(in: Self.snapshot(providers: [])) == [.codex])
    }

    @Test func `model remembers the selected provider and falls back when it disappears`() throws {
        let suite = "LiveQuotaCardTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var available: [UsageProvider] = [.codex, .claude]
        let model = LiveQuotaCardModel(defaults: defaults, load: { _ in Self.snapshot(providers: available) })
        model.reload()
        #expect(model.provider == .codex)
        model.select(.claude)
        #expect(LiveQuotaCardModel(defaults: defaults, load: { _ in nil }).provider == .claude)

        available = [.codex]
        model.reload()
        #expect(model.provider == .codex)
    }

    @Test func `card can be hidden and shown and reloads on snapshot publication`() throws {
        let suite = "LiveQuotaCardControllerTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var loads = 0
        let model = LiveQuotaCardModel(defaults: defaults, load: { _ in
            loads += 1
            return Self.snapshot(providers: [.claude])
        })
        let controller = LiveQuotaCardController(defaults: defaults, model: model)
        defer { controller.stop(); controller.hide() }
        controller.start()
        #expect(controller.isVisible)
        let before = loads
        NotificationCenter.default.post(name: .aiMonitorWidgetSnapshotPublished, object: nil)
        #expect(loads > before)

        controller.setEnabled(false)
        #expect(!controller.isVisible)
        #expect(defaults.bool(forKey: LiveQuotaCardController.enabledKey) == false)
        controller.setEnabled(true)
        #expect(controller.isVisible)
    }

    @Test func `render floating quota card with explicit sample data`() throws {
        guard let directory = ProcessInfo.processInfo.environment["AI_MONITOR_LIVE_PROOF_DIR"] else { return }
        let snapshot = Self.snapshot(providers: [.codex, .claude])
        let view = AIMonitorQuotaCardView(
            snapshot: snapshot, provider: .claude, providers: [.codex, .claude], select: { _ in })
            .padding(16)
            .frame(width: LiveQuotaCardController.cardSize.width, height: LiveQuotaCardController.cardSize.height)
            .background(AIMonitorQuotaCardBackground())
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let bitmap = try NSBitmapImageRep(cgImage: #require(renderer.cgImage))
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("ai-monitor-live-quota.png"))
    }
}
