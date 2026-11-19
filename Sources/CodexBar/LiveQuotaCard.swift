import AIMonitorQuotaUI
import AppKit
import CodexBarCore
import Observation
import SwiftUI

extension Notification.Name {
    /// Posted after the app publishes a new widget snapshot, so the floating quota card redraws at once.
    static let aiMonitorWidgetSnapshotPublished = Notification.Name("aiMonitorWidgetSnapshotPublished")
}

/// State for the floating quota card: the widget snapshot the app just published and the selected provider.
@MainActor
@Observable
final class LiveQuotaCardModel {
    var snapshot: WidgetSnapshot?
    var provider: UsageProvider
    /// Bumped every minute so "N 分钟" freshness text keeps counting between snapshots.
    var tick = Date()

    private let defaults: UserDefaults
    private let load: (UsageProvider) -> WidgetSnapshot?
    static let providerKey = "aiMonitorQuotaCardProvider"

    init(
        defaults: UserDefaults = .standard,
        load: @escaping (UsageProvider) -> WidgetSnapshot? = { WidgetSnapshotStore.load(provider: $0) })
    {
        self.defaults = defaults
        self.load = load
        self.provider = defaults.string(forKey: Self.providerKey).flatMap(UsageProvider.init(rawValue:)) ?? .codex
    }

    var providers: [UsageProvider] {
        self.snapshot.map(AIMonitorQuotaCardView.providers(in:)) ?? [self.provider]
    }

    func reload() {
        self.snapshot = self.load(self.provider)
        if let snapshot, !AIMonitorQuotaCardView.providers(in: snapshot).contains(self.provider),
           let first = AIMonitorQuotaCardView.providers(in: snapshot).first
        {
            self.select(first)
        }
        self.tick = Date()
    }

    func select(_ provider: UsageProvider) {
        self.provider = provider
        self.defaults.set(provider.rawValue, forKey: Self.providerKey)
        self.snapshot = self.load(provider)
    }
}

/// Floating desktop card that shows the usage widget's large tile. It reads the same snapshot the widget
/// reads, but redraws as soon as the app publishes new data instead of waiting for WidgetKit scheduling.
@MainActor
final class LiveQuotaCardController: NSObject, NSWindowDelegate {
    static let shared = LiveQuotaCardController()
    static let enabledKey = "aiMonitorQuotaCardEnabled"
    static let originKey = "aiMonitorQuotaCardOrigin"
    static let cardSize = NSSize(width: 360, height: 372)

    let model: LiveQuotaCardModel
    private let defaults: UserDefaults
    private var panel: NSPanel?
    private var timer: Timer?
    private var observing = false

    init(defaults: UserDefaults = .standard, model: LiveQuotaCardModel? = nil) {
        self.defaults = defaults
        self.model = model ?? LiveQuotaCardModel(defaults: defaults)
        super.init()
    }

    /// Off by default for existing installs would hide the new feature; on by default matches the Mac card.
    var isEnabled: Bool {
        self.defaults.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    var isVisible: Bool { self.panel?.isVisible ?? false }

    func start() {
        self.observe()
        if self.isEnabled { self.show() }
    }

    func setEnabled(_ enabled: Bool) {
        self.defaults.set(enabled, forKey: Self.enabledKey)
        if enabled { self.show() } else { self.hide() }
    }

    func show() {
        if self.panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(origin: NSPoint(x: 80, y: 300), size: Self.cardSize),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false)
            panel.title = "AI Monitor · 额度"
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.isMovableByWindowBackground = true
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            panel.delegate = self
            if let origin = self.savedOrigin() { panel.setFrameOrigin(origin) }
            panel.contentView = NSHostingView(rootView: LiveQuotaCardRoot(
                model: self.model,
                hide: { [weak self] in self?.setEnabled(false) }))
            self.panel = panel
        }
        self.keepOnScreen()
        self.model.reload()
        self.panel?.orderFrontRegardless()
        self.startTimer()
    }

    func hide() {
        self.panel?.orderOut(nil)
        self.timer?.invalidate()
        self.timer = nil
    }

    func stop() {
        self.timer?.invalidate()
        self.timer = nil
        if self.observing {
            NotificationCenter.default.removeObserver(self)
            self.observing = false
        }
    }

    private func startTimer() {
        guard self.timer == nil else { return }
        // A cheap fallback re-read once a minute keeps freshness text current and recovers a missed post.
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.reload() }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func observe() {
        guard !self.observing else { return }
        self.observing = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(self.snapshotPublished),
            name: .aiMonitorWidgetSnapshotPublished, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(self.screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc private func snapshotPublished() {
        guard self.isVisible else { return }
        self.model.reload()
    }

    @objc private func screensChanged() { self.keepOnScreen() }

    /// Returns a card that is mostly off every screen to the top-right of the primary display.
    func keepOnScreen() {
        guard let panel = self.panel else { return }
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let frame = panel.frame
        let visibleArea = screens.reduce(CGFloat(0)) { area, screen in
            let overlap = screen.visibleFrame.intersection(frame)
            return area + (overlap.isNull ? 0 : overlap.width * overlap.height)
        }
        guard visibleArea < frame.width * frame.height * 0.5, let screen = screens.first else { return }
        panel.setFrameOrigin(NSPoint(
            x: screen.visibleFrame.maxX - frame.width - 24,
            y: screen.visibleFrame.maxY - frame.height - 24))
        self.saveOrigin()
    }

    private func savedOrigin() -> NSPoint? {
        guard let values = self.defaults.array(forKey: Self.originKey) as? [Double], values.count == 2 else {
            return nil
        }
        return NSPoint(x: values[0], y: values[1])
    }

    private func saveOrigin() {
        guard let origin = self.panel?.frame.origin else { return }
        self.defaults.set([Double(origin.x), Double(origin.y)], forKey: Self.originKey)
    }

    func windowDidMove(_ notification: Notification) {
        self.saveOrigin()
    }
}

private struct LiveQuotaCardRoot: View {
    let model: LiveQuotaCardModel
    let hide: () -> Void

    var body: some View {
        Group {
            if let snapshot = self.model.snapshot {
                AIMonitorQuotaCardView(
                    snapshot: snapshot,
                    provider: self.model.provider,
                    providers: self.model.providers,
                    select: { self.model.select($0) })
                    .id(self.model.tick)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: "AI Monitor").font(.system(size: 13, weight: .semibold))
                    Text(verbatim: "正在读取额度…").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(16)
        .background(AIMonitorQuotaCardBackground())
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .environment(\.colorScheme, .dark)
        .contextMenu {
            Button(action: self.hide) { Text(verbatim: "隐藏额度卡片（可在设置 › 通用 中重新打开）") }
        }
    }
}
