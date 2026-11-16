import AppKit
import CodexBarCore
import SwiftUI
import Testing
@testable import CodexBarWidget

@MainActor
struct StudioWidgetRenderTests {
    @Test
    func `segmented bar preserves fractional percentages and bounds invalid values`() {
        #expect(QuotaBar.fillFraction(12.345) == 0.12345)
        #expect(QuotaBar.fillFraction(0) == 0)
        #expect(QuotaBar.fillFraction(100) == 1)
        #expect(QuotaBar.fillFraction(-5) == 0)
        #expect(QuotaBar.fillFraction(150) == 1)
        #expect(QuotaBar.fillFraction(.nan) == 0)
        #expect(QuotaBar.fillFraction(.infinity) == 0)
        #expect(QuotaBar.fillFraction(nil) == 0)
    }

    @Test
    func `reference history preserves calendar gaps zero and unknown values`() {
        let points = [
            ("2026-11-01", 99),
            ("2026-11-10", 0),
            ("2026-11-12", -1),
            ("2026-11-14", 20),
            ("2026-11-14", 30),
            ("invalid", 500),
        ]
            .map { WidgetSnapshot.DailyUsagePoint(dayKey: $0.0, totalTokens: $0.1, costUSD: nil) }
        let days = ReferenceTokenHistory.days(points)
        #expect(days.map(\.id) == (8...14).map { "2026-11-" + String(format: "%02d", $0) })
        #expect(days.map(\.tokens) == [nil, nil, 0, nil, nil, nil, 30])
        #expect(ReferenceTokenHistory.days([]).isEmpty)
    }

    @Test
    func `renders Mac status with explicit sample data`() throws {
        guard let directory = ProcessInfo.processInfo.environment["CODEXBAR_WIDGET_PROOF_DIR"] else { return }
        let view = StudioMacStatusView(entry: StudioMacStatusEntry(
            date: Date(),
            cpuSamples: [43, 35, 39, 24, 28, 19, 25, 43],
            memoryPercent: 48,
            availableGB: 213,
            diskUsedPercent: 58,
            memoryTotalGB: 16,
            swapGB: 3,
            pressureLevel: 1,
            diskTotalGB: 494))
            .environment(\.colorScheme, .dark)
            .padding(14).frame(width: 329, height: 155)
            .background(StudioWidgetBackground(macStatus: true))
            .clipShape(RoundedRectangle(cornerRadius: 22))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let bitmap = try NSBitmapImageRep(cgImage: #require(renderer.cgImage))
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("mac-status-sample.png"))
    }

    @Test
    func `renders studio cards using the shipped tile views and synthetic data`() throws {
        guard let directory = ProcessInfo.processInfo.environment["CODEXBAR_WIDGET_PROOF_DIR"] else { return }
        let output = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let now = Date()
        for provider in [UsageProvider.codex, .claude] {
            let entry = WidgetSnapshot.ProviderEntry(
                provider: provider,
                updatedAt: now.addingTimeInterval(-120),
                primary: RateWindow(
                    usedPercent: provider == .codex ? 28 : 42,
                    windowMinutes: 300,
                    resetsAt: now.addingTimeInterval(7200),
                    resetDescription: nil),
                secondary: RateWindow(
                    usedPercent: provider == .codex ? 56 : 35,
                    windowMinutes: 10080,
                    resetsAt: now.addingTimeInterval(172_800),
                    resetDescription: nil),
                dailyUsage: [12000, 24000, 18000, 39000, 28000, 45000, 32000].enumerated().map {
                    WidgetSnapshot.DailyUsagePoint(
                        dayKey: "2026-11-\(String(format: "%02d", 8 + $0.offset))",
                        totalTokens: $0.element,
                        costUSD: nil)
                })
            for (name, size, width, height) in [
                ("small", WidgetTileSize.small, 155.0, 155.0),
                ("medium", .medium, 329.0, 155.0),
                ("large", .large, 329.0, 345.0),
            ] {
                try WidgetLocalizationOverride.$language.withValue("zh-Hans") {
                    let view = UsageTile(entry: entry, size: size) {
                        TileHeader(provider: entry.provider, updatedAt: entry.updatedAt, size: size)
                    }
                    .environment(\.colorScheme, .dark)
                    .environment(\.locale, Locale(identifier: "zh-Hans"))
                    .padding(14)
                    .frame(width: width, height: height)
                    .background(StudioWidgetBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    let renderer = ImageRenderer(content: view)
                    renderer.scale = 2
                    let bitmap = try NSBitmapImageRep(cgImage: #require(renderer.cgImage))
                    let png = try #require(bitmap.representation(using: .png, properties: [:]))
                    try png.write(to: output.appendingPathComponent("\(provider.rawValue)-\(name)-sample.png"))
                }
            }
        }
    }
}
