import CodexBarCore
import SwiftUI
import WidgetKit

extension WidgetTileSize {
    init(family: WidgetFamily) {
        switch family {
        case .systemSmall: self = .small
        case .systemMedium: self = .medium
        default: self = .large
        }
    }
}

struct CodexBarUsageWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CodexBarWidgetEntry

    var body: some View {
        let providerEntry = self.entry.snapshot.entries.first { $0.provider == self.entry.provider.instanceID }
        Group {
            if let providerEntry {
                UsageTile(entry: providerEntry, size: WidgetTileSize(family: self.family)) {
                    TileHeader(
                        provider: providerEntry.provider,
                        updatedAt: providerEntry.updatedAt,
                        size: WidgetTileSize(family: self.family))
                }
            } else {
                WidgetEmptyState(message: WidgetEmptyStateCopy.message(
                    provider: self.entry.provider,
                    snapshot: self.entry.snapshot))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(StudioWidgetSurface())
        .environment(\.widgetUsageShowsUsed, self.entry.snapshot.usageBarsShowUsed)
    }
}

struct CodexBarHistoryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CodexBarWidgetEntry

    var body: some View {
        let providerEntry = self.entry.snapshot.entries.first { $0.provider == self.entry.provider.instanceID }
        Group {
            if let providerEntry {
                HistoryView(entry: providerEntry, isLarge: self.family == .systemLarge)
            } else {
                WidgetEmptyState(message: WidgetEmptyStateCopy.message(
                    provider: self.entry.provider,
                    snapshot: self.entry.snapshot))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(StudioWidgetSurface())
    }
}

struct CodexBarCompactWidgetView: View {
    let entry: CodexBarCompactEntry

    var body: some View {
        let providerEntry = self.entry.snapshot.entries.first { $0.provider == self.entry.provider.instanceID }
        Group {
            if let providerEntry {
                CompactMetricView(entry: providerEntry, metric: self.entry.metric)
            } else {
                WidgetEmptyState(message: WidgetEmptyStateCopy.message(
                    provider: self.entry.provider,
                    snapshot: self.entry.snapshot))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(StudioWidgetSurface())
    }
}

struct CodexBarSwitcherWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CodexBarSwitcherEntry

    var body: some View {
        let providerEntry = self.entry.snapshot.entries.first { $0.provider == self.entry.provider.instanceID }
        let size = WidgetTileSize(family: self.family)
        Group {
            if let providerEntry {
                UsageTile(entry: providerEntry, size: size) {
                    ProviderPagerHeader(
                        providers: self.entry.availableProviders,
                        selected: self.entry.provider,
                        updatedAt: providerEntry.updatedAt,
                        size: size)
                }
            } else {
                VStack(alignment: .leading, spacing: WidgetLayout.sectionSpacing) {
                    ProviderPagerHeader(
                        providers: self.entry.availableProviders,
                        selected: self.entry.provider,
                        updatedAt: Date(),
                        size: size)
                    WidgetEmptyState(message: WidgetEmptyStateCopy.switcherMessage(
                        provider: self.entry.provider,
                        snapshot: self.entry.snapshot))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(StudioWidgetSurface())
        .environment(\.widgetUsageShowsUsed, self.entry.snapshot.usageBarsShowUsed)
    }
}

private struct CompactMetricView: View {
    let entry: WidgetSnapshot.ProviderEntry
    let metric: CompactMetric

    var body: some View {
        let display = CompactMetricFormatter.display(for: self.entry, metric: self.metric)
        VStack(alignment: .leading, spacing: WidgetLayout.sectionSpacing) {
            TileHeader(provider: self.entry.provider, updatedAt: self.entry.updatedAt, size: .small)
            Spacer(minLength: 0)
            // This tile carries a single figure, so it gets the full width and sits centred rather
            // than clinging to the header with dead space underneath.
            HeroBlock(
                value: display.value,
                caption: WidgetFormat.tokenRowTitle(
                    display.label,
                    summary: self.metric == .credits ? nil : self.entry.tokenUsage,
                    entryUpdatedAt: self.entry.updatedAt),
                detail: (display.detail ?? CompactMetricFormatter.unavailableDetail(
                    value: display.value,
                    entry: self.entry))
                    .map { Text($0) },
                numberSize: WidgetLayout.compactMetricNumberSize)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct CompactMetricDisplay: Equatable {
    let value: String
    let label: String
    let detail: String?
}

enum CompactMetricFormatter {
    static func display(for entry: WidgetSnapshot.ProviderEntry, metric: CompactMetric) -> CompactMetricDisplay {
        switch metric {
        case .credits:
            if let cost = WidgetBalanceFormatter.extraUsageCost(for: entry) {
                return CompactMetricDisplay(
                    value: WidgetFormat.currency(cost.used, code: cost.currencyCode),
                    label: W("Extra usage balance"),
                    detail: nil)
            }
            if let balance = WidgetBalanceFormatter.providerBalance(for: entry) {
                return CompactMetricDisplay(value: balance.value, label: balance.title, detail: nil)
            }
            let value = entry.creditsRemaining.map(WidgetFormat.credits) ?? "—"
            return CompactMetricDisplay(value: value, label: W("Credits left"), detail: nil)
        case .todayCost:
            let value = entry.tokenUsage.map { token in
                token.sessionCostUSD.map { WidgetFormat.currency($0, code: token.currencyCode) } ?? "—"
            } ?? "—"
            let detail = entry.tokenUsage?.sessionTokens.map(WidgetFormat.tokenCount)
            let label = entry.tokenUsage.map {
                Self.costMetricLabel($0.sessionLabel, provider: entry.provider)
            } ?? W("Today cost")
            return CompactMetricDisplay(value: value, label: label, detail: detail)
        case .last30DaysCost:
            let value = entry.tokenUsage.map { token in
                token.last30DaysCostUSD.map { WidgetFormat.currency($0, code: token.currencyCode) } ?? "—"
            } ?? "—"
            let detail = entry.tokenUsage?.last30DaysTokens.map(WidgetFormat.tokenCount)
            let label = entry.tokenUsage.map {
                Self.costMetricLabel($0.last30DaysLabel, provider: entry.provider)
            } ?? W("30d cost")
            return CompactMetricDisplay(value: value, label: label, detail: detail)
        }
    }

    /// A tile pinned to a metric its provider never reports would otherwise be a blank square. Name
    /// the provider so the reason is obvious and the widget can be reconfigured.
    static func unavailableDetail(value: String, entry: WidgetSnapshot.ProviderEntry) -> String? {
        guard value == WidgetFormat.unavailable else { return nil }
        let name = entry.provider.firstPartyProvider
            .flatMap { ProviderDefaults.metadata[$0]?.displayName }
            ?? entry.provider.rawValue.capitalized
        return W("Not reported by %@", String(describing: name))
    }

    static func costMetricLabel(_ label: String, provider: ProviderInstanceID) -> String {
        // Provider-specific by design: old Codex widget timelines lack the API-estimate billing disclaimer.
        guard provider == .codex else { return W("%@ cost", self.localizedPeriod(label)) }
        // Snapshots written by older app versions contain the English estimate suffix.
        // Keep its meaning while translating the period and billing disclaimer together.
        let suffix = " API est. · not billed"
        if label.hasSuffix(suffix) {
            return W("%@ API est. · not billed", self.localizedPeriod(String(label.dropLast(suffix.count))))
        }
        let shortSuffix = " API est."
        if label.hasSuffix(shortSuffix) {
            return W("%@ %@", self.localizedPeriod(String(label.dropLast(shortSuffix.count))), W("API est."))
        }
        guard !label.contains(W("API est.")) else { return label }
        return W("%@ API est. · not billed", self.localizedPeriod(label))
    }

    private static func localizedPeriod(_ label: String) -> String {
        if label.hasSuffix("d"), let days = Int(label.dropLast()) {
            return W("%dd", days)
        }
        return W(label)
    }
}

enum WidgetEmptyStateCopy {
    static func message(provider: UsageProvider, snapshot: WidgetSnapshot) -> String {
        guard !snapshot.enabledProviders.isEmpty else {
            return W("Enable a provider in CodexBar → Settings → Providers.")
        }
        guard !snapshot.enabledProviders.contains(provider.instanceID) else { return W("No data") }
        let name = ProviderDefaults.metadata[provider]?.displayName ?? provider.rawValue.capitalized
        return W("%@ is unavailable. Edit the widget to choose a provider.", name)
    }

    static func switcherMessage(provider: UsageProvider, snapshot: WidgetSnapshot) -> String {
        snapshot.enabledProviders.contains(provider.instanceID)
            ? W("No data") : W("Enable a provider in CodexBar → Settings → Providers.")
    }
}

/// Header for the switcher widget: the selected provider spelled out in full, plus a pager to
/// move through the others.
///
/// A widget cannot open a menu or a picker, so paging is the control that fits: it costs one line
/// instead of a whole chip row, and the provider whose numbers are on screen is always named.
struct ProviderPagerHeader: View {
    let providers: [UsageProvider]
    let selected: UsageProvider
    let updatedAt: Date
    let size: WidgetTileSize

    var body: some View {
        let pager = ProviderPager.make(providers: self.providers, selected: self.selected)
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                ProviderMark(provider: self.selected, isSelected: true, size: self.size.markSize)
                Text(ProviderTitle.text(for: self.selected, size: self.size))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .layoutPriority(2)
                if self.size != .small {
                    FreshnessLabel(updatedAt: self.updatedAt)
                        .layoutPriority(0)
                }
                Spacer(minLength: 4)
                if let pager, pager.isPageable {
                    ProviderPagerControls(pager: pager, size: self.size)
                        .layoutPriority(1)
                }
            }
            if self.size == .small {
                FreshnessLabel(updatedAt: self.updatedAt)
            }
        }
    }
}

private struct ProviderPagerControls: View {
    let pager: ProviderPager
    let size: WidgetTileSize

    var body: some View {
        HStack(spacing: 3) {
            if self.size != .small {
                ProviderPageButton(provider: self.pager.previous, symbol: "chevron.left", size: self.size)
                Text(self.pager.positionText)
                    .font(.caption2.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            ProviderPageButton(provider: self.pager.next, symbol: "chevron.right", size: self.size)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(W("Provider %@", String(describing: self.pager.positionText))))
    }
}

private struct ProviderPageButton: View {
    @Environment(\.widgetProviderSelectionOverride) private var selectionOverride
    let provider: UsageProvider
    let symbol: String
    let size: WidgetTileSize

    var body: some View {
        if let choice = ProviderChoice(provider: self.provider) {
            Group {
                if let selectionOverride {
                    Button { selectionOverride(self.provider) } label: { self.glyph }
                } else {
                    Button(intent: SwitchWidgetProviderIntent(provider: choice)) { self.glyph }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(ProviderPageButtonLabel.text(for: self.provider)))
        } else {
            self.glyph.opacity(0.4)
        }
    }

    private var glyph: some View {
        let side = self.size.markSize - 2
        return Image(systemName: self.symbol)
            .font(.system(size: side * 0.44, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: side, height: side)
            .background(
                RoundedRectangle(cornerRadius: side * 0.3, style: .continuous)
                    .fill(Color.primary.opacity(0.07)))
    }
}

enum ProviderPageButtonLabel {
    static func text(for provider: UsageProvider) -> String {
        let name = ProviderDefaults.metadata[provider]?.displayName ?? provider.rawValue.capitalized
        return W("Switch to %@", String(describing: name))
    }
}

private struct HistoryView: View {
    let entry: WidgetSnapshot.ProviderEntry
    let isLarge: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetLayout.sectionSpacing) {
            TileHeader(
                provider: self.entry.provider,
                updatedAt: self.entry.updatedAt,
                size: self.isLarge ? .large : .medium)
            UsageHistoryChart(
                points: self.entry.dailyUsage,
                color: WidgetColors.color(for: self.entry.provider),
                currencyCode: self.entry.tokenUsage?.currencyCode)
                .frame(minHeight: self.isLarge ? 110 : 58, maxHeight: .infinity)
            if let token = entry.tokenUsage {
                VStack(alignment: .leading, spacing: 4) {
                    WidgetSeparator().padding(.bottom, 2)
                    MetricLine(
                        title: WidgetFormat.tokenRowTitle(
                            token.sessionLabel,
                            summary: token,
                            entryUpdatedAt: self.entry.updatedAt),
                        value: WidgetFormat.costAndTokens(
                            cost: token.sessionCostUSD,
                            tokens: token.sessionTokens,
                            currencyCode: token.currencyCode),
                        isProminent: true)
                    MetricLine(
                        title: WidgetFormat.tokenRowTitle(
                            token.last30DaysLabel,
                            summary: token,
                            entryUpdatedAt: self.entry.updatedAt),
                        value: WidgetFormat.costAndTokens(
                            cost: token.last30DaysCostUSD,
                            tokens: token.last30DaysTokens,
                            currencyCode: token.currencyCode))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Daily cost or token history. The chart now labels its peak and its date range, and the most
/// recent day is drawn at full strength so "where am I today" is answerable at a glance.
