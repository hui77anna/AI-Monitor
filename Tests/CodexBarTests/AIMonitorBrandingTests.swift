import Testing
@testable import CodexBar

struct AIMonitorBrandingTests {
    @Test func `display branding preserves technical paths and copyright`() {
        #expect(aiMonitorDisplayText(key: "About CodexBar", value: "关于 CodexBar") == "关于 AI Monitor")
        #expect(aiMonitorDisplayText(key: "title", value: "CodexBar Settings") == "AI Monitor Settings")
        #expect(aiMonitorDisplayText(key: "copyright", value: "CodexBar MIT") == "CodexBar MIT")
        #expect(aiMonitorDisplayText(key: "path", value: "/Applications/CodexBar.app") == "/Applications/CodexBar.app")
    }
}
