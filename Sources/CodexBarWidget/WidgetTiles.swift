import CodexBarCore
import SwiftUI

/// The three macOS tile shapes, decoupled from `WidgetFamily` so layouts can be rendered and
/// reasoned about outside a widget host.
enum WidgetTileSize {
    case small
    case medium
    case large

    var heroNumberSize: CGFloat {
        switch self {
        case .small: 24
        case .medium: 34
        case .large: 42
        }
    }

    var markSize: CGFloat {
        self == .small ? WidgetLayout.markSizeSmall : WidgetLayout.markSizeRegular
    }

    /// How many lanes fit below the headline before the tile starts clipping.
    ///
    /// A cost block costs about one lane of height and the history chart about two, so the budget
    /// has to know what else the tile is drawing — a fixed cap either clips a busy provider or
    /// pages a sparse one for no reason.
    func secondaryLaneCapacity(hasMetrics: Bool, hasChart: Bool) -> Int {
        switch self {
        case .small:
            return 2
        case .medium:
            return hasMetrics ? 2 : 3
        case .large:
            var capacity = 6
            if hasChart { capacity -= 2 }
            if hasMetrics { capacity -= 2 }
            return max(1, capacity)
        }
    }

    /// Small tiles list the remaining lanes as figures only: at 127pt of usable height a 7pt bar
    /// costs as much room as the number it duplicates.
    var showsSecondaryBars: Bool {
        self != .small
    }

    /// Large tiles carry the history chart, but only while the quota lanes leave it enough room to
    /// be a chart: squeezed to a few points it is noise, and the dedicated History widget covers
    /// providers with more lanes than that.
    func showsChart(laneCount: Int, hasHistory: Bool) -> Bool {
        self == .large && hasHistory && laneCount <= 3
    }

    var laneSpacing: CGFloat {
        self == .small ? 5 : WidgetLayout.laneSpacing
    }
}

// MARK: - Tile

/// Shared body for the usage and switcher widgets across all three families.
///
/// One layout means the two widgets cannot drift apart, and every size difference is a value in
/// `WidgetTileSize` rather than a separate near-duplicate view.
struct UsageTile<Header: View>: View {
    @Environment(\.widgetUsageShowsUsed) private var showsUsed
    let entry: WidgetSnapshot.ProviderEntry
    let size: WidgetTileSize
    @ViewBuilder let header: () -> Header

    var body: some View {
        // Provider-specific by design: the reference design targets these two coding services.
        if self.entry.provider == .codex || self.entry.provider == .claude {
            ReferenceUsageTile(entry: self.entry, size: self.size, header: self.header)
        } else {
            self.standardBody
        }
    }

    @ViewBuilder
    private var standardBody: some View {
        let color = WidgetColors.color(for: self.entry.provider)
        // The provider's compact row cap curates what a tile may LIST; it must not decide which
        // lane is binding. Headline and overflow are computed against the full set.
        let allLanes = WidgetTileLane.lanes(for: self.entry)
        let displayLanes = self.laneLimit == nil
            ? allLanes
            : WidgetTileLane.lanes(for: self.entry, limit: self.laneLimit)
        let hasChart = self.size.showsChart(
            laneCount: allLanes.count,
            hasHistory: !self.entry.dailyUsage.isEmpty)
        let fallback = allLanes.contains(where: \.isHeadlineCandidate) ? nil : WidgetFallbackHero.make(for: self.entry)
        let metrics = WidgetMetricRows.rows(
            for: self.entry,
            size: self.size,
            secondaryLaneCount: max(0, allLanes.count - 1),
            excluding: fallback?.consumedMetricID)
        let plan = WidgetTilePlan.make(
            lanes: allLanes,
            displayCandidates: displayLanes,
            maxSecondaryLanes: self.size.secondaryLaneCapacity(
                hasMetrics: !metrics.isEmpty,
                hasChart: hasChart),
            reservesOverflowRow: self.size != .large)

        if self.size == .small {
            ViewThatFits(in: .vertical) {
                ForEach([2, 1, 0], id: \.self) { capacity in
                    self.smallContent(
                        plan: WidgetTilePlan.make(
                            lanes: allLanes,
                            displayCandidates: displayLanes,
                            maxSecondaryLanes: capacity,
                            reservesOverflowRow: true),
                        fallback: fallback,
                        color: color,
                        metrics: metrics)
                        .fixedSize(horizontal: false, vertical: true)
                }
                self.smallContent(
                    plan: WidgetTilePlan.make(
                        lanes: allLanes,
                        displayCandidates: displayLanes,
                        maxSecondaryLanes: 0,
                        reservesOverflowRow: true),
                    fallback: fallback,
                    color: color,
                    metrics: [])
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(alignment: .leading, spacing: WidgetLayout.sectionSpacing) {
                self.header()
                // Medium splits into columns only when there are lanes to fill the right one. A
                // single-lane provider in two columns leaves a void beside the headline; down one
                // column it gets the full width for its bar instead.
                if self.size == .medium, !plan.lanes.isEmpty {
                    HStack(alignment: .top, spacing: 14) {
                        self.hero(plan: plan, fallback: fallback, color: color, spreads: !metrics.isEmpty)
                            .frame(width: 104, alignment: .leading)
                        VStack(alignment: .leading, spacing: WidgetLayout.laneSpacing) {
                            self.lanes(plan: plan, color: color)
                            if !metrics.isEmpty {
                                Spacer(minLength: 2)
                                self.metrics(metrics)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    self.hero(plan: plan, fallback: fallback, color: color, spreads: false)
                    VStack(alignment: .leading, spacing: self.size.laneSpacing) {
                        self.lanes(plan: plan, color: color)
                    }
                    self.metrics(metrics)
                    if hasChart {
                        UsageHistoryChart(
                            points: self.entry.dailyUsage,
                            color: color,
                            currencyCode: self.entry.tokenUsage?.currencyCode)
                            .frame(minHeight: 66, maxHeight: .infinity)
                    } else {
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// Providers cap how many lanes a compact tile may show; large tiles take everything and page
    /// the excess behind a "+N more" line.
    private var laneLimit: Int? {
        switch self.size {
        case .small: WidgetUsageRow.smallWidgetRowLimit(for: self.entry)
        case .medium: WidgetUsageRow.mediumWidgetRowLimit(for: self.entry)
        case .large: nil
        }
    }

    private func smallContent(
        plan: WidgetTilePlan,
        fallback: WidgetFallbackHeroContent?,
        color: Color,
        metrics: [WidgetMetricRow]) -> some View
    {
        VStack(alignment: .leading, spacing: 4) {
            self.header()
            self.hero(plan: plan, fallback: fallback, color: color, spreads: false)
            VStack(alignment: .leading, spacing: 3) {
                self.lanes(plan: plan, color: color)
            }
            self.metrics(metrics)
        }
    }

    // MARK: Headline

    @ViewBuilder
    private func hero(
        plan: WidgetTilePlan,
        fallback: WidgetFallbackHeroContent?,
        color: Color,
        spreads: Bool) -> some View
    {
        if let lane = plan.hero {
            let displayed = WidgetUsageDisplay.percent(
                fromRemaining: lane.remainingPercent,
                showUsed: self.showsUsed)
            let title = WidgetLaneCopy.caption(
                title: W("%@ %@", W(lane.title), WidgetFormat.percent(displayed)),
                showUsed: self.showsUsed)
            HeroBlock(
                value: WidgetFormat.percent(displayed),
                caption: Text(WidgetLaneCopy.caption(title: lane.title, showUsed: self.showsUsed)),
                detail: self.resetText(lane),
                barPercent: displayed ?? 0,
                isLow: QuotaSeverity.isLow(remaining: lane.remainingPercent),
                color: color,
                numberSize: self.size.heroNumberSize,
                spreads: spreads,
                compact: self.size == .small,
                inlineQuotaTitle: title)
        } else if let fallback {
            HeroBlock(
                value: fallback.value,
                caption: WidgetFormat.tokenRowTitle(
                    fallback.caption,
                    summary: fallback.consumedMetricID == "session-cost" ? self.entry.tokenUsage : nil,
                    entryUpdatedAt: self.entry.updatedAt),
                detail: fallback.detail.map { Text($0) },
                numberSize: self.size.heroNumberSize,
                compact: self.size == .small)
        }
    }

    private func resetText(_ lane: WidgetTileLane) -> Text? {
        switch WidgetLaneCopy.reset(resetsAt: lane.resetsAt, resetDescription: lane.resetDescription) {
        case let .date(reset): WidgetDateText.reset(reset)
        case let .text(value): Text(value)
        case nil: nil
        }
    }

    // MARK: Lanes

    @ViewBuilder
    private func lanes(plan: WidgetTilePlan, color: Color) -> some View {
        ForEach(plan.lanes) { lane in
            QuotaLaneView(
                title: lane.title,
                percent: WidgetUsageDisplay.percent(
                    fromRemaining: lane.remainingPercent,
                    showUsed: self.showsUsed),
                remainingPercent: lane.remainingPercent,
                color: color,
                showsBar: self.size.showsSecondaryBars)
        }
        if plan.overflowCount > 0 {
            Text(W("+%@ more", String(describing: plan.overflowCount)))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: Cost and credit rows

    @ViewBuilder
    private func metrics(_ lines: [WidgetMetricRow]) -> some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                if self.size != .small {
                    WidgetSeparator().padding(.bottom, 2)
                }
                ForEach(lines) { line in
                    MetricLine(
                        title: WidgetFormat.tokenRowTitle(
                            line.title,
                            summary: ["session-cost", "last30"].contains(line.id) ? self.entry.tokenUsage : nil,
                            entryUpdatedAt: self.entry.updatedAt),
                        value: line.value,
                        isProminent: line.isProminent)
                }
            }
        }
    }
}

// MARK: - Metric rows

struct WidgetMetricRow: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    var isProminent: Bool = false
}

enum WidgetMetricRows {
    /// Cost, credit and balance lines, trimmed to what each tile can show without clipping.
    static func rows(
        for entry: WidgetSnapshot.ProviderEntry,
        size: WidgetTileSize,
        secondaryLaneCount: Int = 0,
        excluding excludedID: String? = nil) -> [WidgetMetricRow]
    {
        let rows = self.allRows(for: entry, size: size, secondaryLaneCount: secondaryLaneCount)
            .filter { $0.id != excludedID }
        return Array(rows.prefix(self.rowCapacity(for: size)))
    }

    /// Hard ceiling per tile so an unusual provider (credits *and* costs *and* a balance) cannot
    /// push the lanes off the tile.
    private static func rowCapacity(for size: WidgetTileSize) -> Int {
        switch size {
        case .small: 1
        case .medium: 2
        case .large: 3
        }
    }

    private static func allRows(
        for entry: WidgetSnapshot.ProviderEntry,
        size: WidgetTileSize,
        secondaryLaneCount: Int) -> [WidgetMetricRow]
    {
        var rows: [WidgetMetricRow] = []
        if size == .small {
            // A small tile spends its height on quota lanes. With none below the headline the room
            // is there, so a single-lane provider gets its cost line instead of empty space.
            guard secondaryLaneCount == 0,
                  let token = entry.tokenUsage ?? WidgetUsageRow.compactTokenUsage(for: entry)
            else {
                return self.balanceRows(for: entry)
            }
            rows.append(self.sessionRow(token: token, entry: entry, isProminent: true, compact: true))
            return rows + self.balanceRows(for: entry)
        }

        if let credits = entry.creditsRemaining {
            rows.append(WidgetMetricRow(id: "credits", title: "Credits", value: WidgetFormat.credits(credits)))
        }
        if let token = entry.tokenUsage {
            rows.append(self.sessionRow(token: token, entry: entry, isProminent: true))
            if size == .large {
                rows.append(WidgetMetricRow(
                    id: "last30",
                    title: token.last30DaysLabel,
                    value: WidgetFormat.costAndTokens(
                        cost: token.last30DaysCostUSD,
                        tokens: token.last30DaysTokens,
                        currencyCode: token.currencyCode)))
            }
        }
        return rows + self.balanceRows(for: entry)
    }

    private static func sessionRow(
        token: WidgetSnapshot.TokenUsageSummary,
        entry: WidgetSnapshot.ProviderEntry,
        isProminent: Bool,
        compact: Bool = false) -> WidgetMetricRow
    {
        // "$1.56 · 1.1M tokens" does not fit beside its label on a 127pt tile — the label loses and
        // renders as "T…". Prefer money when known, retaining tokens for unpriced history.
        let value = compact
            ? (token.sessionCostUSD.map { WidgetFormat.currency($0, code: token.currencyCode) }
                ?? token.sessionTokens.map(WidgetFormat.tokenCount)
                ?? WidgetFormat.unavailable)
            : WidgetFormat.costAndTokens(
                cost: token.sessionCostUSD,
                tokens: token.sessionTokens,
                currencyCode: token.currencyCode)
        return WidgetMetricRow(
            id: "session-cost",
            title: token.sessionLabel,
            value: value,
            isProminent: isProminent)
    }

    private static func balanceRows(for entry: WidgetSnapshot.ProviderEntry) -> [WidgetMetricRow] {
        var rows: [WidgetMetricRow] = []
        if let balance = WidgetBalanceFormatter.providerBalance(for: entry) {
            rows.append(WidgetMetricRow(id: "provider-balance", title: balance.title, value: balance.value))
        }
        if let balance = WidgetBalanceFormatter.extraUsageBalance(for: entry) {
            rows.append(WidgetMetricRow(id: "extra-usage", title: balance.title, value: balance.value))
        }
        return rows
    }
}

// MARK: - Headline fallback

struct WidgetFallbackHeroContent: Equatable {
    let value: String
    let caption: String
    let detail: String?
    /// The metric row this headline was built from. The tile drops it from the list below so the
    /// same figure is not printed twice.
    let consumedMetricID: String
}

enum WidgetFallbackHero {
    /// Balance-only and credit-only providers report no quota lanes, so the headline falls back to
    /// the figure those tiles do have instead of leaving the tile blank.
    static func make(for entry: WidgetSnapshot.ProviderEntry) -> WidgetFallbackHeroContent? {
        if let balance = WidgetBalanceFormatter.providerBalance(for: entry) {
            return WidgetFallbackHeroContent(
                value: balance.value,
                caption: balance.title,
                detail: nil,
                consumedMetricID: "provider-balance")
        }
        if let cost = WidgetBalanceFormatter.extraUsageCost(for: entry) {
            return WidgetFallbackHeroContent(
                value: WidgetFormat.currency(cost.used, code: cost.currencyCode),
                caption: W("Extra usage balance"),
                detail: nil,
                consumedMetricID: "extra-usage")
        }
        if let credits = entry.creditsRemaining {
            return WidgetFallbackHeroContent(
                value: WidgetFormat.credits(credits),
                caption: W("Credits left"),
                detail: nil,
                consumedMetricID: "credits")
        }
        guard let token = entry.tokenUsage else { return nil }
        guard let cost = token.sessionCostUSD else {
            return token.sessionTokens.map { tokens in
                WidgetFallbackHeroContent(
                    value: UsageFormatter.tokenCountString(tokens),
                    caption: W("%@ tokens", W(token.sessionLabel)),
                    detail: nil,
                    consumedMetricID: "session-cost")
            }
        }
        return WidgetFallbackHeroContent(
            value: WidgetFormat.currency(cost, code: token.currencyCode),
            caption: token.sessionLabel,
            detail: token.sessionTokens.map(WidgetFormat.tokenCount),
            consumedMetricID: "session-cost")
    }
}

// MARK: - Reference card layout

/// Uses the upstream quota projection; only row order and visual hierarchy change.
struct ReferenceUsageTile<Header: View>: View {
    @Environment(\.widgetUsageShowsUsed) private var showsUsed
    let entry: WidgetSnapshot.ProviderEntry
    let size: WidgetTileSize
    @ViewBuilder let header: () -> Header

    private var lanes: [WidgetTileLane] {
        var rows = WidgetTileLane.lanes(for: self.entry)
        // Provider-specific by design: keep absent Codex/Claude windows visibly unavailable.
        if self.entry.primary == nil, !rows.contains(where: { $0.id == "primary" }) {
            rows.insert(.init(id: "primary", title: "Session", remainingPercent: nil), at: 0)
        }
        if self.entry.secondary == nil, !rows.contains(where: { $0.id == "secondary" }) {
            rows.append(.init(id: "secondary", title: "Weekly", remainingPercent: nil))
        }
        return rows
    }

    var body: some View {
        let rows = self.lanes
        let maximum = self.size == .large ? 3 : 2
        VStack(alignment: .leading, spacing: self.size == .large ? 12 : 7) {
            self.header()
            ForEach(Array(rows.prefix(maximum).enumerated()), id: \.element.id) { index, lane in
                self.quota(lane, index: index)
            }
            if rows.count > maximum {
                Text(W("+%@ more", String(rows.count - maximum)))
                    .font(.system(size: 8)).foregroundStyle(.secondary)
            }
            if self.size == .large {
                WidgetSeparator()
                ReferenceTokenChart(points: self.entry.dailyUsage, color: WidgetColors.color(for: self.entry.provider))
                    .frame(maxHeight: .infinity)
            } else {
                Spacer(minLength: 0)
            }
            if WidgetFreshness.isStale(self.entry.updatedAt) {
                Text("来源数据已过期，请刷新")
                    .font(.system(size: 8)).foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func quota(_ lane: WidgetTileLane, index: Int) -> some View {
        let displayed = WidgetUsageDisplay.percent(fromRemaining: lane.remainingPercent, showUsed: self.showsUsed)
        // Provider-specific by design: the reference separates Codex weekly quota with amber ink.
        let color = self.entry.provider == .codex && index == 1
            ? Color(red: 0.96, green: 0.57, blue: 0.25)
            : WidgetColors.color(for: self.entry.provider)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .bottom, spacing: 5) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(self.title(lane))
                        .font(.system(size: self.size == .small ? 10 : 11, weight: .semibold))
                        .lineLimit(1)
                    if self.size != .small {
                        self.reset(lane)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                Spacer(minLength: 3)
                Text(WidgetFormat.percent(displayed))
                    .font(.system(size: self.size == .small ? 15 : 19, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(QuotaSeverity.isLow(remaining: lane.remainingPercent) ? .red : .primary)
            }
            QuotaBar(
                percent: displayed,
                color: color,
                isLow: QuotaSeverity.isLow(remaining: lane.remainingPercent),
                height: self.size == .small ? 7 : 8)
                .padding(2)
                .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.primary.opacity(0.1), lineWidth: 0.5))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text("\(self.title(lane))，\(self.showsUsed ? "已用" : "剩余") \(WidgetFormat.percent(displayed))"))
    }

    private func title(_ lane: WidgetTileLane) -> String {
        let label: String = switch lane.title {
        case "Session": self.entry.primary?.windowMinutes == 300 ? "5 小时额度" : "会话额度"
        case "Weekly": "每周额度"
        default: W(lane.title)
        }
        return label + (self.showsUsed ? " · 已用" : " · 剩余")
    }

    private func reset(_ lane: WidgetTileLane) -> Text {
        guard lane.remainingPercent != nil else { return Text("暂无额度数据") }
        switch WidgetLaneCopy.reset(resetsAt: lane.resetsAt, resetDescription: lane.resetDescription) {
        case let .date(date): return WidgetDateText.reset(date)
        case let .text(value): return Text(value)
        case nil: return Text("重置时间未提供")
        }
    }
}

struct ReferenceTokenDay: Identifiable {
    let id: String
    let tokens: Int?
}

enum ReferenceTokenHistory {
    /// Seven calendar days ending at the newest source day; gaps remain missing, never zero-filled.
    static func days(_ points: [WidgetSnapshot.DailyUsagePoint]) -> [ReferenceTokenDay] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        let valid = points.filter { point in
            guard let date = formatter.date(from: point.dayKey) else { return false }
            return formatter.string(from: date) == point.dayKey
        }
        guard let last = valid.map(\.dayKey).max(), let end = formatter.date(from: last) else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let lookup = Dictionary(valid.map { ($0.dayKey, $0.totalTokens) }, uniquingKeysWith: { _, latest in latest })
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 6, to: end) else { return nil }
            let key = formatter.string(from: date)
            let raw = lookup[key].flatMap(\.self)
            return ReferenceTokenDay(id: key, tokens: raw.flatMap { $0 >= 0 ? $0 : nil })
        }
    }
}

struct ReferenceTokenChart: View {
    let points: [WidgetSnapshot.DailyUsagePoint]
    let color: Color

    var body: some View {
        let days = ReferenceTokenHistory.days(self.points)
        let peak = max(1, days.compactMap(\.tokens).max() ?? 1)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("7 日用量").font(.system(size: 11, weight: .bold))
                Text(W("Tokens")).font(.system(size: 8)).foregroundStyle(.secondary)
                Spacer()
                Text("每日记录").font(.system(size: 8)).foregroundStyle(.secondary)
            }
            if days.isEmpty {
                Text("暂无历史记录").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        VStack {
                            ForEach(0..<4, id: \.self) { _ in
                                Rectangle().fill(.primary.opacity(0.06)).frame(height: 0.5)
                                Spacer(minLength: 0)
                            }
                        }.padding(.top, 18).padding(.bottom, 17)
                        HStack(alignment: .bottom, spacing: 9) {
                            ForEach(days) { day in
                                VStack(spacing: 5) {
                                    Text(day.tokens.map { UsageFormatter.tokenCountString($0) } ?? "—")
                                        .font(.system(size: 7, weight: .medium))
                                        .foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(self.color.gradient)
                                        .frame(width: self.barWidth(geometry.size.width), height: day.tokens.map {
                                            max(
                                                $0 > 0 ? 3 : 0,
                                                Double($0) / Double(peak) * max(1, geometry.size.height - 37))
                                        } ?? 0)
                                    Text(day.id.suffix(5).replacingOccurrences(of: "-", with: "/"))
                                        .font(.system(size: 7)).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
    }

    private func barWidth(_ width: CGFloat) -> CGFloat {
        min(18, max(4, (width - 54) / 12))
    }
}

// MARK: - Shared row, chart and formatting helpers
//
// Kept in this file (rather than CodexBarWidgetViews.swift) so the app's floating quota card can compile the
// same tile views through Sources/AIMonitorQuotaUI without the widget's App Intents.

struct WidgetUsageRow: Identifiable, Equatable {
    let id: String
    let title: String
    let percentLeft: Double?
    /// Carried through from the row's rate window so tiles can show when the lane frees up; the
    /// snapshot has always had it and the widgets used to drop it.
    var resetsAt: Date?
    var resetDescription: String?

    static func smallWidgetRowLimit(for entry: WidgetSnapshot.ProviderEntry) -> Int? {
        self.widgetRowLimit(for: entry, family: .small)
    }

    static func mediumWidgetRowLimit(for entry: WidgetSnapshot.ProviderEntry) -> Int? {
        self.widgetRowLimit(for: entry, family: .medium)
    }

    private static func widgetRowLimit(
        for entry: WidgetSnapshot.ProviderEntry,
        family: ProviderWidgetFamily) -> Int?
    {
        guard let provider = entry.provider.firstPartyProvider else { return nil }
        return ProviderDescriptorRegistry.descriptor(for: provider).presentation.widgetRowLimit(
            rows: entry.usageRows,
            family: family)
    }

    static func rows(
        for entry: WidgetSnapshot.ProviderEntry,
        limit: Int? = nil,
        applyBindingCap: Bool = true,
        now: Date = Date()) -> [WidgetUsageRow]
    {
        // Provider-specific by design: DeepSeek exposes no quota denominator, so a 100% bar would be misleading.
        guard entry.provider != .deepseek else { return [] }
        let rows: [WidgetUsageRow]
        if let usageRows = entry.usageRows {
            let resolvedSnapshots = usageRows.map { row in
                guard row.window == nil,
                      let window = self.legacyCodexRateWindow(for: row.id, entry: entry)
                else {
                    return row
                }
                return WidgetSnapshot.WidgetUsageRowSnapshot(
                    id: row.id,
                    title: row.title,
                    percentLeft: row.percentLeft,
                    window: window)
            }
            let sourceRows = resolvedSnapshots.map { row in
                // The generic snapshot writer stores only a percentage for the primary/secondary/
                // tertiary slots and leaves their reset on the entry's own windows, so recover it
                // here. Without this the reset caption is present for Codex and absent for every
                // other provider. Resolved reset only — the row keeps its own percentage.
                let reset = row.window ?? self.slotWindow(for: row.id, entry: entry)
                return WidgetUsageRow(
                    id: row.id,
                    title: row.title,
                    percentLeft: row.window?.remainingPercent ?? row.percentLeft,
                    resetsAt: reset?.resetsAt,
                    resetDescription: reset?.resetDescription)
            }
            rows = applyBindingCap ? self.applyingCodexWeeklyCap(
                sourceRows,
                snapshots: resolvedSnapshots,
                provider: entry.provider,
                now: now) : sourceRows
        } else {
            let metadata = entry.provider.firstPartyProvider.flatMap { ProviderDefaults.metadata[$0] }
            var defaultRows = [
                WidgetUsageRow(
                    id: "primary",
                    title: metadata?.sessionLabel ?? "Session",
                    percentLeft: entry.primary?.remainingPercent,
                    resetsAt: entry.primary?.resetsAt,
                    resetDescription: entry.primary?.resetDescription),
                WidgetUsageRow(
                    id: "secondary",
                    title: metadata?.weeklyLabel ?? "Weekly",
                    percentLeft: entry.secondary?.remainingPercent,
                    resetsAt: entry.secondary?.resetsAt,
                    resetDescription: entry.secondary?.resetDescription),
            ]
            if metadata?.supportsOpus == true {
                defaultRows.append(WidgetUsageRow(
                    id: "tertiary",
                    title: metadata?.opusLabel ?? "Opus",
                    percentLeft: entry.tertiary?.remainingPercent,
                    resetsAt: entry.tertiary?.resetsAt,
                    resetDescription: entry.tertiary?.resetDescription))
            }
            rows = defaultRows.filter { $0.percentLeft != nil }
        }
        guard let limit else { return rows }
        // Provider-specific by design: Antigravity medium widgets select one constrained row per model family.
        if entry.provider == .antigravity,
           limit >= 2,
           rows.contains(where: { $0.id.hasPrefix("antigravity-quota-summary-") })
        {
            var selected = AntigravityQuotaFamilyVisibility.KnownFamily.allCases.compactMap { family in
                rows.filter {
                    AntigravityQuotaFamilyVisibility.knownFamily(windowID: $0.id, title: $0.title) == family
                }.min(by: self.isMoreConstrained)
            }
            let selectedIDs = Set(selected.map(\.id))
            let fallbackRows = rows.enumerated()
                .filter { !selectedIDs.contains($0.element.id) }
                .sorted { lhs, rhs in
                    switch (lhs.element.percentLeft, rhs.element.percentLeft) {
                    case let (.some(left), .some(right)):
                        left == right ? lhs.offset < rhs.offset : left < right
                    case (.some, .none):
                        true
                    case (.none, .some):
                        false
                    case (.none, .none):
                        lhs.offset < rhs.offset
                    }
                }
                .map(\.element)
            selected.append(contentsOf: fallbackRows.prefix(max(0, limit - selected.count)))
            return selected
        }
        return Array(rows.prefix(max(0, limit)))
    }

    private static func applyingCodexWeeklyCap(
        _ rows: [WidgetUsageRow],
        snapshots: [WidgetSnapshot.WidgetUsageRowSnapshot],
        provider: ProviderInstanceID,
        now: Date) -> [WidgetUsageRow]
    {
        // Provider-specific by design: Codex weekly exhaustion suppresses its paired legacy session widget row.
        guard provider == .codex,
              let weekly = snapshots.first(where: { $0.id == "weekly" })?.window,
              weekly.remainingPercent <= 0,
              weekly.resetsAt.map({ $0 > now }) ?? true
        else {
            return rows
        }
        return rows.map { row in
            guard row.id == "session" else { return row }
            return WidgetUsageRow(
                id: row.id,
                title: row.title,
                percentLeft: 0,
                resetsAt: weekly.resetsAt,
                resetDescription: weekly.resetDescription)
        }
    }

    /// Reset metadata for the slot IDs the generic snapshot writer emits. Deliberately narrow:
    /// provider-specific row IDs carry their own window when the writer has one.
    static func slotWindow(for rowID: String, entry: WidgetSnapshot.ProviderEntry) -> RateWindow? {
        switch rowID {
        case "primary": entry.primary
        case "secondary": entry.secondary
        case "tertiary": entry.tertiary
        default: nil
        }
    }

    private static func legacyCodexRateWindow(
        for rowID: String,
        entry: WidgetSnapshot.ProviderEntry) -> RateWindow?
    {
        // Provider-specific by design: old Codex timelines reconstruct session/weekly windows by duration.
        guard entry.provider == .codex else { return nil }
        let candidates = [(entry.primary, "session"), (entry.secondary, "weekly")]
        for (window, fallbackID) in candidates {
            guard let window else { continue }
            let classifiedID = switch window.windowMinutes {
            case 300: "session"
            case 10080: "weekly"
            default: fallbackID
            }
            if classifiedID == rowID {
                return window
            }
        }
        return nil
    }

    static func compactTokenUsage(
        for entry: WidgetSnapshot.ProviderEntry) -> WidgetSnapshot.TokenUsageSummary?
    {
        guard self.rows(for: entry).isEmpty,
              entry.codeReviewRemainingPercent == nil
        else {
            return nil
        }
        return entry.tokenUsage
    }

    private static func isMoreConstrained(_ lhs: WidgetUsageRow, than rhs: WidgetUsageRow) -> Bool {
        switch (lhs.percentLeft, rhs.percentLeft) {
        case let (.some(left), .some(right)):
            left < right
        case (.some, .none):
            true
        case (.none, .some):
            false
        case (.none, .none):
            false
        }
    }
}

enum WidgetUsageDisplay {
    static func percent(fromRemaining remaining: Double?, showUsed: Bool) -> Double? {
        guard let remaining else { return nil }
        let clamped = max(0, min(100, remaining))
        return showUsed ? 100 - clamped : clamped
    }
}

struct UsageHistoryChart: View {
    let points: [WidgetSnapshot.DailyUsagePoint]
    let color: Color
    let currencyCode: String?

    var body: some View {
        let isCostMode = UsageHistoryChartMode.isCostMode(self.points)
        let values = self.points.map { point -> Double in
            isCostMode ? (point.costUSD ?? 0) : Double(point.totalTokens ?? 0)
        }
        let scale = UsageChartScale(values: values)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(UsageHistoryChartCopy.title(dayCount: self.points.count))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let peak = UsageHistoryChartCopy.peak(
                    maximum: scale.maximum,
                    isCostMode: isCostMode,
                    currencyCode: self.currencyCode)
                {
                    Text(peak)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .allowsTightening(true)
                }
            }
            GeometryReader { geometry in
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(values.indices, id: \.self) { index in
                        let fraction = scale.fraction(for: values[index])
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(self.color.gradient)
                            .frame(maxWidth: .infinity)
                            .frame(height: max(fraction > 0 ? 2 : 0, CGFloat(fraction) * geometry.size.height))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(maxHeight: .infinity)
            Rectangle()
                .fill(Color.primary.opacity(WidgetLayout.separatorOpacity))
                .frame(height: 1)
            if let range = UsageHistoryChartCopy.range(points: self.points) {
                HStack(spacing: 4) {
                    Text(range.start)
                    Spacer(minLength: 4)
                    Text(range.end)
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            }
        }
    }
}

enum UsageHistoryChartCopy {
    static func title(dayCount: Int) -> String {
        dayCount > 0 ? W("Last %d days", dayCount) : W("Daily usage")
    }

    static func peak(maximum: Double, isCostMode: Bool, currencyCode: String?) -> String? {
        guard maximum > 0 else { return nil }
        if isCostMode, let currencyCode {
            return W(
                "Peak %@",
                String(describing: UsageFormatter.compactCurrencyString(maximum, currencyCode: currencyCode)))
        }
        guard !isCostMode else { return nil }
        return W("Peak %@", String(describing: UsageFormatter.tokenCountString(Int(maximum))))
    }

    static func range(points: [WidgetSnapshot.DailyUsagePoint]) -> (start: String, end: String)? {
        guard let first = points.first?.dayKey,
              let last = points.last?.dayKey,
              let start = WidgetFormat.dayLabel(first),
              let end = WidgetFormat.dayLabel(last),
              start != end
        else { return nil }
        return (start, end)
    }
}

enum UsageHistoryChartMode {
    static func isCostMode(_ points: [WidgetSnapshot.DailyUsagePoint]) -> Bool {
        !points.isEmpty && points.allSatisfy { $0.costUSD != nil }
    }
}

enum WidgetColors {
    static func color(for instanceID: ProviderInstanceID) -> Color {
        guard let provider = instanceID.firstPartyProvider else { return .secondary }
        // The widget cannot read ~/.codexbar/config.json, so it resolves the user override from the
        // copy the app mirrors into the App Group.
        if ProviderAccentColors.sharedOverride(for: instanceID) == nil {
            if provider == .codex { return Color(red: 0.68, green: 0.53, blue: 0.94) }
            if provider == .claude { return Color(red: 0.93, green: 0.57, blue: 0.41) }
        }
        let color = ProviderAccentColors.sharedOverride(for: instanceID)
            ?? ProviderDescriptorRegistry.descriptor(for: provider).branding.widgetColor
        return Color(red: color.red, green: color.green, blue: color.blue)
    }
}

struct WidgetBalanceLine: Equatable {
    let title: String
    let value: String
}

enum WidgetBalanceFormatter {
    static func providerBalance(for entry: WidgetSnapshot.ProviderEntry) -> WidgetBalanceLine? {
        // Provider-specific by design: these providers publish their widget value through the balance-text field.
        guard entry.provider == .deepseek || entry.provider == .openrouter,
              let value = entry.balanceText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else { return nil }
        return WidgetBalanceLine(title: "Balance", value: value)
    }

    static func extraUsageCost(for entry: WidgetSnapshot.ProviderEntry) -> ProviderCostSnapshot? {
        // Provider-specific by design: Devin encodes its extra-usage balance as a named provider-cost period.
        guard entry.provider == .devin,
              let cost = entry.providerCost,
              cost.period == "Extra usage balance"
        else { return nil }
        return cost
    }

    static func extraUsageBalance(for entry: WidgetSnapshot.ProviderEntry) -> WidgetBalanceLine? {
        guard let cost = self.extraUsageCost(for: entry) else { return nil }
        return WidgetBalanceLine(
            title: "Extra usage",
            value: W("%@: %@", W("Balance"), WidgetFormat.currency(cost.used, code: cost.currencyCode)))
    }
}

enum WidgetFormat {
    /// Shown when a provider does not report a figure at all.
    static let unavailable = "—"

    static func percent(_ value: Double?) -> String {
        guard let value else { return self.unavailable }
        return String(format: "%.0f%%", value)
    }

    static func credits(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    static func costAndTokens(cost: Double?, tokens: Int?, currencyCode: String = "USD") -> String {
        let costText = cost.map { self.currency($0, code: currencyCode) } ?? self.unavailable
        if let tokens {
            return "\(costText) · \(self.tokenCount(tokens))"
        }
        return costText
    }

    static func currency(_ value: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(code) \(String(format: "%.2f", value))"
    }

    static func tokenCount(_ value: Int) -> String {
        "\(UsageFormatter.tokenCountString(value)) tokens"
    }

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dayLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter
    }()

    /// "2026-08-12" to "Aug 12". Returns nil for keys the chart cannot date.
    static func dayLabel(_ dayKey: String) -> String? {
        guard let date = self.dayKeyFormatter.date(from: dayKey) else { return nil }
        return self.dayLabelFormatter.string(from: date)
    }

    /// Suffixes the title with the token snapshot's own age once it lags the entry's
    /// freshness signal past `TokenUsageSummary.staleLagThreshold`.
    static func tokenRowTitle(
        _ base: String,
        summary: WidgetSnapshot.TokenUsageSummary?,
        entryUpdatedAt: Date) -> Text
    {
        guard let summary, summary.isStale(comparedTo: entryUpdatedAt), let updatedAt = summary.updatedAt else {
            return Text(W(base))
        }
        return Text("\(W(base)) · \(WidgetDateText.offset(updatedAt))")
    }
}
