import CodexBarCore
import SwiftUI

/// The usage widget's large tile, hosted inside the app for the floating quota card.
///
/// It renders the exact widget views (`UsageTile`) from the shared sources, so the card and the
/// desktop widget always look the same. Paging uses closures instead of the widget's App Intents.
public struct AIMonitorQuotaCardView: View {
    let snapshot: WidgetSnapshot
    let provider: UsageProvider
    let providers: [UsageProvider]
    let select: (UsageProvider) -> Void

    public init(
        snapshot: WidgetSnapshot,
        provider: UsageProvider,
        providers: [UsageProvider],
        select: @escaping (UsageProvider) -> Void)
    {
        self.snapshot = snapshot
        self.provider = provider
        self.providers = providers
        self.select = select
    }

    /// Providers the card can page through: the reference-styled coding services present in the snapshot.
    public static func providers(in snapshot: WidgetSnapshot) -> [UsageProvider] {
        let enabled = snapshot.enabledProviders.isEmpty ? snapshot.entries.map(\.provider) : snapshot.enabledProviders
        var seen = Set<UsageProvider>()
        let providers = enabled.compactMap(\.firstPartyProvider).filter { provider in
            (provider == .codex || provider == .claude) && seen.insert(provider).inserted
        }
        return providers.isEmpty ? [.codex] : providers
    }

    public var body: some View {
        let entry = self.snapshot.entries.first { $0.provider == self.provider.instanceID }
        Group {
            if let entry {
                UsageTile(entry: entry, size: .large) {
                    QuotaCardHeader(
                        providers: self.providers,
                        selected: self.provider,
                        updatedAt: entry.updatedAt,
                        select: self.select)
                }
            } else {
                VStack(alignment: .leading, spacing: WidgetLayout.sectionSpacing) {
                    QuotaCardHeader(
                        providers: self.providers,
                        selected: self.provider,
                        updatedAt: Date(),
                        select: self.select)
                    WidgetEmptyState(message: W("No data"))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.widgetUsageShowsUsed, self.snapshot.usageBarsShowUsed)
    }
}

/// The widget's gradient, for the card's own window background.
public struct AIMonitorQuotaCardBackground: View {
    public init() {}
    public var body: some View { StudioWidgetBackground() }
}

/// Mirrors the widget's `ProviderPagerHeader` (large size) with closure-driven paging.
private struct QuotaCardHeader: View {
    let providers: [UsageProvider]
    let selected: UsageProvider
    let updatedAt: Date
    let select: (UsageProvider) -> Void

    var body: some View {
        let size = WidgetTileSize.large
        let pager = ProviderPager.make(providers: self.providers, selected: self.selected)
        HStack(spacing: 7) {
            ProviderMark(provider: self.selected, isSelected: true, size: size.markSize)
            Text(ProviderTitle.text(for: self.selected, size: size))
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .layoutPriority(2)
            FreshnessLabel(updatedAt: self.updatedAt)
                .layoutPriority(0)
            Spacer(minLength: 4)
            if let pager, pager.isPageable {
                HStack(spacing: 3) {
                    self.button(pager.previous, symbol: "chevron.left", side: size.markSize - 2)
                    Text(pager.positionText)
                        .font(.caption2.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                    self.button(pager.next, symbol: "chevron.right", side: size.markSize - 2)
                }
                .layoutPriority(1)
            }
        }
    }

    private func button(_ provider: UsageProvider, symbol: String, side: CGFloat) -> some View {
        Button { self.select(provider) } label: {
            Image(systemName: symbol)
                .font(.system(size: side * 0.44, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: side, height: side)
                .background(
                    RoundedRectangle(cornerRadius: side * 0.3, style: .continuous)
                        .fill(Color.primary.opacity(0.07)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
