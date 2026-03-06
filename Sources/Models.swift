import Foundation
import Combine

// MARK: - Route Rule Model
struct RouteRule: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var domain: String
    var resolvedIPs: [String] = []
    var manualIPs: [String] = []       // manually-entered IPs
    var isEnabled: Bool = true
    var lastResolved: Date?
    var notes: String = ""

    var displayDomain: String { domain.isEmpty ? "Unknown" : domain }
    var statusLabel: String { isEnabled ? "Active" : "Paused" }

    /// All IPs: resolved + manual, deduplicated
    var allIPs: [String] {
        Array(Set(resolvedIPs + manualIPs)).sorted()
    }
}

// MARK: - App Settings
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var gatewayMode: GatewayMode = .automatic
    @Published var manualGatewayIP: String = ""
    @Published var detectedGatewayIP: String = ""
    @Published var gatewayError: String? = nil
    @Published var runOnStartup: Bool = false
    @Published var applyOnLaunch: Bool = true
    @Published var dnsServer: String = "8.8.8.8"
    @Published var showInDock: Bool = true
    @Published var themeMode: ThemeMode = .system
    @Published var presenceMode: PresenceMode = .both

    enum GatewayMode: String, CaseIterable, Codable {
        case automatic = "Automatic"
        case manual = "Manual"
    }

    enum ThemeMode: String, CaseIterable, Codable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
    }

    enum PresenceMode: String, CaseIterable, Codable {
        case menuBarOnly  = "Menu Bar Only"
        case dockOnly     = "Dock Only"
        case both         = "Both"
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
                if gateway.isEmpty {
                    self.detectedGatewayIP = ""
                    self.gatewayError = "Could not detect gateway"
                } else if Self.isValidIPv4(gateway) {
                    self.detectedGatewayIP = gateway
                    self.gatewayError = nil
                } else {
                    // Non-IP result like "link#28"
                    self.detectedGatewayIP = gateway
                    self.gatewayError = "Detected \"\(gateway)\" which is not a valid IP. Please enter gateway manually."
                }
            }
        }
    }

    private static func isValidIPv4(_ s: String) -> Bool {
        let parts = s.components(separatedBy: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let n = Int(part), n >= 0, n <= 255 else { return false }
            return true
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
            "themeMode": themeMode.rawValue,
            "presenceMode": presenceMode.rawValue
        ]
        UserDefaults.standard.set(data, forKey: settingsKey)
        updateLoginItem()

        NotificationCenter.default.post(
            name: .dockVisibilityChanged,
            object: nil,
            userInfo: ["show": showInDock, "presenceMode": presenceMode.rawValue]
        )
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
        if let pm = data["presenceMode"] as? String { presenceMode = PresenceMode(rawValue: pm) ?? .both }
    }

    private func updateLoginItem() {
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

// MARK: - Privilege Helper
struct PrivilegeHelper {

    /// Run a shell command with admin privileges via `/usr/bin/osascript`.
    /// This triggers the macOS password dialog.
    /// Uses Process directly to avoid sandbox restrictions with NSAppleScript.
    @discardableResult
    static func runAsAdmin(_ command: String) -> String {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "do shell script \"\(escaped)\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "Error: \(error.localizedDescription)"
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus != 0 {
            // User cancelled or auth failed
            let msg = stderr.isEmpty ? "Unknown error (exit \(process.terminationStatus))" : stderr
            return "Error: \(msg)"
        }

        return stdout
    }

    /// Run a single route command with admin privileges.
    @discardableResult
    static func runRoute(_ command: String) -> String {
        return runAsAdmin(command)
    }

    /// Run multiple commands in a single admin prompt (one password dialog).
    /// Commands are joined with " && ".
    @discardableResult
    static func runBatchAsAdmin(_ commands: [String]) -> String {
        guard !commands.isEmpty else { return "" }
        let joined = commands.joined(separator: " && ")
        return runAsAdmin(joined)
    }

    // MARK: - Passwordless sudo for route command

    private static let sudoersFile = "/etc/sudoers.d/tunnelguard"

    /// Check if passwordless sudo is currently configured for route.
    static func isAdminGranted() -> Bool {
        return FileManager.default.fileExists(atPath: sudoersFile)
    }

    /// Grant passwordless sudo for /sbin/route to the current user.
    /// This creates a sudoers.d entry so route commands no longer need a password.
    /// Returns (success, message).
    static func grantAdmin() -> (Bool, String) {
        let user = NSUserName()
        // sudoers line: allow this user to run /sbin/route without password
        let line = "\(user) ALL=(ALL) NOPASSWD: /sbin/route"
        // We need admin to write to /etc/sudoers.d/
        let cmd = "echo '\(line)' > \(sudoersFile) && chmod 0440 \(sudoersFile) && chown root:wheel \(sudoersFile)"
        let result = runAsAdmin(cmd)
        if result.contains("Error:") {
            return (false, result)
        }
        return (true, "Admin access granted for route commands")
    }

    /// Revoke the passwordless sudo entry.
    static func revokeAdmin() -> (Bool, String) {
        let cmd = "rm -f \(sudoersFile)"
        let result = runAsAdmin(cmd)
        if result.contains("Error:") {
            return (false, result)
        }
        return (true, "Admin access revoked")
    }
}

// MARK: - Route Manager
class RouteManager: ObservableObject {
    static let shared = RouteManager()

    @Published var rules: [RouteRule] = []
    @Published var isApplying: Bool = false
    @Published var isRulesApplied: Bool = false
    @Published var lastActionLog: [String] = []
    @Published var activeRulesCount: Int = 0
    @Published var lastError: String? = nil
    /// Rule pending delete confirmation
    @Published var ruleToDelete: RouteRule? = nil
    /// Result of last apply operation for toast display
    enum ApplyResult { case success(Int), error(String), none }
    @Published var applyResult: ApplyResult = .none

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

    func addRule(domain: String, notes: String = "", manualIPs: [String] = []) async -> RouteRule? {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        guard !trimmed.isEmpty else { return nil }

        var rule = RouteRule(domain: trimmed, manualIPs: manualIPs, notes: notes)
        let (ips, debugOutput) = await resolveIPsDetailed(for: trimmed)
        rule.resolvedIPs = ips
        rule.lastResolved = Date()

        await MainActor.run {
            rules.append(rule)
            saveRules()
            if ips.isEmpty && manualIPs.isEmpty {
                log("⚠️ No IPs found for \(trimmed)")
                if !debugOutput.isEmpty { log("   output: \(debugOutput)") }
            } else {
                log("Added rule for \(trimmed) → \(rule.allIPs.joined(separator: ", "))")
            }
        }
        return rule
    }

    /// Request deletion — caller should set ruleToDelete and show confirmation
    func confirmRemoveRule(_ rule: RouteRule) {
        ruleToDelete = rule
    }

    /// Actually remove after confirmation
    func removeRule(_ rule: RouteRule) {
        removeRoutes(for: rule)
        rules.removeAll { $0.id == rule.id }
        saveRules()
        log("Removed rule for \(rule.domain)")
        ruleToDelete = nil
    }

    func cancelDelete() {
        ruleToDelete = nil
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

    /// Update rule fields (domain, notes, manualIPs)
    func updateRule(_ rule: RouteRule, newDomain: String? = nil, newNotes: String? = nil, newManualIPs: [String]? = nil) {
        guard let idx = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        if let d = newDomain { rules[idx].domain = d }
        if let n = newNotes { rules[idx].notes = n }
        if let ips = newManualIPs { rules[idx].manualIPs = ips }
        saveRules()
        log("Updated rule for \(rules[idx].domain)")
    }

    func refreshIPs(for rule: RouteRule) async {
        guard let idx = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        removeRoutes(for: rule)
        let (ips, debugOutput) = await resolveIPsDetailed(for: rule.domain)
        await MainActor.run {
            if ips.isEmpty {
                lastError = "Could not resolve \(rule.domain)"
                log("⚠️ Resolution failed for \(rule.domain)")
                if !debugOutput.isEmpty {
                    log("   output: \(debugOutput)")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { self.lastError = nil }
            } else {
                lastError = nil
                rules[idx].resolvedIPs = ips
                rules[idx].lastResolved = Date()
                if rules[idx].isEnabled {
                    applyRoutes(for: rules[idx])
                }
                saveRules()
                log("Refreshed IPs for \(rule.domain) → \(ips.joined(separator: ", "))")
            }
        }
    }

    func applyAllActiveRules() {
        isApplying = true
        applyResult = .none
        log("Applying all active rules...")
        let gw = AppSettings.shared.effectiveGateway
        guard !gw.isEmpty else {
            log("⚠️ No gateway set")
            isApplying = false
            applyResult = .error("No gateway configured")
            return
        }

        // Collect all route-add commands for a single admin prompt
        var commands: [String] = []
        for rule in rules where rule.isEnabled {
            for ip in rule.allIPs {
                let cmd = "route -n add \(ip) \(gw) 2>&1"
                commands.append(cmd)
                logCommand("route -n add \(ip) \(gw)")
            }
        }

        if commands.isEmpty {
            log("No active rules with IPs to apply.")
            isApplying = false
            applyResult = .error("No active rules with IPs")
            return
        }

        // Single password prompt for all commands (or direct sudo if granted)
        let result = runElevatedBatch(commands)
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasError = trimmed.contains("Error:") || trimmed.contains("error") || trimmed.contains("not permitted")

        if !trimmed.isEmpty {
            for line in trimmed.components(separatedBy: "\n") {
                let l = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !l.isEmpty { log("→ \(l)") }
            }
        }

        let count = rules.filter { $0.isEnabled }.count
        isApplying = false

        if hasError {
            applyResult = .error("Some routes failed — check log")
            log("⚠️ Completed with errors.")
        } else {
            isRulesApplied = true
            applyResult = .success(count)
            log("Done applying \(count) rules.")
        }
    }

    func stopAllRules() {
        log("Stopping all rules...")
        removeAllRoutes()
        isRulesApplied = false
        applyResult = .none
        log("All routes stopped.")
    }

    func removeAllRoutes() {
        var commands: [String] = []
        for rule in rules {
            for ip in rule.allIPs {
                commands.append("route -n delete \(ip) 2>&1 || true")
            }
        }
        if !commands.isEmpty {
            runElevatedBatch(commands)
        }
        log("All routes removed.")
    }

    private func applyRoutes(for rule: RouteRule) {
        let gw = AppSettings.shared.effectiveGateway
        guard !gw.isEmpty else { log("⚠️ No gateway set"); return }

        var commands: [String] = []
        for ip in rule.allIPs {
            let cmd = "route -n add \(ip) \(gw) 2>&1"
            commands.append(cmd)
            logCommand("route -n add \(ip) \(gw)")
        }

        if !commands.isEmpty {
            let result = runElevatedBatch(commands)
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                for line in trimmed.components(separatedBy: "\n") {
                    let l = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !l.isEmpty { log("→ \(l)") }
                }
            }
        }
    }

    private func removeRoutes(for rule: RouteRule) {
        var commands: [String] = []
        for ip in rule.allIPs {
            commands.append("route -n delete \(ip) 2>&1 || true")
        }
        if !commands.isEmpty {
            runElevatedBatch(commands)
        }
    }

    /// Smart batch execution: uses direct `sudo` if admin is granted, otherwise osascript prompt.
    @discardableResult
    private func runElevatedBatch(_ commands: [String]) -> String {
        if PrivilegeHelper.isAdminGranted() {
            // Admin granted — use direct sudo (no password dialog)
            let sudoCommands = commands.map { "sudo \($0)" }
            let joined = sudoCommands.joined(separator: " && ")
            return shell(joined)
        } else {
            return PrivilegeHelper.runBatchAsAdmin(commands)
        }
    }

    /// Resolve IPs using the configured DNS server to avoid sandbox/bind errors.
    /// Falls back to nslookup if dig fails.
    func resolveIPsDetailed(for domain: String) async -> ([String], String) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let dns = AppSettings.shared.dnsServer.trimmingCharacters(in: .whitespacesAndNewlines)

                // Build dig command: use @server only if DNS is configured
                let digCmd: String
                if dns.isEmpty {
                    digCmd = "dig +short +time=5 +tries=2 \(domain) A 2>&1"
                } else {
                    digCmd = "dig @\(dns) +short +time=5 +tries=2 \(domain) A 2>&1"
                }
                self.logCommand(digCmd)
                let raw = shell(digCmd)

                var ips = raw.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { Self.isValidIPv4($0) }

                let debugLine = raw.trimmingCharacters(in: .whitespacesAndNewlines)

                // If dig failed (bind error, etc.), fall back to nslookup
                if ips.isEmpty && (raw.contains("bind:") || raw.contains("Operation not permitted") || raw.contains("connection timed out")) {
                    let nsCmd: String
                    if dns.isEmpty {
                        nsCmd = "nslookup \(domain) 2>&1"
                    } else {
                        nsCmd = "nslookup \(domain) \(dns) 2>&1"
                    }
                    self.logCommand(nsCmd)
                    let nsRaw = shell(nsCmd)
                    // Parse nslookup output: lines after "Name:" containing "Address:"
                    var foundAnswer = false
                    for line in nsRaw.components(separatedBy: "\n") {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.hasPrefix("Name:") { foundAnswer = true; continue }
                        if foundAnswer && trimmed.hasPrefix("Address:") {
                            let ip = trimmed.replacingOccurrences(of: "Address:", with: "")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .components(separatedBy: "#").first?
                                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            if Self.isValidIPv4(ip) { ips.append(ip) }
                        }
                    }
                    let nsDebug = nsRaw.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: (ips, ips.isEmpty ? nsDebug : debugLine))
                    return
                }

                continuation.resume(returning: (ips, debugLine))
            }
        }
    }

    func resolveIPs(for domain: String) async -> [String] {
        let (ips, _) = await resolveIPsDetailed(for: domain)
        return ips
    }

    private static func isValidIPv4(_ s: String) -> Bool {
        let parts = s.components(separatedBy: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let n = Int(part), n >= 0, n <= 255 else { return false }
            return true
        }
    }

    func log(_ message: String) {
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

    /// Log a command (prefixed with CMD: for purple coloring in LogsView)
    private func logCommand(_ command: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let entry = "[\(timestamp)] CMD: \(command)"
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
