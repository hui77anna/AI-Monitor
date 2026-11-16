import AppKit
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
