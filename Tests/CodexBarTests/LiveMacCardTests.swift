import AppKit
import CodexBarCore
import SwiftUI
import Testing
@testable import CodexBar

@MainActor
struct LiveMacCardTests {
    @Test func `CPU measures interval busy time and rejects empty intervals`() {
        #expect(LiveMacSampler.cpuPercent(previous: [100, 100, 100, 100], next: [110, 110, 170, 110]) == 30)
        #expect(LiveMacSampler.cpuPercent(previous: [0, 0, 0, 0], next: [0, 0, 0, 0]) == nil)
        #expect(LiveMacSampler.cpuPercent(previous: [], next: []) == nil)
        #expect(LiveMacSampler.cpuPercent(previous: [UInt32.max, 0, 0, 0], next: [0, 0, 0, 0]) == 100)
    }

    @Test func `live sampler updates every second stops and resumes`() async throws {
        let sampler = LiveMacSampler()
        sampler.start()
        defer { sampler.stop() }
        let initial = sampler.entry.date
        try await Task.sleep(for: .milliseconds(2300))
        #expect(sampler.entry.date > initial)
        #expect(!sampler.entry.cpuSamples.isEmpty)
        #expect(sampler.entry.memoryPercent != nil)
        #expect(sampler.entry.availableGB != nil)
        sampler.stop()
        try await Task.sleep(for: .milliseconds(200))
        let stopped = sampler.entry.date
        try await Task.sleep(for: .milliseconds(1200))
        #expect(sampler.entry.date == stopped)
        sampler.start()
        try await Task.sleep(for: .milliseconds(1200))
        #expect(sampler.entry.date > stopped)
    }

    @Test func `render floating card with explicit sample data`() throws {
        guard let directory = ProcessInfo.processInfo.environment["AI_MONITOR_LIVE_PROOF_DIR"] else { return }
        let entry = LiveMacEntry(
            date: Date(),
            cpuSamples: [48, 43, 45, 41, 39, 43],
            memoryPercent: 48,
            availableGB: 213,
            diskUsedPercent: 57,
            memoryTotalGB: 16,
            swapGB: 3,
            pressureLevel: 1,
            diskTotalGB: 494)
        let view = LiveMacCardView(entry: entry, refresh: {})
            .padding(14).frame(width: 348, height: 164)
            .background(LinearGradient(
                colors: [Color(red: 0.055, green: 0.052, blue: 0.075), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 22)).environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let bitmap = try NSBitmapImageRep(cgImage: #require(renderer.cgImage))
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("ai-monitor-live-mac.png"))
    }
}

@MainActor
struct LiveMacCardControllerTests {
    @Test func `disk capacity prefers the Finder available value and falls back to raw free space`() throws {
        let finder = try #require(MacDiskCapacity.resolve(important: 150_000_000_000, raw: 80_000_000_000, total: 500_000_000_000))
        #expect(finder.availableGB == 150)
        #expect(finder.totalGB == 500)
        #expect(finder.usedPercent == 70)
        #expect(MacDiskCapacity.resolve(important: nil, raw: 80_000_000_000, total: 500_000_000_000)?.availableGB == 80)
        #expect(MacDiskCapacity.resolve(important: 0, raw: 80_000_000_000, total: 500_000_000_000)?.availableGB == 80)
        #expect(MacDiskCapacity.resolve(important: 9_000_000_000_000, raw: nil, total: 500_000_000_000)?.usedPercent == 0)
        #expect(MacDiskCapacity.resolve(important: 1, raw: 1, total: 0) == nil)
        #expect(MacDiskCapacity.current() != nil)
    }

    @Test func `card can be disabled and pauses sampling while locked or occluded`() throws {
        let suite = "LiveMacCardControllerTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let controller = LiveMacCardController(defaults: defaults)
        defer { controller.stop(); controller.hide() }

        #expect(controller.isEnabled)
        controller.show()
        #expect(controller.isSampling)

        controller.setPaused(.screensLocked, true)
        #expect(!controller.isSampling)
        controller.setPaused(.occluded, true)
        controller.setPaused(.screensLocked, false)
        #expect(!controller.isSampling)
        controller.setPaused(.occluded, false)
        #expect(controller.isSampling)

        controller.setEnabled(false)
        #expect(!controller.isEnabled)
        #expect(!controller.isSampling)
        #expect(defaults.bool(forKey: LiveMacCardController.enabledKey) == false)

        controller.setEnabled(true)
        #expect(controller.isSampling)
    }
}
