import SwiftUI
import AppKit

// MARK: - Bundle Version Helper
struct BundleInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    static var versionLabel: String { "v\(version)" }
    static var fullLabel: String { "v\(version) (\(build))" }
}

// MARK: - Theme Environment
private struct ThemeKey: EnvironmentKey {
    static let defaultValue: AppSettings.ThemeMode = .dark
}
extension EnvironmentValues {
    var themeMode: AppSettings.ThemeMode {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Theme Colors
struct TGColors {
    let isDark: Bool

    var background: Color        { isDark ? Color(hex: "0d1117") : Color(hex: "f0f2f5") }
    var sidebarBg: Color         { isDark ? Color(hex: "0a0e15").opacity(0.6) : Color(hex: "dde0e8").opacity(0.85) }
    var panelBg: Color           { isDark ? Color.white.opacity(0.04) : Color.white.opacity(0.85) }
    var panelBorder: Color       { isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.10) }
    var primaryText: Color       { isDark ? Color.white : Color(hex: "1a1a2e") }
    var secondaryText: Color     { isDark ? Color.white.opacity(0.45) : Color(hex: "1a1a2e").opacity(0.55) }
    var accentBlue: Color        { Color(hex: "3b82f6") }
    var accentGreen: Color       { isDark ? Color(hex: "34d399") : Color(hex: "059669") }
    var accentOrange: Color      { Color(hex: "f59e0b") }
    var accentRed: Color         { Color(hex: "ef4444") }
    var accentPurple: Color      { isDark ? Color(hex: "a78bfa") : Color(hex: "7c3aed") }
    var glassOverlay: Color      { isDark ? Color.white.opacity(0.03) : Color.white.opacity(0.3) }
    var divider: Color           { isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.10) }
    var rowHover: Color          { isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.04) }
    var inputBg: Color           { isDark ? Color.white.opacity(0.07) : Color.white.opacity(0.95) }
    var inputBorder: Color       { isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.15) }
    var selectedNavBg: Color     { isDark ? Color.white.opacity(0.10) : Color(hex: "3b82f6").opacity(0.14) }
    var selectedNavBorder: Color { isDark ? Color(hex: "3b82f6").opacity(0.3) : Color(hex: "3b82f6").opacity(0.45) }
    var toastBg: Color           { isDark ? Color(hex: "111827").opacity(0.95) : Color.white.opacity(0.97) }
    var logText: NSColor         { isDark ? NSColor(red:0.35,green:0.85,blue:0.6,alpha:1) : NSColor(red:0.05,green:0.45,blue:0.25,alpha:1) }
    var logCmdText: NSColor      { isDark ? NSColor(red:0.65,green:0.55,blue:0.98,alpha:1) : NSColor(red:0.48,green:0.23,blue:0.93,alpha:1) }

    // Toggle colors for light mode visibility
    var toggleOnBg: Color        { Color(hex: "3b82f6") }
    var toggleOffBg: Color       { isDark ? Color.secondary.opacity(0.25) : Color.black.opacity(0.12) }

    // Segmented picker styling
    var segmentBg: Color         { isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06) }
    var segmentSelectedBg: Color { isDark ? Color.white.opacity(0.15) : Color.white }
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var val: UInt64 = 0
        Scanner(string: h).scanHexInt64(&val)
        self.init(
            red: Double((val >> 16) & 0xFF)/255,
            green: Double((val >> 8) & 0xFF)/255,
            blue: Double(val & 0xFF)/255
        )
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var routeManager = RouteManager.shared
    @StateObject private var settings = AppSettings.shared
    @State private var selectedTab: AppTab = .rules
    @State private var showAddSheet = false
    @State private var editingRule: RouteRule? = nil
    @State private var showApplyToast = false
    @State private var applyToastMessage = ""
    @State private var applyToastIsError = false
    @State private var showRefreshToast = false
    @State private var refreshToastMessage = ""
    @State private var refreshToastIsError = false

    enum AppTab: String, CaseIterable {
        case rules    = "Rules"
        case logs     = "Logs"
        case settings = "Settings"
        case about    = "About"
        case vpn      = "VPN Settings"

        var icon: String {
            switch self {
            case .rules:    return "shield.lefthalf.filled"
            case .logs:     return "terminal"
            case .settings: return "gear"
            case .about:    return "info.circle"
            case .vpn:      return "network.badge.shield.half.filled"
            }
        }

        var isExternal: Bool { self == .vpn }
    }

    private var colors: TGColors {
        let dark: Bool
        switch settings.themeMode {
        case .dark:   dark = true
        case .light:  dark = false
        case .system: dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        return TGColors(isDark: dark)
    }

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            colors.glassOverlay.ignoresSafeArea()

            HStack(spacing: 0) {
                SidebarView(selectedTab: $selectedTab, showAddSheet: $showAddSheet, colors: colors)
                    .frame(width: 204)
                    .background(
                        ZStack {
                            colors.sidebarBg
                            LinearGradient(
                                colors: [colors.glassOverlay, Color.clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        }
                    )

                colors.divider.frame(width: 1)

                Group {
                    switch selectedTab {
                    case .rules:    RulesView(showAddSheet: $showAddSheet, editingRule: $editingRule, colors: colors)
                    case .logs:     LogsView(colors: colors)
                    case .settings: SettingsView(colors: colors)
                    case .about:    AboutView(colors: colors)
                    case .vpn:      Color.clear
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddRuleSheet(isPresented: $showAddSheet, colors: colors)
        }
        .sheet(item: $editingRule) { rule in
            EditRuleSheet(rule: rule, isPresented: Binding(
                get: { editingRule != nil },
                set: { if !$0 { editingRule = nil } }
            ), colors: colors)
        }
        // Delete confirmation alert
        .alert("Delete Rule", isPresented: Binding(
            get: { routeManager.ruleToDelete != nil },
            set: { if !$0 { routeManager.cancelDelete() } }
        )) {
            Button("Cancel", role: .cancel) { routeManager.cancelDelete() }
            Button("Delete", role: .destructive) {
                if let r = routeManager.ruleToDelete { routeManager.removeRule(r) }
            }
        } message: {
            if let r = routeManager.ruleToDelete {
                Text("Are you sure you want to delete the rule for \"\(r.domain)\"? This will also remove its routes.")
            }
        }
        .environmentObject(routeManager)
        .environmentObject(settings)
        .preferredColorScheme(settings.themeMode == .dark ? .dark : settings.themeMode == .light ? .light : nil)
        .modifier(ToastOverlay(
            message: showRefreshToast ? refreshToastMessage : applyToastMessage,
            icon: (showRefreshToast ? refreshToastIsError : applyToastIsError) ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
            iconColor: (showRefreshToast ? refreshToastIsError : applyToastIsError) ? colors.accentOrange : colors.accentGreen,
            isShowing: showApplyToast || showRefreshToast,
            colors: colors
        ))
        .onChange(of: routeManager.isApplying) { applying in
            if !applying {
                switch routeManager.applyResult {
                case .success(let count):
                    applyToastMessage = "\(count) rule\(count == 1 ? "" : "s") applied successfully"
                    applyToastIsError = false
                    withAnimation { showApplyToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { showApplyToast = false } }
                case .error(let msg):
                    applyToastMessage = msg
                    applyToastIsError = true
                    withAnimation { showApplyToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) { withAnimation { showApplyToast = false } }
                case .none:
                    break
                }
            }
        }
        .onChange(of: routeManager.refreshResult) { result in
            switch result {
            case .success(let domain, let count):
                refreshToastMessage = "\(domain) → \(count) IP\(count == 1 ? "" : "s") resolved"
                refreshToastIsError = false
                withAnimation { showRefreshToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { showRefreshToast = false } }
            case .error(let msg):
                refreshToastMessage = msg
                refreshToastIsError = true
                withAnimation { showRefreshToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { withAnimation { showRefreshToast = false } }
            case .none:
                break
            }
        }
    }
}

// MARK: - Sidebar
struct SidebarView: View {
    @Binding var selectedTab: ContentView.AppTab
    @Binding var showAddSheet: Bool
    let colors: TGColors
    @EnvironmentObject var routeManager: RouteManager

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: [Color(hex: "3b82f6"), Color(hex: "1d4ed8")],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)
                        .shadow(color: Color(hex: "3b82f6").opacity(0.5), radius: 12, y: 4)
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text("TunnelGuard")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(colors.primaryText)
                Text(BundleInfo.fullLabel)
                    .font(.system(size: 10))
                    .foregroundColor(colors.secondaryText)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            HStack(spacing: 5) {
                Circle()
                    .fill(routeManager.isRulesApplied ? colors.accentGreen : colors.secondaryText)
                    .frame(width: 6, height: 6)
                    .shadow(color: routeManager.isRulesApplied ? colors.accentGreen.opacity(0.8) : .clear, radius: 4)
                if routeManager.isRulesApplied {
                    Text("\(routeManager.activeRulesCount) active")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(colors.accentGreen)
                } else {
                    Text(routeManager.rules.count > 0 ? "\((routeManager.rules.count)) rule\((routeManager.rules.count) == 1 ? "" : "s")" : "Idle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(colors.secondaryText)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(colors.panelBg)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(colors.panelBorder, lineWidth: 1))
            .padding(.bottom, 18)

            VStack(spacing: 2) {
                ForEach(ContentView.AppTab.allCases.filter { !$0.isExternal }, id: \.self) { tab in
                    SidebarNavItem(tab: tab, isSelected: selectedTab == tab, colors: colors) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            VStack(spacing: 6) {
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension?VPN") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "network.badge.shield.half.filled")
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 20)
                            .foregroundColor(colors.accentBlue)
                        Text("VPN Settings")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(colors.primaryText)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                            .foregroundColor(colors.secondaryText)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .contentShape(Rectangle())
                    .background(colors.panelBg)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(colors.panelBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
            }

            VStack(spacing: 8) {
                Button { showAddSheet = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 11))
                        Text("Add Domain").font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(colors.primaryText.opacity(0.85))
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(colors.inputBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(colors.inputBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)

            // Apply / Stop button
            VStack(spacing: 0) {
                Button {
                    if routeManager.isRulesApplied {
                        routeManager.stopAllRules()
                    } else {
                        routeManager.applyAllActiveRules()
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: routeManager.isRulesApplied ? "stop.fill" : "play.fill")
                            .font(.system(size: 11))
                        Text(routeManager.isRulesApplied ? "Stop Rules" : "Apply Rules")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: routeManager.isRulesApplied
                                ? [Color(hex:"059669"), Color(hex:"047857")]
                                : [Color(hex:"3b82f6"), Color(hex:"1d4ed8")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(
                        color: routeManager.isRulesApplied
                            ? Color(hex:"059669").opacity(0.4)
                            : Color(hex:"3b82f6").opacity(0.4),
                        radius: 8, y: 3
                    )
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.25), value: routeManager.isRulesApplied)
            }
            .padding(.horizontal, 10)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
    }
}

struct SidebarNavItem: View {
    let tab: ContentView.AppTab
    let isSelected: Bool
    let colors: TGColors
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 20)
                    .foregroundColor(isSelected ? colors.accentBlue : colors.secondaryText)
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? colors.primaryText : colors.secondaryText)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .contentShape(Rectangle())
            .background(isSelected ? colors.selectedNavBg : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(isSelected ? colors.selectedNavBorder : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Toast Modifier
struct ToastOverlay: ViewModifier {
    let message: String
    let icon: String
    let iconColor: Color
    let isShowing: Bool
    let colors: TGColors

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            if isShowing {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(.system(size: 14, weight: .semibold))
                    Text(message)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(colors.primaryText)
                }
                .padding(.horizontal, 18).padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 13)
                        .fill(colors.toastBg)
                        .shadow(color: .black.opacity(0.3), radius: 14, y: 5)
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(iconColor.opacity(0.3), lineWidth: 1))
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 22)
                .zIndex(99)
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: isShowing)
    }
}

// MARK: - Rules View
struct RulesView: View {
    @EnvironmentObject var routeManager: RouteManager
    @Binding var showAddSheet: Bool
    @Binding var editingRule: RouteRule?
    let colors: TGColors
    @State private var searchText = ""

    var filteredRules: [RouteRule] {
        searchText.isEmpty ? routeManager.rules :
        routeManager.rules.filter {
            $0.domain.localizedCaseInsensitiveContains(searchText) ||
            $0.allIPs.joined().contains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Exclusion Rules")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(colors.primaryText)
                    Text("\(routeManager.rules.count) domains configured")
                        .font(.system(size: 12))
                        .foregroundColor(colors.secondaryText)
                }
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(colors.secondaryText).font(.system(size: 12))
                    TextField("Search domains...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(colors.primaryText)
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(colors.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(colors.inputBorder, lineWidth: 1))
                .frame(width: 200)
            }
            .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 18)

            if let err = routeManager.lastError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(colors.accentOrange)
                        .font(.system(size: 13, weight: .semibold))
                    Text(err)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(colors.primaryText)
                    Spacer()
                }
                .padding(.horizontal, 18).padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 13)
                        .fill(colors.toastBg)
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(colors.accentOrange.opacity(0.35), lineWidth: 1))
                )
                .padding(.horizontal, 24).padding(.bottom, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack {
                Text("DOMAIN").frame(width: 150, alignment: .leading)
                Text("RESOLVED IPs").frame(maxWidth: .infinity, alignment: .leading)
                Text("LAST UPDATED").frame(width: 110, alignment: .leading)
                Text("STATUS").frame(width: 70, alignment: .center)
                Text("ACTIONS").frame(width: 110, alignment: .center)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(colors.secondaryText)
            .padding(.horizontal, 24).padding(.bottom, 8)

            colors.divider.frame(height: 1).padding(.horizontal, 24)

            if filteredRules.isEmpty {
                EmptyStateView(showAddSheet: $showAddSheet, colors: colors)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredRules) { rule in
                            RuleRowView(rule: rule, colors: colors, editingRule: $editingRule)
                            colors.divider.frame(height: 1).padding(.horizontal, 24)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: routeManager.lastError)
    }
}

struct RuleRowView: View {
    let rule: RouteRule
    let colors: TGColors
    @Binding var editingRule: RouteRule?
    @EnvironmentObject var routeManager: RouteManager
    @State private var isHovered = false
    @State private var isRefreshing = false

    var body: some View {
        HStack {
            // Domain
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.domain).font(.system(size: 13, weight: .medium)).foregroundColor(colors.primaryText)
                if !rule.notes.isEmpty {
                    Text(rule.notes).font(.system(size: 10)).foregroundColor(colors.secondaryText)
                }
                if !rule.manualIPs.isEmpty {
                    Text("+ \(rule.manualIPs.count) manual IP\(rule.manualIPs.count == 1 ? "" : "s")")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(colors.accentPurple)
                }
            }
            .frame(width: 150, alignment: .leading)

            // IPs
            VStack(alignment: .leading, spacing: 2) {
                if rule.allIPs.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(colors.accentOrange)
                        Text("ERR · Check Log")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(colors.accentOrange)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(colors.accentOrange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                } else {
                    ForEach(rule.allIPs.prefix(3), id: \.self) { ip in
                        HStack(spacing: 4) {
                            Text(ip)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(colors.accentGreen)
                            if rule.manualIPs.contains(ip) {
                                Text("M")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(colors.accentPurple)
                                    .padding(.horizontal, 3).padding(.vertical, 1)
                                    .background(colors.accentPurple.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                    }
                    if rule.allIPs.count > 3 {
                        Text("+\(rule.allIPs.count - 3) more")
                            .font(.system(size: 10))
                            .foregroundColor(colors.secondaryText)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Last updated
            Text(rule.lastResolved.map { RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: Date()) } ?? "Never")
                .font(.system(size: 11)).foregroundColor(colors.secondaryText)
                .frame(width: 110, alignment: .leading)

            // Toggle
            Toggle("", isOn: Binding(get: { rule.isEnabled }, set: { _ in routeManager.toggleRule(rule) }))
                .toggleStyle(GlassToggleStyle(colors: colors))
                .frame(width: 70, alignment: .center)

            // Actions
            HStack(spacing: 6) {
                // Edit
                Button { editingRule = rule } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundColor(colors.accentBlue.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Edit rule")

                // Refresh
                Button {
                    isRefreshing = true
                    Task { await routeManager.refreshIPs(for: rule); isRefreshing = false }
                } label: {
                    Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(colors.secondaryText)
                        .rotationEffect(isRefreshing ? .degrees(360) : .degrees(0))
                        .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                }
                .buttonStyle(.plain)
                .help("Refresh IPs")

                // Delete (with confirmation)
                Button { routeManager.confirmRemoveRule(rule) } label: {
                    Image(systemName: "trash").font(.system(size: 12)).foregroundColor(colors.accentRed.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Delete rule")
            }
            .frame(width: 110, alignment: .center)
        }
        .padding(.horizontal, 24).padding(.vertical, 14)
        .background(isHovered ? colors.rowHover : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Add Rule Sheet
struct AddRuleSheet: View {
    @Binding var isPresented: Bool
    let colors: TGColors
    @EnvironmentObject var routeManager: RouteManager
    @State private var domain = ""
    @State private var notes = ""
    @State private var manualIPsText = ""
    @State private var isAdding = false
    @State private var errorMsg: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Add Exclusion Rule")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(colors.primaryText)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .medium))
                        .foregroundColor(colors.secondaryText)
                        .padding(6)
                        .background(colors.inputBg)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Domain").font(.system(size: 12, weight: .medium)).foregroundColor(colors.secondaryText)
                GlassTextField(placeholder: "e.g. example.com", text: $domain, colors: colors)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Manual IPs (optional)").font(.system(size: 12, weight: .medium)).foregroundColor(colors.secondaryText)
                GlassTextField(placeholder: "e.g. 1.2.3.4, 5.6.7.8", text: $manualIPsText, colors: colors)
                Text("Comma-separated. These are added alongside resolved IPs.")
                    .font(.system(size: 10))
                    .foregroundColor(colors.secondaryText.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Notes (optional)").font(.system(size: 12, weight: .medium)).foregroundColor(colors.secondaryText)
                GlassTextField(placeholder: "e.g. work services", text: $notes, colors: colors)
            }

            if let e = errorMsg {
                Text(e).font(.system(size: 12)).foregroundColor(colors.accentRed)
            }

            HStack(spacing: 10) {
                Button { isPresented = false } label: {
                    Text("Cancel").font(.system(size: 13, weight: .medium))
                        .foregroundColor(colors.secondaryText)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(colors.inputBg)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(colors.inputBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    guard !domain.trimmingCharacters(in: .whitespaces).isEmpty else {
                        errorMsg = "Please enter a domain name."
                        return
                    }
                    let manualIPs = parseManualIPs(manualIPsText)
                    isAdding = true
                    Task {
                        await routeManager.addRule(domain: domain, notes: notes, manualIPs: manualIPs)
                        isPresented = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isAdding { ProgressView().scaleEffect(0.6).tint(.white).frame(width: 14, height: 14) }
                        Text(isAdding ? "Resolving..." : "Add Rule").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 36).padding(.vertical, 2)
                    .background(LinearGradient(colors: [Color(hex:"3b82f6"), Color(hex:"1d4ed8")], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(isAdding)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(colors.background)
    }
}

// MARK: - Edit Rule Sheet
struct EditRuleSheet: View {
    let rule: RouteRule
    @Binding var isPresented: Bool
    let colors: TGColors
    @EnvironmentObject var routeManager: RouteManager
    @State private var domain: String = ""
    @State private var notes: String = ""
    @State private var manualIPsText: String = ""
    @State private var isRefreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Edit Rule")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(colors.primaryText)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .medium))
                        .foregroundColor(colors.secondaryText)
                        .padding(6)
                        .background(colors.inputBg)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Domain").font(.system(size: 12, weight: .medium)).foregroundColor(colors.secondaryText)
                GlassTextField(placeholder: "e.g. example.com", text: $domain, colors: colors)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Manual IPs").font(.system(size: 12, weight: .medium)).foregroundColor(colors.secondaryText)
                GlassTextField(placeholder: "e.g. 1.2.3.4, 5.6.7.8", text: $manualIPsText, colors: colors)
                Text("Comma-separated. Added alongside auto-resolved IPs.")
                    .font(.system(size: 10))
                    .foregroundColor(colors.secondaryText.opacity(0.7))
            }

            // Show current resolved IPs (read-only)
            if !rule.resolvedIPs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("Auto-Resolved IPs").font(.system(size: 12, weight: .medium)).foregroundColor(colors.secondaryText)
                        Button {
                            isRefreshing = true
                            Task { await routeManager.refreshIPs(for: rule); isRefreshing = false }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                                .foregroundColor(colors.accentBlue)
                                .rotationEffect(isRefreshing ? .degrees(360) : .degrees(0))
                                .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                        }
                        .buttonStyle(.plain)
                    }
                    Text(rule.resolvedIPs.joined(separator: ", "))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(colors.accentGreen)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(colors.inputBg)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(colors.inputBorder, lineWidth: 1))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Notes (optional)").font(.system(size: 12, weight: .medium)).foregroundColor(colors.secondaryText)
                GlassTextField(placeholder: "e.g. work services", text: $notes, colors: colors)
            }

            HStack(spacing: 10) {
                Button { isPresented = false } label: {
                    Text("Cancel").font(.system(size: 13, weight: .medium))
                        .foregroundColor(colors.secondaryText)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(colors.inputBg)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(colors.inputBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    let manualIPs = parseManualIPs(manualIPsText)
                    routeManager.updateRule(rule, newDomain: domain, newNotes: notes, newManualIPs: manualIPs)
                    isPresented = false
                } label: {
                    Text("Save Changes").font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(LinearGradient(colors: [Color(hex:"3b82f6"), Color(hex:"1d4ed8")], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(colors.background)
        .onAppear {
            domain = rule.domain
            notes = rule.notes
            manualIPsText = rule.manualIPs.joined(separator: ", ")
        }
    }
}

// MARK: - Parse manual IPs helper
func parseManualIPs(_ text: String) -> [String] {
    text.components(separatedBy: CharacterSet(charactersIn: ",\n "))
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

// MARK: - Empty State
struct EmptyStateView: View {
    @Binding var showAddSheet: Bool
    let colors: TGColors

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "shield.slash").font(.system(size: 48, weight: .thin)).foregroundColor(colors.secondaryText.opacity(0.4))
            Text("No exclusion rules yet").font(.system(size: 17, weight: .semibold)).foregroundColor(colors.secondaryText)
            Text("Add a domain to exclude it from your VPN tunnel").font(.system(size: 13)).foregroundColor(colors.secondaryText.opacity(0.6)).multilineTextAlignment(.center)
            Button { showAddSheet = true } label: {
                HStack(spacing: 8) { Image(systemName: "plus"); Text("Add First Rule") }
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color(hex:"3b82f6").opacity(0.85))
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
    let colors: TGColors
    @State private var showCopiedToast = false

    private var logText: String { routeManager.lastActionLog.joined(separator: "\n") }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Activity Log").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(colors.primaryText)
                    Text("\(routeManager.lastActionLog.count) entries").font(.system(size: 12)).foregroundColor(colors.secondaryText)
                }
                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(logText, forType: .string)
                    withAnimation { showCopiedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { showCopiedToast = false } }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: showCopiedToast ? "checkmark" : "doc.on.doc").font(.system(size: 11))
                        Text(showCopiedToast ? "Copied!" : "Copy All").font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(showCopiedToast ? colors.accentGreen : colors.secondaryText)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(colors.inputBg)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(colors.inputBorder, lineWidth: 1))
                }
                .buttonStyle(.plain).animation(.easeInOut(duration: 0.2), value: showCopiedToast)

                Button { RouteManager.shared.lastActionLog.removeAll() } label: {
                    Text("Clear").font(.system(size: 12, weight: .medium))
                        .foregroundColor(colors.secondaryText)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(colors.inputBg)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(colors.inputBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 18)

            LogTextView(text: logText, colors: colors)
                .background(colors.panelBg)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(colors.panelBorder, lineWidth: 1))
                .padding(.horizontal, 24).padding(.bottom, 24)
        }
        .modifier(ToastOverlay(message: "Copied to clipboard", icon: "doc.on.doc.fill", iconColor: colors.accentGreen, isShowing: showCopiedToast, colors: colors))
    }
}

// MARK: - Log Text View (NSTextView — selectable, copyable, CMD: lines in purple)
struct LogTextView: NSViewRepresentable {
    let text: String
    let colors: TGColors

    func makeNSView(context: Context) -> NSScrollView {
        let sv = NSTextView.scrollableTextView()
        guard let tv = sv.documentView as? NSTextView else { return sv }
        tv.isEditable = false; tv.isSelectable = true; tv.isRichText = false
        tv.backgroundColor = .clear; tv.drawsBackground = false
        tv.textContainerInset = NSSize(width: 16, height: 12)
        tv.isAutomaticLinkDetectionEnabled = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        sv.backgroundColor = .clear; sv.drawsBackground = false
        sv.hasVerticalScroller = true; sv.autohidesScrollers = true
        return sv
    }

    func updateNSView(_ sv: NSScrollView, context: Context) {
        guard let tv = sv.documentView as? NSTextView else { return }
        let lines = text.components(separatedBy: "\n")
        let attr = NSMutableAttributedString()
        for (i, line) in lines.enumerated() {
            let c: NSColor
            if line.contains("CMD:")                                   { c = colors.logCmdText }
            else if line.contains("⚠️")                               { c = NSColor(red:1,green:0.6,blue:0.2,alpha:1) }
            else if line.contains("Error") || line.contains("error")  { c = NSColor(red:0.95,green:0.35,blue:0.35,alpha:1) }
            else                                                       { c = colors.logText }

            let font: NSFont = line.contains("CMD:")
                ? NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
                : NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

            attr.append(NSAttributedString(string: i < lines.count-1 ? line+"\n" : line, attributes: [
                .font: font, .foregroundColor: c
            ]))
        }
        tv.textStorage?.setAttributedString(attr)
        tv.scrollToEndOfDocument(nil)
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    let colors: TGColors
    @State private var showSavedToast = false
    @State private var adminGranted = PrivilegeHelper.isAdminGranted()
    @State private var adminStatusMsg: String? = nil
    @State private var hostsActive = HostsFileManager.shared.hasHostsEntries()
    @State private var hostsEntries: [String] = HostsFileManager.shared.currentEntries()
    @State private var vpnDNSServers: [String] = HostsFileManager.detectVPNDNS()

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Settings")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(colors.primaryText)
                        .padding(.top, 28)

                    // Gateway
                    SettingsSectionView(title: "VPN Gateway", icon: "network", colors: colors) {
                        VStack(alignment: .leading, spacing: 14) {
                            TGSegmentedPicker(
                                selection: $settings.gatewayMode,
                                options: AppSettings.GatewayMode.allCases,
                                label: { $0.rawValue },
                                colors: colors
                            )
                            if settings.gatewayMode == .automatic {
                                HStack {
                                    Text("Detected:").font(.system(size: 13)).foregroundColor(colors.secondaryText)
                                    if let err = settings.gatewayError {
                                        // Non-IP detected — show error with copy and switch-to-manual
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(settings.detectedGatewayIP)
                                                .font(.system(size: 13, design: .monospaced))
                                                .foregroundColor(colors.accentOrange)
                                            Text(err)
                                                .font(.system(size: 11))
                                                .foregroundColor(colors.accentRed)
                                            HStack(spacing: 8) {
                                                Button {
                                                    NSPasteboard.general.clearContents()
                                                    NSPasteboard.general.setString(settings.detectedGatewayIP, forType: .string)
                                                } label: {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "doc.on.doc").font(.system(size: 10))
                                                        Text("Copy").font(.system(size: 11, weight: .medium))
                                                    }
                                                    .foregroundColor(colors.accentBlue)
                                                }
                                                .buttonStyle(.plain)

                                                Button {
                                                    settings.gatewayMode = .manual
                                                } label: {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "pencil").font(.system(size: 10))
                                                        Text("Enter Manually").font(.system(size: 11, weight: .medium))
                                                    }
                                                    .foregroundColor(colors.accentBlue)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    } else {
                                        Text(settings.detectedGatewayIP.isEmpty ? "Detecting..." : settings.detectedGatewayIP)
                                            .font(.system(size: 13, design: .monospaced)).foregroundColor(colors.accentGreen)
                                    }
                                    Spacer()
                                    Button { settings.detectGateway() } label: {
                                        Image(systemName: "arrow.clockwise").foregroundColor(colors.secondaryText)
                                    }.buttonStyle(.plain)
                                }
                            } else {
                                GlassTextField(placeholder: "e.g. 192.168.1.1", text: $settings.manualGatewayIP, colors: colors)
                            }
                        }
                    }

                    // DNS
                    SettingsSectionView(title: "DNS Resolution", icon: "server.rack", colors: colors) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DNS Server for IP resolution").font(.system(size: 12)).foregroundColor(colors.secondaryText)
                            HStack(spacing: 8) {
                                GlassTextField(placeholder: "Leave empty for system default", text: $settings.dnsServer, colors: colors)
                                Button {
                                    settings.dnsServer = settings.effectiveGateway
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.turn.down.left").font(.system(size: 10))
                                        Text("Use Gateway").font(.system(size: 11, weight: .medium))
                                            .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                                    }
                                    .foregroundColor(colors.accentBlue)
                                    .padding(.horizontal, 10).padding(.vertical, 8)
                                    .background(colors.inputBg)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(colors.inputBorder, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                            Text("Leave empty to use system DNS. Or use your gateway IP for local resolution.")
                                .font(.system(size: 10))
                                .foregroundColor(colors.secondaryText.opacity(0.7))
                        }
                    }

                    // DNS Bypass (/etc/hosts)
                    SettingsSectionView(title: "DNS Bypass (Local Hosts)", icon: "doc.text.magnifyingglass", colors: colors) {
                        VStack(alignment: .leading, spacing: 14) {
                            GlassToggleRow(label: "Write domains to /etc/hosts", isOn: $settings.writeToHosts, colors: colors)

                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(colors.accentBlue)
                                Text("If excluded domains are not loading even after IP routing is applied, enable this option. It writes resolved IPs directly to /etc/hosts so your Mac can resolve them locally — bypassing VPN DNS completely.")
                                    .font(.system(size: 11))
                                    .foregroundColor(colors.secondaryText)
                                    .lineSpacing(3)
                            }

                            // VPN DNS servers detected
                            if !vpnDNSServers.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(colors.accentOrange)
                                        Text("VPN DNS Detected")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(colors.accentOrange)
                                    }
                                    Text(vpnDNSServers.joined(separator: ", "))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(colors.accentOrange)
                                    Text("Your VPN is overriding system DNS with the servers above. Excluded domains with locally-hosted nameservers may fail to resolve. Enable DNS Bypass to fix this.")
                                        .font(.system(size: 10))
                                        .foregroundColor(colors.secondaryText.opacity(0.7))
                                        .lineSpacing(2)
                                }
                                .padding(10)
                                .background(colors.accentOrange.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(colors.accentOrange.opacity(0.15), lineWidth: 1))
                            }

                            // Status indicator
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(hostsActive ? colors.accentGreen : colors.secondaryText)
                                    .frame(width: 7, height: 7)
                                Text(hostsActive ? "Hosts entries active" : "No hosts entries")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(hostsActive ? colors.accentGreen : colors.secondaryText)
                            }

                            // Show current /etc/hosts entries
                            if !hostsEntries.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Current /etc/hosts entries:")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(colors.secondaryText)
                                    VStack(alignment: .leading, spacing: 3) {
                                        ForEach(hostsEntries, id: \.self) { entry in
                                            Text(entry)
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(colors.accentGreen)
                                        }
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(colors.inputBg)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(colors.inputBorder, lineWidth: 1))
                                }
                            }

                            Text("When enabled, TunnelGuard adds entries like \"31.214.255.152 example.com\" to /etc/hosts when rules are applied, and removes them when rules are stopped. This is useful when your VPN overrides DNS settings and the excluded domain's nameservers are not reachable from the VPN's DNS server.")
                                .font(.system(size: 10))
                                .foregroundColor(colors.secondaryText.opacity(0.7))
                                .lineSpacing(3)
                        }
                    }

                    // Appearance
                    SettingsSectionView(title: "Appearance", icon: "paintpalette", colors: colors) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Theme").font(.system(size: 13)).foregroundColor(colors.primaryText.opacity(0.85))
                                Spacer()
                                TGSegmentedPicker(
                                    selection: $settings.themeMode,
                                    options: AppSettings.ThemeMode.allCases,
                                    label: { $0.rawValue },
                                    colors: colors
                                )
                                .frame(width: 220)
                            }
                        }
                    }

                    // Presence
                    SettingsSectionView(title: "App Presence", icon: "menubar.dock.rectangle", colors: colors) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Show app in").font(.system(size: 13)).foregroundColor(colors.primaryText.opacity(0.85))
                                Spacer()
                                TGSegmentedPicker(
                                    selection: $settings.presenceMode,
                                    options: AppSettings.PresenceMode.allCases,
                                    label: { $0.rawValue },
                                    colors: colors
                                )
                                .frame(width: 300)
                            }
                            Text("Menu Bar Only hides the Dock icon. Dock Only removes the menu bar icon.")
                                .font(.system(size: 11))
                                .foregroundColor(colors.secondaryText)
                        }
                    }

                    // Startup
                    SettingsSectionView(title: "Startup & Behavior", icon: "power", colors: colors) {
                        VStack(alignment: .leading, spacing: 14) {
                            GlassToggleRow(label: "Launch at system startup", isOn: $settings.runOnStartup, colors: colors)
                            GlassToggleRow(label: "Apply active rules on launch", isOn: $settings.applyOnLaunch, colors: colors)
                        }
                    }

                    // Admin Access
                    SettingsSectionView(title: "Admin Access", icon: "lock.shield", colors: colors) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(adminGranted ? colors.accentGreen : colors.accentOrange)
                                            .frame(width: 7, height: 7)
                                        Text(adminGranted ? "Admin access granted" : "Admin access not granted")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(colors.primaryText.opacity(0.85))
                                    }
                                    Text(adminGranted
                                         ? "Route commands run without password prompts."
                                         : "You'll be prompted for your password each time routes are applied.")
                                        .font(.system(size: 11))
                                        .foregroundColor(colors.secondaryText)
                                }
                                Spacer()
                                Button {
                                    if adminGranted {
                                        let (ok, msg) = PrivilegeHelper.revokeAdmin()
                                        adminGranted = !ok
                                        adminStatusMsg = msg
                                    } else {
                                        let (ok, msg) = PrivilegeHelper.grantAdmin()
                                        adminGranted = ok
                                        adminStatusMsg = msg
                                    }
                                    // Clear status after a few seconds
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) { adminStatusMsg = nil }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: adminGranted ? "lock.open.fill" : "lock.fill")
                                            .font(.system(size: 11))
                                        Text(adminGranted ? "Revoke" : "Grant Access")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(
                                        LinearGradient(
                                            colors: adminGranted
                                                ? [colors.accentOrange, colors.accentRed]
                                                : [Color(hex:"3b82f6"), Color(hex:"1d4ed8")],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }

                            if let msg = adminStatusMsg {
                                Text(msg)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(msg.contains("Error") ? colors.accentRed : colors.accentGreen)
                                    .transition(.opacity)
                            }

                            Text("This adds a sudoers entry for /sbin/route so TunnelGuard can modify routes without prompting. You can revoke it at any time.")
                                .font(.system(size: 11))
                                .foregroundColor(colors.secondaryText.opacity(0.7))
                                .lineSpacing(3)
                        }
                    }

                    // Save
                    Button { settings.save() } label: {
                        Text("Save Settings").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(LinearGradient(colors: [Color(hex:"3b82f6"), Color(hex:"1d4ed8")], startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: Color(hex:"3b82f6").opacity(0.4), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain).padding(.bottom, 28)
                }
                .padding(.horizontal, 24)
            }
        }
        .modifier(ToastOverlay(message: "Settings saved", icon: "checkmark.circle.fill", iconColor: colors.accentGreen, isShowing: showSavedToast, colors: colors))
        .onReceive(NotificationCenter.default.publisher(for: .settingsSaved)) { _ in
            withAnimation { showSavedToast = true }
            refreshHostsStatus()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation { showSavedToast = false } }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TunnelGuardHostsFileChanged"))) { _ in
            refreshHostsStatus()
        }
        .onAppear {
            refreshHostsStatus()
        }
        .environmentObject(settings)
    }

    private func refreshHostsStatus() {
        hostsActive = HostsFileManager.shared.hasHostsEntries()
        hostsEntries = HostsFileManager.shared.currentEntries()
        vpnDNSServers = HostsFileManager.detectVPNDNS()
    }
}

struct SettingsSectionView<Content: View>: View {
    let title: String
    let icon: String
    let colors: TGColors
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundColor(colors.accentBlue)
                Text(title.uppercased()).font(.system(size: 11, weight: .semibold)).foregroundColor(colors.secondaryText)
            }
            VStack(alignment: .leading, spacing: 14) { content }
                .padding(16)
                .background(colors.panelBg)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(colors.panelBorder, lineWidth: 1))
        }
    }
}

struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    let colors: TGColors

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, design: .monospaced))
            .foregroundColor(colors.primaryText)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(colors.inputBg)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(colors.inputBorder, lineWidth: 1))
    }
}

struct GlassToggleRow: View {
    let label: String
    @Binding var isOn: Bool
    let colors: TGColors

    var body: some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(colors.primaryText.opacity(0.85))
            Spacer()
            Toggle("", isOn: $isOn).toggleStyle(GlassToggleStyle(colors: colors))
        }
    }
}

// MARK: - Custom Segmented Picker (visible in light mode)
struct TGSegmentedPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [T]
    let label: (T) -> String
    let colors: TGColors

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection == option
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = option }
                } label: {
                    Text(label(option))
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? colors.primaryText : colors.secondaryText)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(isSelected ? colors.segmentSelectedBg : Color.clear)
                                .shadow(color: isSelected && !colors.isDark ? Color.black.opacity(0.08) : .clear, radius: 2, y: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(colors.segmentBg)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(colors.inputBorder, lineWidth: 1))
    }
}

// MARK: - About View
struct AboutView: View {
    let colors: TGColors

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(LinearGradient(colors: [Color(hex:"3b82f6"), Color(hex:"1d4ed8")], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 80, height: 80)
                            .shadow(color: Color(hex:"3b82f6").opacity(0.5), radius: 20, y: 8)
                        Image(systemName: "shield.lefthalf.filled").font(.system(size: 36, weight: .semibold)).foregroundColor(.white)
                    }
                    Text("TunnelGuard").font(.system(size: 26, weight: .black, design: .rounded)).foregroundColor(colors.primaryText)
                    Text("Version \(BundleInfo.version) (Build \(BundleInfo.build))").font(.system(size: 12)).foregroundColor(colors.secondaryText)
                    Text("macOS VPN Split-Tunnel Manager").font(.system(size: 14)).foregroundColor(colors.secondaryText)
                }
                .padding(.top, 32)

                VStack(spacing: 12) {
                    Text("DEVELOPER").font(.system(size: 10, weight: .semibold)).foregroundColor(colors.secondaryText)
                    HStack(spacing: 16) {
                        Circle()
                            .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                            .overlay(Text("A").font(.system(size: 18, weight: .black)).foregroundColor(.white))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Amirhossein Hosseinpour").font(.system(size: 15, weight: .semibold)).foregroundColor(colors.primaryText)
                            Text("AmirhpCom").font(.system(size: 12)).foregroundColor(colors.secondaryText)
                        }
                        Spacer()
                        HStack(spacing: 10) {
                            LinkButton(title: "Website", url: "https://amirhp.com/landing", icon: "globe", colors: colors)
                            LinkButton(title: "GitHub", url: "https://github.com/amirhp-com", icon: "chevron.left.forwardslash.chevron.right", colors: colors)
                        }
                    }
                    .padding(16)
                    .background(colors.panelBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(colors.panelBorder, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle").foregroundColor(colors.accentOrange).font(.system(size: 12))
                        Text("DISCLAIMER").font(.system(size: 10, weight: .semibold)).foregroundColor(colors.accentOrange.opacity(0.8))
                    }
                    Text("TunnelGuard modifies your system's routing table using macOS native commands. This requires administrator privileges. Improper use may affect network connectivity. The developer assumes no responsibility for network disruptions, data loss, or security incidents. Use at your own risk.")
                        .font(.system(size: 12)).foregroundColor(colors.secondaryText).lineSpacing(4)
                }
                .padding(16)
                .background(colors.accentOrange.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(colors.accentOrange.opacity(0.15), lineWidth: 1))

                HStack(spacing: 12) {
                    LinkButton(title: "Documentation & Help", url: "https://amirhp-com.github.io/tunnelguard/", icon: "questionmark.circle", colors: colors, fullWidth: true)
                    LinkButton(title: "Report Issue", url: "https://github.com/amirhp-com/tunnelguard/issues/new", icon: "ant.circle", colors: colors, fullWidth: true)
                }

                VStack(spacing: 4) {
                    Text("© 2026 Amirhossein Hosseinpour · AmirhpCom").font(.system(size: 11)).foregroundColor(colors.secondaryText.opacity(0.6))
                    Text("Copyleft — Free to use, modify, and distribute").font(.system(size: 11)).foregroundColor(colors.secondaryText.opacity(0.4))
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
    let colors: TGColors
    var fullWidth: Bool = false

    var body: some View {
        Button {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title).font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                if fullWidth { Spacer() }
            }
            .foregroundColor(colors.primaryText.opacity(0.75))
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(colors.panelBg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(colors.panelBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Toggle (light mode visible)
struct GlassToggleStyle: ToggleStyle {
    var colors: TGColors = TGColors(isDark: true)

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(configuration.isOn ? colors.toggleOnBg : colors.toggleOffBg)
                .frame(width: 44, height: 26)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(configuration.isOn ? Color.clear : colors.inputBorder, lineWidth: 1)
                )
            Circle()
                .fill(.white)
                .frame(width: 20, height: 20)
                .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                .offset(x: configuration.isOn ? 9 : -9)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isOn)
        }
        .onTapGesture { configuration.isOn.toggle() }
    }
}
