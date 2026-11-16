import AppKit
import Darwin
import Observation
import SwiftUI

struct LiveMacEntry {
    let date: Date
    let cpuSamples: [Double]
    let memoryPercent: Double?
    let availableGB: Double?
    let diskUsedPercent: Double?
    var memoryTotalGB: Double?
    var swapGB: Double?
    var pressureLevel: Int?
    var diskTotalGB: Double?
}

@MainActor
@Observable
final class LiveMacSampler {
    var entry = LiveMacEntry(date: Date(), cpuSamples: [], memoryPercent: nil, availableGB: nil, diskUsedPercent: nil)
    private var previousTicks: [UInt32]?
    private var samples: [Double] = []
    private var diskSampleDate: Date?
    private var diskFree: Double?
    private var diskTotal: Double?
    private var diskUsed: Double?
    private var timer: Timer?

    static func cpuPercent(previous: [UInt32], next: [UInt32]) -> Double? {
        guard previous.count == 4, next.count == 4 else { return nil }
        let delta = zip(previous, next).map { Double($1 &- $0) }
        let total = delta.reduce(0, +)
        return total > 0 ? min(100, max(0, (total - delta[2]) / total * 100)) : nil
    }

    func start() {
        guard self.timer == nil else { return }
        self.previousTicks = nil
        self.refresh()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        self.timer?.invalidate()
        self.timer = nil
        self.previousTicks = nil
    }

    func refresh() { self.entry = self.sample() }
    private static func cpuTicks() -> [UInt32]? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return nil }
        return [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3]
    }

    func sample() -> LiveMacEntry {
        let next = Self.cpuTicks()
        if let previous = self.previousTicks, let next,
           let percent = Self.cpuPercent(previous: previous, next: next)
        {
            self.samples.append(percent)
            self.samples = Array(self.samples.suffix(30))
        }
        self.previousTicks = next
        var memory: Double?
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if status == KERN_SUCCESS {
            let pages = Double(info.active_count) + Double(info.wire_count) + Double(info.compressor_page_count)
            memory = min(
                100,
                pages * Double(getpagesize()) / Double(ProcessInfo.processInfo.physicalMemory) * 100)
        }
        if self.diskSampleDate == nil || Date().timeIntervalSince(self.diskSampleDate!) >= 30 {
            let filesystem = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            let free = (filesystem?[.systemFreeSize] as? NSNumber)?.doubleValue
            let total = (filesystem?[.systemSize] as? NSNumber)?.doubleValue
            let used = free.flatMap { free in total.flatMap { $0 > 0 ? (1 - free / $0) * 100 : nil } }
            self.diskFree = free
            self.diskTotal = total
            self.diskUsed = used
            self.diskSampleDate = Date()
        }
        let free = self.diskFree
        let total = self.diskTotal
        let used = self.diskUsed
        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        let swapOK = sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0
        var pressure: Int32 = 0
        var pressureSize = MemoryLayout<Int32>.size
        let pressureOK = sysctlbyname("kern.memorystatus_vm_pressure_level", &pressure, &pressureSize, nil, 0) == 0
        return LiveMacEntry(
            date: Date(),
            cpuSamples: self.samples,
            memoryPercent: memory,
            availableGB: free.map { $0 / 1_000_000_000 },
            diskUsedPercent: used,
            memoryTotalGB: Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824,
            swapGB: swapOK ? Double(swap.xsu_used) / 1_073_741_824 : nil,
            pressureLevel: pressureOK ? Int(pressure) : nil,
            diskTotalGB: total.map { $0 / 1_000_000_000 })
    }
}

struct LiveMacCardView: View {
    let entry: LiveMacEntry
    var refresh: () -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "chart.bar.fill").font(.system(size: 11))
                    Text(verbatim: "Mac 状态").font(.system(size: 12, weight: .bold))
                    Spacer()
                    Text(self.entry.date, style: .time)
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                    Button(action: self.refresh) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 10, weight: .semibold))
                    }.buttonStyle(.plain).foregroundStyle(.secondary)
                        .accessibilityLabel(Text(verbatim: "刷新 Mac 状态"))
                }
                if geometry.size.width < 200 {
                    self.compactMetric("CPU", value: self.entry.cpuSamples.last, unit: "%", color: .cyan)
                    self.compactMetric("内存", value: self.entry.memoryPercent, unit: "%", color: .mint)
                    self.compactMetric("可用", value: self.entry.availableGB, unit: " GB", color: .orange)
                } else {
                    HStack(alignment: .top, spacing: 8) {
                        self.metric("CPU", value: self.entry.cpuSamples.last, unit: "%", color: .cyan) {
                            GeometryReader { geometry in
                                Path { path in
                                    for (index, value) in self.entry.cpuSamples.enumerated() {
                                        let point = CGPoint(
                                            x: CGFloat(index) / CGFloat(max(1, self.entry.cpuSamples.count - 1)) *
                                                geometry
                                                .size
                                                .width,
                                            y: (1 - value / 100) * geometry.size.height)
                                        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                                    }
                                }.stroke(Color(red: 0.12, green: 0.67, blue: 0.86), lineWidth: 1.25)
                            }.frame(height: 32).padding(.top, 7)
                            Text(verbatim: "实时 · 1 秒").font(.system(size: 7)).foregroundStyle(.secondary)
                        }
                        Rectangle().fill(.white.opacity(0.07)).frame(width: 0.5)
                        self.metric("内存占用", value: self.entry.memoryPercent, unit: "%", color: .mint) {
                            self.track(self.entry.memoryPercent, color: .mint)
                            Text(self.memoryDetail).font(.system(size: 7)).foregroundStyle(.secondary)
                            Text(verbatim: "Swap " + self.number(self.entry.swapGB) + " GB")
                                .font(.system(size: 7)).foregroundStyle(.secondary)
                            HStack(spacing: 3) {
                                Text(self.pressureLabel).font(.system(size: 7)).foregroundStyle(.secondary)
                                self.pressureIndicator
                            }.padding(.top, 9)
                        }
                        Rectangle().fill(.white.opacity(0.07)).frame(width: 0.5)
                        self.metric("存储", value: self.entry.availableGB, unit: "GB", color: .orange) {
                            self.track(self.entry.diskUsedPercent.map { 100 - $0 }, color: .orange)
                            Text("可用 · 共 " + self.number(self.entry.diskTotalGB, decimals: 0) + " GB")
                                .font(.system(size: 7)).foregroundStyle(.secondary)
                        }
                    }
                }
                if geometry.size.width < 200 {
                    Text(verbatim: "实时 · 1 秒")
                        .font(.system(size: 8)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func number(_ value: Double?, decimals: Int = 1) -> String {
        value.map { String(format: "%.*f", decimals, $0) } ?? "—"
    }

    private var memoryDetail: String {
        let used = self.entry.memoryTotalGB.flatMap { total in self.entry.memoryPercent.map { total * $0 / 100 } }
        return "已用 " + self.number(used) + " / " + self.number(self.entry.memoryTotalGB, decimals: 0) + " GB"
    }

    private var pressureLabel: String {
        guard let level = self.entry.pressureLevel else { return "压力未知" }
        return level >= 4 ? "压力高" : level >= 2 ? "压力中" : "压力低"
    }

    private var pressureIndicator: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Capsule().fill([Color.mint, .orange, .red][index].opacity(
                    self.entry.pressureLevel.map { level in
                        index == (level >= 4 ? 2 : level >= 2 ? 1 : 0) ? 1 : 0.18
                    } ?? 0.12))
            }
        }.frame(height: 3).accessibilityLabel("内存压力等级 " + (self.entry.pressureLevel.map(String.init) ?? "未知"))
    }

    private func compactMetric(_ title: String, value: Double?, unit: String, color: Color) -> some View {
        HStack {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            Spacer()
            Text((value.map { String(format: "%.0f", $0) } ?? "—") + unit)
                .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(color)
        }
    }

    private func metric(
        _ title: String,
        value: Double?,
        unit: String,
        color _: Color,
        @ViewBuilder detail: () -> some View) -> some View
    {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 9)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(value.map { String(format: "%.0f", $0) } ?? "—")
                    .font(.system(size: 27, weight: .medium, design: .rounded))
                Text(unit).font(.system(size: unit == "GB" ? 24 : 26, weight: .medium))
            }.lineLimit(1).minimumScaleFactor(0.7)
            detail()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func track(_ percent: Double?, color: Color) -> some View {
        GeometryReader { geometry in
            Capsule().fill(.primary.opacity(0.12))
                .overlay(alignment: .leading) {
                    Capsule().fill(color).frame(width: geometry.size.width * min(1, max(0, (percent ?? 0) / 100)))
                }
        }.frame(height: 4)
    }
}

@MainActor
final class LiveMacCardController: NSObject, NSWindowDelegate {
    static let shared = LiveMacCardController()
    private let sampler = LiveMacSampler()
    private var panel: NSPanel?
    private var sleeping = false

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(self.sleep), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(self.wake), name: NSWorkspace.didWakeNotification, object: nil)
        self.show()
    }

    func show() {
        if self.panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 80, y: 100, width: 348, height: 164),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false)
            panel.title = "AI Monitor · Mac 实时状态"
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.isMovableByWindowBackground = true
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            panel.delegate = self
            panel.setFrameAutosaveName("AI Monitor Live Mac Card")
            if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }),
               let screen = NSScreen.main
            {
                panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.minX + 24, y: screen.visibleFrame.maxY - 190))
            }
            panel.contentView = NSHostingView(rootView: LiveMacCardRoot(sampler: self.sampler))
            self.panel = panel
        }
        self.panel?.orderFrontRegardless()
        if !self.sleeping { self.sampler.start() }
    }

    @objc private func sleep() { self.sleeping = true; self.sampler.stop() }
    @objc private func wake() { self.sleeping = false; self.sampler.start() }
    func stop() {
        self.sampler.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}

private struct LiveMacCardRoot: View {
    let sampler: LiveMacSampler
    var body: some View {
        LiveMacCardView(entry: self.sampler.entry, refresh: { self.sampler.refresh() })
            .padding(14)
            .background(LinearGradient(
                colors: [Color(red: 0.055, green: 0.052, blue: 0.075), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .environment(\.colorScheme, .dark)
    }
}
