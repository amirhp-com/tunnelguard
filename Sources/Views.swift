import SwiftUI

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var routeManager = RouteManager.shared
    @StateObject private var settings = AppSettings.shared
    @State private var selectedTab: AppTab = .rules
    @State private var showAddSheet = false

    enum AppTab: String, CaseIterable {
        case rules = "Rules"
        case logs = "Logs"
        case settings = "Settings"
        case about = "About"

        var icon: String {
            switch self {
            case .rules: return "shield.lefthalf.filled"
            case .logs: return "terminal"
            case .settings: return "gear"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.15),
                    Color(red: 0.08, green: 0.12, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 0) {
                // Sidebar
                SidebarView(selectedTab: $selectedTab, showAddSheet: $showAddSheet)
                    .frame(width: 200)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)

                // Main Content
                Group {
                    switch selectedTab {
                    case .rules:
                        RulesView(showAddSheet: $showAddSheet)
                    case .logs:
                        LogsView()
                    case .settings:
                        SettingsView()
                    case .about:
                        AboutView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddRuleSheet(isPresented: $showAddSheet)
        }
        .environmentObject(routeManager)
        .environmentObject(settings)
    }
}

// MARK: - Sidebar
struct SidebarView: View {
    @Binding var selectedTab: ContentView.AppTab
    @Binding var showAddSheet: Bool
    @EnvironmentObject var routeManager: RouteManager

    var body: some View {
        VStack(spacing: 0) {
            // Logo area
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.3, green: 0.6, blue: 1.0), Color(red: 0.1, green: 0.4, blue: 0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .shadow(color: Color.blue.opacity(0.5), radius: 12, x: 0, y: 4)

                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text("TunnelGuard")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("v1.0.0")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.top, 28)
            .padding(.bottom, 24)

            // Status pill
            HStack(spacing: 6) {
                Circle()
                    .fill(routeManager.activeRulesCount > 0 ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
                    .shadow(color: routeManager.activeRulesCount > 0 ? .green : .clear, radius: 4)

                Text(routeManager.activeRulesCount > 0 ? "\(routeManager.activeRulesCount) active" : "Idle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
            .padding(.bottom, 20)

            // Nav items
            VStack(spacing: 2) {
                ForEach(ContentView.AppTab.allCases, id: \.self) { tab in
                    SidebarNavItem(tab: tab, isSelected: selectedTab == tab) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            // Apply button
            VStack(spacing: 8) {
                Button {
                    routeManager.applyAllActiveRules()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                        Text("Apply Rules")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.2, green: 0.5, blue: 1.0), Color(red: 0.1, green: 0.35, blue: 0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: Color.blue.opacity(0.4), radius: 8, y: 3)
                }
                .buttonStyle(.plain)

                Button {
                    showAddSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11))
                        Text("Add Domain")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 20)
        }
    }
}

struct SidebarNavItem: View {
    let tab: ContentView.AppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                    .foregroundColor(isSelected ? Color(red: 0.4, green: 0.7, blue: 1.0) : .white.opacity(0.55))

                Text(tab.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.55))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(isSelected ? Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Rules View
struct RulesView: View {
    @EnvironmentObject var routeManager: RouteManager
    @Binding var showAddSheet: Bool
    @State private var searchText = ""

    var filteredRules: [RouteRule] {
        if searchText.isEmpty { return routeManager.rules }
        return routeManager.rules.filter {
            $0.domain.localizedCaseInsensitiveContains(searchText) ||
            $0.resolvedIPs.joined().contains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Exclusion Rules")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(routeManager.rules.count) domains configured")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                }
                Spacer()

                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.system(size: 12))
                    TextField("Search domains...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .frame(width: 200)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 18)

            // Table header
            HStack {
                Text("DOMAIN")
                    .frame(width: 160, alignment: .leading)
                Text("RESOLVED IPs")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("LAST UPDATED")
                    .frame(width: 120, alignment: .leading)
                Text("STATUS")
                    .frame(width: 80, alignment: .center)
                Text("ACTIONS")
                    .frame(width: 80, alignment: .center)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.white.opacity(0.3))
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 24)

            // Rules list
            if filteredRules.isEmpty {
                EmptyStateView(showAddSheet: $showAddSheet)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredRules) { rule in
                            RuleRowView(rule: rule)
                            Rectangle()
                                .fill(Color.white.opacity(0.04))
                                .frame(height: 1)
                                .padding(.horizontal, 24)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
}

struct RuleRowView: View {
    let rule: RouteRule
    @EnvironmentObject var routeManager: RouteManager
    @State private var isHovered = false
    @State private var isRefreshing = false

    var body: some View {
        HStack {
            // Domain
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.domain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                if !rule.notes.isEmpty {
                    Text(rule.notes)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
            .frame(width: 160, alignment: .leading)

            // IPs
            VStack(alignment: .leading, spacing: 2) {
                if rule.resolvedIPs.isEmpty {
                    Text("Not resolved")
                        .font(.system(size: 12))
                        .foregroundColor(.orange.opacity(0.7))
                } else {
                    ForEach(rule.resolvedIPs.prefix(3), id: \.self) { ip in
                        Text(ip)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(red: 0.4, green: 0.8, blue: 0.6))
                    }
                    if rule.resolvedIPs.count > 3 {
                        Text("+\(rule.resolvedIPs.count - 3) more")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Last updated
            Text(rule.lastResolved.map { RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: Date()) } ?? "Never")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.35))
                .frame(width: 120, alignment: .leading)

            // Toggle
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in routeManager.toggleRule(rule) }
            ))
            .toggleStyle(GlassToggleStyle())
            .frame(width: 80, alignment: .center)

            // Actions
            HStack(spacing: 8) {
                Button {
                    isRefreshing = true
                    Task {
                        await routeManager.refreshIPs(for: rule)
                        isRefreshing = false
                    }
                } label: {
                    Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                        .rotationEffect(isRefreshing ? .degrees(360) : .degrees(0))
                        .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                }
                .buttonStyle(.plain)

                Button {
                    routeManager.removeRule(rule)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .frame(width: 80, alignment: .center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(isHovered ? Color.white.opacity(0.04) : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Add Rule Sheet
struct AddRuleSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var routeManager: RouteManager
    @State private var domain = ""
    @State private var notes = ""
    @State private var isResolving = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.09, blue: 0.17), Color(red: 0.09, green: 0.13, blue: 0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Text("Add Exclusion Rule")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Domain")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))

                    TextField("e.g. google.com or api.example.com", text: $domain)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes (optional)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))

                    TextField("e.g. Work intranet, bypass VPN", text: $notes)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                }

                HStack(spacing: 12) {
                    Button { isPresented = false } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Button {
                        addRule()
                    } label: {
                        HStack(spacing: 8) {
                            if isResolving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                            }
                            Text(isResolving ? "Resolving..." : "Add & Resolve")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.5, blue: 1.0), Color(red: 0.1, green: 0.35, blue: 0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .blue.opacity(0.4), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .disabled(domain.isEmpty || isResolving)
                    .opacity(domain.isEmpty ? 0.5 : 1.0)
                }
            }
            .padding(28)
        }
        .frame(width: 440, height: 320)
    }

    private func addRule() {
        errorMessage = ""
        isResolving = true
        Task {
            let result = await routeManager.addRule(domain: domain, notes: notes)
            await MainActor.run {
                isResolving = false
                if result == nil {
                    errorMessage = "Failed to add rule. Check the domain name."
                } else {
                    isPresented = false
                }
            }
        }
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    @Binding var showAddSheet: Bool

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "shield.slash")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.white.opacity(0.15))

            Text("No exclusion rules yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))

            Text("Add a domain to exclude it from your VPN tunnel")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.25))
                .multilineTextAlignment(.center)

            Button {
                showAddSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add First Rule")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Logs View
struct LogsView: View {
    @EnvironmentObject var routeManager: RouteManager

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Activity Log")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(routeManager.lastActionLog.count) entries")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }
                Spacer()
                Button {
                    RouteManager.shared.lastActionLog.removeAll()
                } label: {
                    Text("Clear")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 18)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(routeManager.lastActionLog.enumerated()), id: \.offset) { idx, entry in
                            Text(entry)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(entry.contains("⚠️") ? .orange : entry.contains("Error") ? .red : Color(red: 0.4, green: 0.85, blue: 0.6))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 3)
                                .id(idx)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Color.black.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .onChange(of: routeManager.lastActionLog.count) { _ in
                    if let last = routeManager.lastActionLog.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 28)

                // Gateway
                SettingsSectionView(title: "VPN Gateway", icon: "network") {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Gateway Mode", selection: $settings.gatewayMode) {
                            ForEach(AppSettings.GatewayMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        if settings.gatewayMode == .automatic {
                            HStack {
                                Text("Detected Gateway:")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.5))
                                Text(settings.detectedGatewayIP.isEmpty ? "Detecting..." : settings.detectedGatewayIP)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(Color(red: 0.4, green: 0.8, blue: 0.6))
                                Spacer()
                                Button { settings.detectGateway() } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            GlassTextField(placeholder: "e.g. 192.168.1.1", text: $settings.manualGatewayIP)
                        }
                    }
                }

                // DNS
                SettingsSectionView(title: "DNS Resolution", icon: "server.rack") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DNS Server for IP Resolution")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                        GlassTextField(placeholder: "8.8.8.8", text: $settings.dnsServer)
                    }
                }

                // Startup
                SettingsSectionView(title: "Startup & Behavior", icon: "power") {
                    VStack(alignment: .leading, spacing: 14) {
                        GlassToggleRow(label: "Launch at system startup", isOn: $settings.runOnStartup)
                        GlassToggleRow(label: "Apply active rules on launch", isOn: $settings.applyOnLaunch)
                        GlassToggleRow(label: "Show in Dock", isOn: $settings.showInDock)
                    }
                }

                // Save button
                Button {
                    settings.save()
                } label: {
                    Text("Save Settings")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.5, blue: 1.0), Color(red: 0.1, green: 0.35, blue: 0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .blue.opacity(0.4), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
        }
        .environmentObject(settings)
    }
}

struct SettingsSectionView<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.35))
            }

            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }
}

struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

struct GlassToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(GlassToggleStyle())
        }
    }
}

// MARK: - About View
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App hero
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.25, green: 0.55, blue: 1.0), Color(red: 0.1, green: 0.35, blue: 0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: .blue.opacity(0.5), radius: 20, y: 8)

                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Text("TunnelGuard")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text("Version 1.0.0  ·  Released March 2026")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.35))

                    Text("macOS VPN Split-Tunnel Manager")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, 32)

                // Developer
                VStack(spacing: 12) {
                    Text("DEVELOPER")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.3))

                    HStack(spacing: 16) {
                        Circle()
                            .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                            .overlay(Text("A").font(.system(size: 18, weight: .black)).foregroundColor(.white))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Amirhossein Hosseinpour")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Text("AmirhpCom")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        Spacer()

                        HStack(spacing: 10) {
                            LinkButton(title: "Website", url: "https://amirhp.com/landing", icon: "globe")
                            LinkButton(title: "GitHub", url: "https://github.com/amirhp-com/tunnelguard/", icon: "chevron.left.forwardslash.chevron.right")
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
                }

                // Disclaimer
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.system(size: 12))
                        Text("DISCLAIMER")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.orange.opacity(0.7))
                    }
                    Text("TunnelGuard modifies your system's routing table using macOS native commands. This requires administrator privileges. Improper use may affect network connectivity. Always ensure you understand the routing rules you apply. The developer assumes no responsibility for network disruptions, data loss, security incidents, or any other consequences arising from the use of this software. Use at your own risk. This tool is intended for advanced users familiar with network routing concepts.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                        .lineSpacing(4)
                }
                .padding(16)
                .background(Color.orange.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.15), lineWidth: 1))

                // Help & Links
                HStack(spacing: 12) {
                    LinkButton(title: "Documentation & Help", url: "https://github.com/amirhp-com/tunnelguard/", icon: "questionmark.circle", fullWidth: true)
                    LinkButton(title: "Report Issue", url: "https://github.com/amirhp-com/tunnelguard/issues", icon: "ant.circle", fullWidth: true)
                }

                // Copyleft
                VStack(spacing: 4) {
                    Text("© 2026 Amirhossein Hosseinpour · AmirhpCom")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.25))
                    Text("Copyleft (c) — Free to use, modify, and distribute with attribution")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.2))
                }
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct LinkButton: View {
    let title: String
    let url: String
    let icon: String
    var fullWidth: Bool = false

    var body: some View {
        Button {
            if let nsUrl = URL(string: url) {
                NSWorkspace.shared.open(nsUrl)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                if fullWidth { Spacer() }
            }
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Toggle Style
struct GlassToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(configuration.isOn ? Color(red: 0.2, green: 0.5, blue: 1.0) : Color.white.opacity(0.12))
                .frame(width: 44, height: 26)

            Circle()
                .fill(.white)
                .frame(width: 20, height: 20)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                .offset(x: configuration.isOn ? 9 : -9)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isOn)
        }
        .onTapGesture { configuration.isOn.toggle() }
    }
}
