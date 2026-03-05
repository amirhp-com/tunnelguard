import Foundation
import Combine

// MARK: - Route Rule Model
struct RouteRule: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var domain: String
    var resolvedIPs: [String] = []
    var isEnabled: Bool = true
    var lastResolved: Date?
    var notes: String = ""

    var displayDomain: String { domain.isEmpty ? "Unknown" : domain }
    var statusLabel: String { isEnabled ? "Active" : "Paused" }
}

// MARK: - App Settings
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var gatewayMode: GatewayMode = .automatic
    @Published var manualGatewayIP: String = ""
    @Published var detectedGatewayIP: String = ""
    @Published var runOnStartup: Bool = false
    @Published var applyOnLaunch: Bool = true
    @Published var dnsServer: String = "8.8.8.8"
    @Published var showInDock: Bool = true
    @Published var themeMode: ThemeMode = .system

    enum GatewayMode: String, CaseIterable, Codable {
        case automatic = "Automatic"
        case manual = "Manual"
    }

    enum ThemeMode: String, CaseIterable, Codable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
    }

    var effectiveGateway: String {
        gatewayMode == .automatic ? detectedGatewayIP : manualGatewayIP
    }

    private let settingsKey = "TunnelGuardSettings"

    init() {
        load()
        detectGateway()
    }

    func detectGateway() {
        DispatchQueue.global(qos: .background).async {
            let result = shell("netstat -nr | grep default | grep -v ':' | head -1 | awk '{print $2}'")
            let gateway = result.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                self.detectedGatewayIP = gateway.isEmpty ? "192.168.1.1" : gateway
            }
        }
    }

    func save() {
        let data: [String: Any] = [
            "gatewayMode": gatewayMode.rawValue,
            "manualGatewayIP": manualGatewayIP,
            "runOnStartup": runOnStartup,
            "applyOnLaunch": applyOnLaunch,
            "dnsServer": dnsServer,
            "showInDock": showInDock,
            "themeMode": themeMode.rawValue
        ]
        UserDefaults.standard.set(data, forKey: settingsKey)
        updateLoginItem()

        // Apply dock visibility immediately
        NotificationCenter.default.post(
            name: .dockVisibilityChanged,
            object: nil,
            userInfo: ["show": showInDock]
        )
        // Signal UI to show a save confirmation toast
        NotificationCenter.default.post(name: .settingsSaved, object: nil)
    }

    func load() {
        guard let data = UserDefaults.standard.dictionary(forKey: settingsKey) else { return }
        if let gm = data["gatewayMode"] as? String { gatewayMode = GatewayMode(rawValue: gm) ?? .automatic }
        manualGatewayIP = data["manualGatewayIP"] as? String ?? ""
        runOnStartup = data["runOnStartup"] as? Bool ?? false
        applyOnLaunch = data["applyOnLaunch"] as? Bool ?? true
        dnsServer = data["dnsServer"] as? String ?? "8.8.8.8"
        showInDock = data["showInDock"] as? Bool ?? true
        if let tm = data["themeMode"] as? String { themeMode = ThemeMode(rawValue: tm) ?? .system }
    }

    private func updateLoginItem() {
        // LaunchAgent plist management for startup
        let plistPath = "\(NSHomeDirectory())/Library/LaunchAgents/com.amirhpcom.tunnelguard.plist"
        if runOnStartup {
            let bundlePath = Bundle.main.bundlePath
            let plist = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.amirhpcom.tunnelguard</string>
    <key>ProgramArguments</key>
    <array>
        <string>\(bundlePath)/Contents/MacOS/TunnelGuard</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
"""
            try? plist.write(toFile: plistPath, atomically: true, encoding: .utf8)
            shell("launchctl load \(plistPath)")
        } else {
            shell("launchctl unload \(plistPath) 2>/dev/null || true")
            try? FileManager.default.removeItem(atPath: plistPath)
        }
    }
}

// MARK: - Route Manager
class RouteManager: ObservableObject {
    static let shared = RouteManager()

    @Published var rules: [RouteRule] = []
    @Published var isApplying: Bool = false
    @Published var lastActionLog: [String] = []
    @Published var activeRulesCount: Int = 0

    private let rulesKey = "TunnelGuardRules"

    func loadRules() {
        if let data = UserDefaults.standard.data(forKey: rulesKey),
           let decoded = try? JSONDecoder().decode([RouteRule].self, from: data) {
            rules = decoded
            updateCount()
        }
    }

    func saveRules() {
        if let encoded = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(encoded, forKey: rulesKey)
        }
        updateCount()
    }

    private func updateCount() {
        activeRulesCount = rules.filter { $0.isEnabled }.count
    }

    func addRule(domain: String, notes: String = "") async -> RouteRule? {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        guard !trimmed.isEmpty else { return nil }

        var rule = RouteRule(domain: trimmed, notes: notes)
        let ips = await resolveIPs(for: trimmed)
        rule.resolvedIPs = ips
        rule.lastResolved = Date()

        await MainActor.run {
            rules.append(rule)
            saveRules()
            log("Added rule for \(trimmed) → \(ips.joined(separator: ", "))")
        }
        return rule
    }

    func removeRule(_ rule: RouteRule) {
        removeRoutes(for: rule)
        rules.removeAll { $0.id == rule.id }
        saveRules()
        log("Removed rule for \(rule.domain)")
    }

    func toggleRule(_ rule: RouteRule) {
        guard let idx = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[idx].isEnabled.toggle()
        if rules[idx].isEnabled {
            applyRoutes(for: rules[idx])
        } else {
            removeRoutes(for: rules[idx])
        }
        saveRules()
        log("\(rules[idx].isEnabled ? "Enabled" : "Disabled") rule for \(rule.domain)")
    }

    func refreshIPs(for rule: RouteRule) async {
        guard let idx = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        removeRoutes(for: rule)
        let ips = await resolveIPs(for: rule.domain)
        await MainActor.run {
            rules[idx].resolvedIPs = ips
            rules[idx].lastResolved = Date()
            if rules[idx].isEnabled {
                applyRoutes(for: rules[idx])
            }
            saveRules()
            log("Refreshed IPs for \(rule.domain) → \(ips.joined(separator: ", "))")
        }
    }

    func applyAllActiveRules() {
        isApplying = true
        log("Applying all active rules...")
        for rule in rules where rule.isEnabled {
            applyRoutes(for: rule)
        }
        isApplying = false
        log("Done applying \(rules.filter { $0.isEnabled }.count) rules.")
    }

    func removeAllRoutes() {
        for rule in rules {
            removeRoutes(for: rule)
        }
        log("All routes removed.")
    }

    private func applyRoutes(for rule: RouteRule) {
        let gw = AppSettings.shared.effectiveGateway
        guard !gw.isEmpty else { log("⚠️ No gateway set"); return }
        for ip in rule.resolvedIPs {
            let result = shell("sudo route -n add \(ip) \(gw) 2>&1")
            log("route add \(ip) via \(gw): \(result.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    }

    private func removeRoutes(for rule: RouteRule) {
        for ip in rule.resolvedIPs {
            shell("sudo route -n delete \(ip) 2>&1")
        }
    }

    func resolveIPs(for domain: String) async -> [String] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = shell("dig +short \(domain) A | grep -E '^[0-9]'")
                let ips = result.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && $0.contains(".") }
                continuation.resume(returning: ips)
            }
        }
    }

    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let entry = "[\(timestamp)] \(message)"
        DispatchQueue.main.async {
            self.lastActionLog.append(entry)
            if self.lastActionLog.count > 200 {
                self.lastActionLog.removeFirst()
            }
        }
        print(entry)
    }
}

// MARK: - Shell Helper
@discardableResult
func shell(_ command: String) -> String {
    let process = Process()
    process.launchPath = "/bin/bash"
    process.arguments = ["-c", command]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    process.launch()
    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}
