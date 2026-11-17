import AppIntents
import CodexBarCore
import Darwin
import SwiftUI
import WidgetKit

@main
struct CodexBarWidgetBundle: WidgetBundle {
    /// AI Monitor registers the two styled quota widgets plus the Mac status widget. The usage widget's large
    /// size already carries the seven-day chart. The other upstream widgets stay in source (and in tests) so
    /// they can be re-registered here without other changes.
    var body: some Widget {
        CodexBarSwitcherWidget()
        CodexBarUsageWidget()
        StudioMacStatusWidget()
    }
}

struct CodexBarSwitcherWidget: Widget {
    static let kind = "CodexBarSwitcherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: CodexBarSwitcherTimelineProvider())
        { entry in
            CodexBarSwitcherWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(W("CodexBar Switcher").replacingOccurrences(of: "CodexBar", with: "AI Monitor")))
        .description(Text(W("Usage widget with a provider switcher.")))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct CodexBarUsageWidget: Widget {
    private let kind = "CodexBarUsageWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: ProviderSelectionIntent.self,
            provider: CodexBarTimelineProvider())
        { entry in
            CodexBarUsageWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(W("CodexBar Usage").replacingOccurrences(of: "CodexBar", with: "AI Monitor")))
        .description(Text(W("Session and weekly usage with credits and costs.")))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct CodexBarHistoryWidget: Widget {
    private let kind = "CodexBarHistoryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: ProviderSelectionIntent.self,
            provider: CodexBarTimelineProvider())
        { entry in
            CodexBarHistoryWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(W("CodexBar History").replacingOccurrences(of: "CodexBar", with: "AI Monitor")))
        .description(Text(W("Usage history chart with recent totals.")))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct CodexBarCompactWidget: Widget {
    private let kind = "CodexBarCompactWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: CompactMetricSelectionIntent.self,
            provider: CodexBarCompactTimelineProvider())
        { entry in
            CodexBarCompactWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(W("CodexBar Metric").replacingOccurrences(of: "CodexBar", with: "AI Monitor")))
        .description(Text(W("Compact widget for credits or cost.")))
        .supportedFamilies([.systemSmall])
    }
}

enum BurnDownWidgetBackgroundConfiguration {
    static let isRemovable = true
}

struct CodexBarBurnDownWidget: Widget {
    private let kind = "CodexBarBurnDownWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: BurnDownSelectionIntent.self,
            provider: BurnDownTimelineProvider())
        { entry in
            BurnDownWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(W("CodexBar Burn Down").replacingOccurrences(
            of: "CodexBar",
            with: "AI Monitor")))
        .description(Text(W("Remaining budget compared with an ideal steady burn rate.")))
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable(BurnDownWidgetBackgroundConfiguration.isRemovable)
    }
}

struct CodexBarCombinedBurnDownWidget: Widget {
    private let kind = "CodexBarCombinedBurnDownWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: BurnProviderSelectionIntent.self,
            provider: CombinedBurnDownTimelineProvider())
        { entry in
            CombinedBurnDownWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(W("CodexBar Burn Down (Combined)").replacingOccurrences(
            of: "CodexBar",
            with: "AI Monitor")))
        .description(Text(W("Two quota burn-down charts in one tile.")))
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable(BurnDownWidgetBackgroundConfiguration.isRemovable)
    }
}

// MARK: - Local Mac status card

struct StudioMacStatusEntry: TimelineEntry {
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

struct StudioMacStatusProvider: TimelineProvider {
    func placeholder(in _: Context) -> StudioMacStatusEntry {
        StudioMacStatusEntry(date: Date(), cpuSamples: [], memoryPercent: nil, availableGB: nil, diskUsedPercent: nil)
    }

    func getSnapshot(in _: Context, completion: @escaping (StudioMacStatusEntry) -> Void) {
        completion(Self.sample())
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<StudioMacStatusEntry>) -> Void) {
        let entry = Self.sample()
        completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(300))))
    }

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

    private static func sample() -> StudioMacStatusEntry {
        var samples: [Double] = []
        var previous = Self.cpuTicks()
        // A bounded, subsecond sample produces a real sparkline; it is not a background history feed.
        for _ in 0..<8 {
            Thread.sleep(forTimeInterval: 0.08)
            let next = Self.cpuTicks()
            if let previous, let next {
                let delta = zip(previous, next).map { Double($1 &- $0) }
                let total = delta.reduce(0, +)
                if total > 0 { samples.append(min(100, max(0, (total - delta[2]) / total * 100))) }
            }
            previous = next
        }
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
        let disk = MacDiskCapacity.current()
        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        let swapOK = sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0
        var pressure: Int32 = 0
        var pressureSize = MemoryLayout<Int32>.size
        let pressureOK = sysctlbyname("kern.memorystatus_vm_pressure_level", &pressure, &pressureSize, nil, 0) == 0
        return StudioMacStatusEntry(
            date: Date(),
            cpuSamples: samples,
            memoryPercent: memory,
            availableGB: disk?.availableGB,
            diskUsedPercent: disk?.usedPercent,
            memoryTotalGB: Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824,
            swapGB: swapOK ? Double(swap.xsu_used) / 1_073_741_824 : nil,
            pressureLevel: pressureOK ? Int(pressure) : nil,
            diskTotalGB: disk?.totalGB)
    }
}

struct StudioMacStatusView: View {
    let entry: StudioMacStatusEntry

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "chart.bar.fill").font(.system(size: 11))
                    Text(verbatim: "Mac 状态").font(.system(size: 12, weight: .bold))
                    Spacer()
                    Text(self.entry.date, style: .time)
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                    Button(intent: RefreshMacStatusIntent()) {
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
                            Text("定时采样").font(.system(size: 7)).foregroundStyle(.secondary)
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
                    Text("定时更新 · 以上次采样为准")
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

struct StudioMacStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StudioMacStatusWidget", provider: StudioMacStatusProvider()) { entry in
            StudioMacStatusView(entry: entry).modifier(StudioWidgetSurface(macStatus: true))
        }
        .configurationDisplayName("Mac 状态")
        .description("本机 CPU、内存和存储。系统定期采样，不是实时监控。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct RefreshMacStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "刷新 Mac 状态"
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: "StudioMacStatusWidget")
        return .result()
    }
}
