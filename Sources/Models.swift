import Cocoa
import Foundation
import Combine
import AppKit

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
    @Published var writeToHosts: Bool = false

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
                    // Non-IP result like "link#28" — don't store invalid value
                    self.detectedGatewayIP = ""
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
            "presenceMode": presenceMode.rawValue,
            "writeToHosts": writeToHosts
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
        writeToHosts = data["writeToHosts"] as? Bool ?? false
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
            shell("launchctl load \(shellQuote(plistPath))")
        } else {
            shell("launchctl unload \(shellQuote(plistPath)) 2>/dev/null || true")
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
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
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

    /// Grant passwordless sudo for /sbin/route and hosts-related commands to the current user.
    /// This creates a sudoers.d entry so route and hosts commands no longer need a password.
    /// Returns (success, message).
    static func grantAdmin() -> (Bool, String) {
        let user = NSUserName()
        // Grant NOPASSWD only for specific commands TunnelGuard needs, restricted to root target
        let line = "\(user) ALL=(root) NOPASSWD: /sbin/route, /bin/cp /tmp/tunnelguard_* /etc/hosts, /bin/chmod 644 /etc/hosts, /usr/sbin/chown root\\:wheel /etc/hosts, /usr/bin/dscacheutil -flushcache, /usr/bin/killall -HUP mDNSResponder"
        // We need admin to write to /etc/sudoers.d/
        let cmd = "echo '\(line)' > \(shellQuote(sudoersFile)) && chmod 0440 \(shellQuote(sudoersFile)) && chown root:wheel \(shellQuote(sudoersFile))"
        let result = runAsAdmin(cmd)
        if result.contains("Error:") {
            return (false, result)
        }
        return (true, "Admin access granted for route and hosts commands")
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

// MARK: - Hosts File Manager
class HostsFileManager {
    static let shared = HostsFileManager()

    private let hostsPath = "/etc/hosts"
    private let beginMarker = "## TunnelGuard - Start ##"
    private let endMarker   = "## TunnelGuard - End ##"

    /// Build hosts entries from the given rules (only enabled rules with IPs).
    private func buildEntries(for rules: [RouteRule]) -> String {
        var lines: [String] = []
        for rule in rules where rule.isEnabled && !rule.allIPs.isEmpty {
            // Add each IP as a separate line pointing to the domain
            for ip in rule.allIPs {
                lines.append("\(ip)\t\(rule.domain)")
            }
        }
        guard !lines.isEmpty else { return "" }
        return "\(beginMarker)\n" + lines.joined(separator: "\n") + "\n\(endMarker)"
    }

    /// Read the current /etc/hosts content, stripping any existing TunnelGuard block.
    private func readHostsWithoutBlock() -> String {
        guard let content = try? String(contentsOfFile: hostsPath, encoding: .utf8) else { return "" }
        // Remove existing TunnelGuard block (including markers)
        var result: [String] = []
        var inBlock = false
        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == beginMarker {
                inBlock = true
                continue
            }
            if trimmed == endMarker {
                inBlock = false
                continue
            }
            if !inBlock {
                result.append(line)
            }
        }
        // Remove trailing empty lines that we may have added
        while result.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            result.removeLast()
        }
        return result.joined(separator: "\n")
    }

    /// Write the TunnelGuard block to /etc/hosts for all active rules.
    /// Uses sudo if admin is granted, otherwise osascript admin prompt.
    func applyHosts(for rules: [RouteRule]) -> (Bool, String) {
        let block = buildEntries(for: rules)
        let existing = readHostsWithoutBlock()

        // Build new content: existing + blank line + TunnelGuard block
        var newContent = existing
        if !newContent.hasSuffix("\n") { newContent += "\n" }
        if !block.isEmpty {
            newContent += "\n\(block)\n"
        }

        return writeHosts(newContent)
    }

    /// Remove the TunnelGuard block from /etc/hosts.
    func removeHosts() -> (Bool, String) {
        let existing = readHostsWithoutBlock()
        var newContent = existing
        if !newContent.hasSuffix("\n") { newContent += "\n" }
        return writeHosts(newContent)
    }

    /// Update hosts entry for a single rule (re-applies all active rules).
    func updateHosts(for rules: [RouteRule]) -> (Bool, String) {
        return applyHosts(for: rules)
    }

    /// Write content to /etc/hosts using elevated privileges.
    private func writeHosts(_ content: String) -> (Bool, String) {
        let tmpFile = "/tmp/tunnelguard_hosts_\(UUID().uuidString)"

        // Step 0: Backup existing hosts file
        let backupPath = "/tmp/tunnelguard_hosts_backup"
        if let existing = try? String(contentsOfFile: hostsPath, encoding: .utf8) {
            try? existing.write(toFile: backupPath, atomically: true, encoding: .utf8)
        }

        // Step 1: Write content to temp file (app can write to /tmp without sudo)
        do {
            try content.write(toFile: tmpFile, atomically: true, encoding: .utf8)
        } catch {
            return (false, "Error: Could not write temp file — \(error.localizedDescription)")
        }

        // Verify temp file was written
        guard FileManager.default.fileExists(atPath: tmpFile) else {
            return (false, "Error: Temp file not found after write")
        }

        // Step 2: Copy temp file to /etc/hosts with elevated privileges
        // Always use osascript for /etc/hosts writes — it's the most reliable method
        // even when admin (sudoers) is granted, because sudoers argument matching is strict
        let qTmp = shellQuote(tmpFile)
        let qHosts = shellQuote(hostsPath)
        let copyCmd = "cp \(qTmp) \(qHosts) && chmod 644 \(qHosts) && chown root:wheel \(qHosts)"
        let result: String
        if PrivilegeHelper.isAdminGranted() {
            // Try sudo first
            result = shell("sudo cp \(qTmp) \(qHosts) 2>&1 && sudo chmod 644 \(qHosts) 2>&1 && sudo chown root:wheel \(qHosts) 2>&1")
            // If sudo failed (password needed, permission denied), fall back to osascript
            if result.contains("password") || result.contains("denied") || result.contains("not permitted") {
                let fallback = PrivilegeHelper.runAsAdmin(copyCmd)
                if fallback.contains("Error:") {
                    try? FileManager.default.removeItem(atPath: tmpFile)
                    return (false, fallback)
                }
            }
        } else {
            result = PrivilegeHelper.runAsAdmin(copyCmd)
            if result.contains("Error:") {
                try? FileManager.default.removeItem(atPath: tmpFile)
                return (false, result)
            }
        }

        // Step 3: Clean up temp file
        try? FileManager.default.removeItem(atPath: tmpFile)

        // Step 4: Verify the write worked
        if let written = try? String(contentsOfFile: hostsPath, encoding: .utf8) {
            if !written.contains(beginMarker) && content.contains(beginMarker) {
                return (false, "Error: Hosts file write verification failed — block not found after write")
            }
        }

        // Step 5: Flush macOS DNS cache so changes take effect immediately
        flushDNSCache()

        return (true, "Hosts file updated successfully")
    }

    /// Flush the macOS DNS cache so /etc/hosts changes are picked up immediately.
    private func flushDNSCache() {
        let flushCmd = "/usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder"
        if PrivilegeHelper.isAdminGranted() {
            shell("sudo \(flushCmd) 2>/dev/null")
        } else {
            // Try without sudo first (may work), fall back to admin prompt
            let result = shell(flushCmd + " 2>&1")
            if result.contains("not permitted") || result.contains("denied") {
                PrivilegeHelper.runAsAdmin(flushCmd)
            }
        }
    }

    /// Check if TunnelGuard block currently exists in /etc/hosts.
    func hasHostsEntries() -> Bool {
        guard let content = try? String(contentsOfFile: hostsPath, encoding: .utf8) else { return false }
        return content.contains(beginMarker)
    }

    /// Read the current TunnelGuard entries from /etc/hosts for display.
    func currentEntries() -> [String] {
        guard let content = try? String(contentsOfFile: hostsPath, encoding: .utf8) else { return [] }
        var entries: [String] = []
        var inBlock = false
        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == beginMarker {
                inBlock = true
                continue
            }
            if trimmed == endMarker {
                inBlock = false
                continue
            }
            if inBlock && !trimmed.isEmpty {
                entries.append(trimmed)
            }
        }
        return entries
    }

    /// Detect VPN DNS servers from scutil --dns output.
    static func detectVPNDNS() -> [String] {
        let raw = shell("scutil --dns 2>/dev/null")
        var servers: [String] = []
        for line in raw.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("nameserver[") || trimmed.hasPrefix("nameserver :") {
                // Extract IP from "nameserver[0] : 8.8.8.8"
                if let colonIdx = trimmed.range(of: ":") {
                    let ip = trimmed[colonIdx.upperBound...].trimmingCharacters(in: .whitespaces)
                    if !ip.isEmpty && !servers.contains(ip) {
                        servers.append(ip)
                    }
                }
            }
        }
        return servers
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
    /// Result of last refresh for toast display
    enum RefreshResult: Equatable { case success(String, Int), error(String), none }
    @Published var refreshResult: RefreshResult = .none

    private let rulesKey = "TunnelGuardRules"
    private let appliedStateKey = "TunnelGuardRulesApplied"

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

    /// Export rules as JSON data for saving to file.
    func exportRules() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(rules)
    }

    /// Import rules from JSON data. Skips duplicates. Returns count of imported rules.
    func importRules(from data: Data) -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let imported = try? decoder.decode([RouteRule].self, from: data) else { return 0 }
        var count = 0
        for var rule in imported {
            let domain = RouteManager.cleanDomain(rule.domain).lowercased()
            if rules.contains(where: { $0.domain.lowercased() == domain }) { continue }
            rule.id = UUID() // Assign new ID to avoid collisions
            rules.append(rule)
            count += 1
        }
        if count > 0 {
            saveRules()
            log("Imported \(count) rule(s)")
        }
        return count
    }

    /// Persist applied state so we can restore it after force-quit
    private func saveAppliedState() {
        UserDefaults.standard.set(isRulesApplied, forKey: appliedStateKey)
    }

    /// Check if routes from a previous session are still active in the routing table.
    /// Looks for any of our rule IPs in `netstat -nr` output.
    /// Calls completion on main thread with whether routes were found.
    func detectExistingRoutes(completion: ((Bool) -> Void)? = nil) {
        let rulesToCheck = rules.filter { $0.isEnabled }
        let gw = AppSettings.shared.effectiveGateway
        guard !gw.isEmpty, !rulesToCheck.isEmpty else {
            completion?(false)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let netstatOutput = shell("netstat -nr 2>/dev/null")
            var foundCount = 0

            for rule in rulesToCheck {
                for ip in rule.allIPs {
                    if netstatOutput.contains(ip) {
                        foundCount += 1
                    }
                }
            }

            DispatchQueue.main.async {
                if foundCount > 0 {
                    self.isRulesApplied = true
                    self.saveAppliedState()
                    self.log("Detected \(foundCount) active route(s) from previous session")
                    completion?(true)
                } else {
                    let wasApplied = UserDefaults.standard.bool(forKey: self.appliedStateKey)
                    if wasApplied {
                        self.isRulesApplied = false
                        self.saveAppliedState()
                        self.log("Previous routes were cleared (system reboot or network change)")
                    }
                    completion?(false)
                }
            }
        }
    }

    /// Log startup information — version, rules, gateway, hosts, DNS
    func logStartupInfo() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let settings = AppSettings.shared

        // Capture values on main thread first
        let total = rules.count
        let enabled = rules.filter { $0.isEnabled }.count
        let totalIPs = rules.filter { $0.isEnabled }.flatMap { $0.allIPs }.count
        let gwMode = settings.gatewayMode == .automatic ? "auto" : "manual"
        let gwIP = settings.effectiveGateway
        let gwErr = settings.gatewayError
        let dns = settings.dnsServer.trimmingCharacters(in: .whitespacesAndNewlines)
        let hostsEnabled = settings.writeToHosts
        let applyOnLaunchVal = settings.applyOnLaunch
        let runOnStartupVal = settings.runOnStartup

        // Run shell commands on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            let hostsActive = HostsFileManager.shared.hasHostsEntries()
            let vpnDNS = HostsFileManager.detectVPNDNS()
            let admin = PrivilegeHelper.isAdminGranted()

            DispatchQueue.main.async {
                self.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                self.log("TunnelGuard v\(version) (\(build)) started")
                self.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                self.log("Rules: \(total) total, \(enabled) enabled, \(totalIPs) IPs to route")

                if let gwErr = gwErr {
                    self.log("Gateway: \(gwIP) (\(gwMode)) ⚠️ \(gwErr)")
                } else {
                    self.log("Gateway: \(gwIP.isEmpty ? "not detected" : gwIP) (\(gwMode))")
                }

                self.log("DNS Server: \(dns.isEmpty ? "system default" : dns)")

                if !vpnDNS.isEmpty {
                    self.log("VPN DNS: \(vpnDNS.joined(separator: ", "))")
                }

                self.log("DNS Bypass: \(hostsEnabled ? "enabled" : "disabled")\(hostsActive ? ", hosts entries active" : "")")
                self.log("Admin Access: \(admin ? "granted" : "not granted")")
                self.log("Apply on launch: \(applyOnLaunchVal ? "yes" : "no"), Launch at startup: \(runOnStartupVal ? "yes" : "no")")
                self.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            }
        }
    }

    private func updateCount() {
        activeRulesCount = rules.filter { $0.isEnabled }.count
    }

    /// Clean a pasted URL to extract just the domain/subdomain.
    static func cleanDomain(_ input: String) -> String {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove protocol
        for prefix in ["https://", "http://"] {
            if s.lowercased().hasPrefix(prefix) {
                s = String(s.dropFirst(prefix.count))
            }
        }
        // Remove path, query, fragment (take only host part)
        if let slash = s.firstIndex(of: "/") { s = String(s[s.startIndex..<slash]) }
        if let q = s.firstIndex(of: "?") { s = String(s[s.startIndex..<q]) }
        if let h = s.firstIndex(of: "#") { s = String(s[s.startIndex..<h]) }
        // Remove port
        if let colon = s.firstIndex(of: ":") { s = String(s[s.startIndex..<colon]) }
        // Remove www.
        if s.lowercased().hasPrefix("www.") { s = String(s.dropFirst(4)) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func addRule(domain: String, notes: String = "", manualIPs: [String] = []) async -> RouteRule? {
        let trimmed = RouteManager.cleanDomain(domain)
        guard !trimmed.isEmpty else { return nil }

        // Prevent duplicate domain rules
        if rules.contains(where: { $0.domain.lowercased() == trimmed.lowercased() }) {
            await MainActor.run {
                log("⚠️ Rule for \(trimmed) already exists")
            }
            return nil
        }

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
            // Auto-apply routes for the new rule if rules are currently active
            if isRulesApplied && rule.isEnabled && !rule.allIPs.isEmpty {
                applyRoutes(for: rule)
                log("Auto-applied routes for newly added domain: \(trimmed)")
            }
        }
        // Sync hosts file on background thread after rule is added (avoids privilege prompt on main thread)
        if AppSettings.shared.writeToHosts && rule.isEnabled && !rule.allIPs.isEmpty {
            DispatchQueue.global(qos: .userInitiated).async {
                self.syncHostsFile()
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
        // Update /etc/hosts if enabled
        if AppSettings.shared.writeToHosts {
            syncHostsFile()
        }
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
        // Update /etc/hosts if enabled
        if AppSettings.shared.writeToHosts && isRulesApplied {
            syncHostsFile()
        }
        log("\(rules[idx].isEnabled ? "Enabled" : "Disabled") rule for \(rule.domain)")
    }

    /// Update rule fields (domain, notes, manualIPs)
    func updateRule(_ rule: RouteRule, newDomain: String? = nil, newNotes: String? = nil, newManualIPs: [String]? = nil) {
        guard let idx = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        if let d = newDomain { rules[idx].domain = d }
        if let n = newNotes { rules[idx].notes = n }
        if let ips = newManualIPs { rules[idx].manualIPs = ips }
        saveRules()
        // Update /etc/hosts if enabled and rules are applied
        if AppSettings.shared.writeToHosts && isRulesApplied {
            syncHostsFile()
        }
        log("Updated rule for \(rules[idx].domain)")
    }

    func refreshIPs(for rule: RouteRule) async {
        guard let idx = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        removeRoutes(for: rule)
        let (ips, debugOutput) = await resolveIPsDetailed(for: rule.domain)
        await MainActor.run {
            if ips.isEmpty {
                lastError = "Could not resolve \(rule.domain)"
                refreshResult = .error("Could not resolve \(rule.domain)")
                log("⚠️ Resolution failed for \(rule.domain)")
                if !debugOutput.isEmpty {
                    log("   output: \(debugOutput)")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    self.lastError = nil
                    self.refreshResult = .none
                }
            } else {
                lastError = nil
                rules[idx].resolvedIPs = ips
                rules[idx].lastResolved = Date()
                if rules[idx].isEnabled {
                    applyRoutes(for: rules[idx])
                }
                saveRules()
                // Update /etc/hosts with new IPs if enabled
                if AppSettings.shared.writeToHosts && isRulesApplied {
                    syncHostsFile()
                }
                refreshResult = .success(rule.domain, ips.count)
                log("Refreshed IPs for \(rule.domain) → \(ips.joined(separator: ", "))")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.refreshResult = .none
                }
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

        guard isSafeIPv4(gw) else {
            log("⚠️ Gateway is not a valid IP: \(gw)")
            isApplying = false
            applyResult = .error("Invalid gateway IP")
            return
        }

        // Collect all route-add commands for a single admin prompt
        var commands: [String] = []
        for rule in rules where rule.isEnabled {
            for ip in rule.allIPs where isSafeIPv4(ip) {
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

        let writeHosts = AppSettings.shared.writeToHosts
        let enabledCount = rules.filter { $0.isEnabled }.count
        let currentRules = rules

        // Run shell commands on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.runElevatedBatch(commands)
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasError = trimmed.contains("Error:") || trimmed.contains("error") || trimmed.contains("not permitted")

            // Write /etc/hosts entries if enabled (also on background thread)
            var hostsOk = true
            var hostsMsg = ""
            if writeHosts {
                let (ok, msg) = HostsFileManager.shared.applyHosts(for: currentRules)
                hostsOk = ok
                hostsMsg = msg
            }

            DispatchQueue.main.async {
                if !trimmed.isEmpty {
                    for line in trimmed.components(separatedBy: "\n") {
                        let l = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !l.isEmpty { self.log("→ \(l)") }
                    }
                }

                self.isApplying = false

                if hasError {
                    self.applyResult = .error("Some routes failed — check log")
                    self.log("⚠️ Completed with errors.")
                } else {
                    self.isRulesApplied = true
                    self.saveAppliedState()
                    self.applyResult = .success(enabledCount)
                    self.log("Done applying \(enabledCount) rules.")
                }

                if writeHosts {
                    if hostsOk {
                        let count = currentRules.filter { $0.isEnabled && !$0.allIPs.isEmpty }.count
                        self.log("DNS bypass: \(count) domain\(count == 1 ? "" : "s") written to /etc/hosts")
                    } else {
                        self.log("⚠️ Failed to write /etc/hosts: \(hostsMsg)")
                    }
                    NotificationCenter.default.post(name: Notification.Name("TunnelGuardHostsFileChanged"), object: nil)
                }
            }
        }
    }

    func stopAllRules() {
        log("Stopping all rules...")

        var commands: [String] = []
        for rule in rules {
            for ip in rule.allIPs where isSafeIPv4(ip) {
                commands.append("route -n delete \(ip) 2>&1 || true")
                logCommand("route -n delete \(ip)")
            }
        }

        let shouldRemoveHosts = AppSettings.shared.writeToHosts || HostsFileManager.shared.hasHostsEntries()

        // Run shell commands on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            if !commands.isEmpty {
                self.runElevatedBatch(commands)
            }

            // Remove /etc/hosts entries if they exist
            var hostsOk = true
            var hostsMsg = ""
            if shouldRemoveHosts {
                let (ok, msg) = HostsFileManager.shared.removeHosts()
                hostsOk = ok
                hostsMsg = msg
            }

            DispatchQueue.main.async {
                self.isRulesApplied = false
                self.saveAppliedState()
                self.applyResult = .none
                self.log("All routes removed.")

                if shouldRemoveHosts {
                    if hostsOk {
                        self.log("DNS bypass: /etc/hosts entries removed")
                    } else {
                        self.log("⚠️ Failed to clean /etc/hosts: \(hostsMsg)")
                    }
                    NotificationCenter.default.post(name: Notification.Name("TunnelGuardHostsFileChanged"), object: nil)
                }

                self.log("All routes stopped.")
            }
        }
    }

    func removeAllRoutes() {
        var commands: [String] = []
        for rule in rules {
            for ip in rule.allIPs where isSafeIPv4(ip) {
                commands.append("route -n delete \(ip) 2>&1 || true")
                logCommand("route -n delete \(ip)")
            }
        }
        if !commands.isEmpty {
            runElevatedBatch(commands)
        }
        log("All routes removed.")
    }

    private func applyRoutes(for rule: RouteRule) {
        let gw = AppSettings.shared.effectiveGateway
        guard !gw.isEmpty, isSafeIPv4(gw) else { log("⚠️ No valid gateway set"); return }

        var commands: [String] = []
        for ip in rule.allIPs where isSafeIPv4(ip) {
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
        for ip in rule.allIPs where isSafeIPv4(ip) {
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

    // MARK: - /etc/hosts Management

    /// Apply /etc/hosts entries for all active rules.
    private func applyHostsEntries() {
        let enabledRules = rules.filter { $0.isEnabled && !$0.allIPs.isEmpty }
        log("Writing /etc/hosts entries for \(enabledRules.count) domain(s)...")
        for rule in enabledRules {
            for ip in rule.allIPs {
                logCommand("/etc/hosts → \(ip)\t\(rule.domain)")
            }
        }
        let (ok, msg) = HostsFileManager.shared.applyHosts(for: rules)
        if ok {
            log("DNS bypass: \(enabledRules.count) domain\(enabledRules.count == 1 ? "" : "s") written to /etc/hosts")
        } else {
            log("⚠️ Failed to write /etc/hosts: \(msg)")
        }
        NotificationCenter.default.post(name: Notification.Name("TunnelGuardHostsFileChanged"), object: nil)
    }

    /// Remove TunnelGuard entries from /etc/hosts.
    private func removeHostsEntries() {
        log("Removing /etc/hosts entries...")
        let (ok, msg) = HostsFileManager.shared.removeHosts()
        if ok {
            log("DNS bypass: /etc/hosts entries removed")
        } else {
            log("⚠️ Failed to clean /etc/hosts: \(msg)")
        }
        NotificationCenter.default.post(name: Notification.Name("TunnelGuardHostsFileChanged"), object: nil)
    }

    /// Sync /etc/hosts with current rules (used when toggling/editing individual rules).
    func syncHostsFile() {
        let (ok, msg) = HostsFileManager.shared.applyHosts(for: rules)
        if ok {
            log("DNS bypass: /etc/hosts updated")
        } else {
            log("⚠️ Failed to update /etc/hosts: \(msg)")
        }
        NotificationCenter.default.post(name: Notification.Name("TunnelGuardHostsFileChanged"), object: nil)
    }

    /// Resolve IPs using the configured DNS server to avoid sandbox/bind errors.
    /// Falls back to nslookup if dig fails.
    func resolveIPsDetailed(for domain: String) async -> ([String], String) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let dns = AppSettings.shared.dnsServer.trimmingCharacters(in: .whitespacesAndNewlines)

                // Validate domain and DNS server before building shell commands
                guard isSafeDomain(domain) else {
                    continuation.resume(returning: ([], "Invalid domain name"))
                    return
                }
                if !dns.isEmpty && !isSafeIPv4(dns) {
                    continuation.resume(returning: ([], "Invalid DNS server IP"))
                    return
                }

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

    private static let logFileURL: URL = {
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/TunnelGuard")
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        return logsDir.appendingPathComponent("tunnelguard.log")
    }()

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
        Self.appendToLogFile(entry)
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
        Self.appendToLogFile(entry)
    }

    /// Append a log entry to the persistent log file with rotation.
    private static func appendToLogFile(_ entry: String) {
        let line = entry + "\n"
        if let handle = try? FileHandle(forWritingTo: logFileURL) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8) ?? Data())
            handle.closeFile()
        } else {
            try? line.write(to: logFileURL, atomically: true, encoding: .utf8)
        }
        // Rotate if log exceeds 1MB
        if let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
           let size = attrs[.size] as? UInt64, size > 1_000_000 {
            let backup = logFileURL.deletingLastPathComponent().appendingPathComponent("tunnelguard.log.old")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: logFileURL, to: backup)
        }
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

// MARK: - Input Sanitization

/// Validate that a string is a safe IPv4 address (digits and dots only).
func isSafeIPv4(_ s: String) -> Bool {
    let parts = s.components(separatedBy: ".")
    guard parts.count == 4 else { return false }
    return parts.allSatisfy { part in
        guard let n = Int(part), n >= 0, n <= 255 else { return false }
        return true
    }
}

/// Validate a domain is safe for shell use (alphanumeric, dots, hyphens only).
func isSafeDomain(_ s: String) -> Bool {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
    return !s.isEmpty && s.unicodeScalars.allSatisfy { allowed.contains($0) } && s.count <= 253
}

/// Shell-quote a string by wrapping in single quotes and escaping embedded single quotes.
func shellQuote(_ s: String) -> String {
    return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
}
