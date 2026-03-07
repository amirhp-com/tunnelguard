import SwiftUI
import AppKit
import Foundation

// MARK: - App Entry Point
@main
struct TunnelGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 900, height: 620)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                    // Lock window size and disable zoom/maximize
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let win = NSApp.windows.first(where: { !($0 is NSPanel) }) {
                            win.styleMask.remove(.resizable)
                            win.standardWindowButton(.zoomButton)?.isEnabled = false
                            win.setContentSize(NSSize(width: 900, height: 620))
                            win.center()
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 620)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ── Single-instance enforcement ──
        let bundleID = Bundle.main.bundleIdentifier ?? "com.amirhpcom.tunnelguard"
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == bundleID
        }
        if running.count > 1 {
            // Another instance is already running — activate it and quit this one
            if let other = running.first(where: { $0 != NSRunningApplication.current }) {
                other.activate()
            }
            NSApp.terminate(nil)
            return
        }

        setupMenuBarItem()
        RouteManager.shared.loadRules()

        // Apply saved presence mode immediately
        applyPresencePolicy()

        if AppSettings.shared.applyOnLaunch {
            RouteManager.shared.applyAllActiveRules()
        }

        // Listen for dock visibility changes triggered from Settings view
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDockSettingChanged(_:)),
            name: .dockVisibilityChanged,
            object: nil
        )

        // Grab main window reference once SwiftUI creates it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.mainWindow = NSApp.windows.first(where: { !($0 is NSPanel) })
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    // MARK: - Menu Bar Setup

    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: RouteManager.shared.isRulesApplied ? "network" : "network.badge.shield.half.filled",
                               accessibilityDescription: "TunnelGuard")
        button.target = self
        button.action = #selector(menuBarButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func menuBarButtonClicked(_ sender: NSStatusBarButton) {
        showContextMenu()
//        if NSApp.currentEvent?.type == .rightMouseUp {
//            showContextMenu()
//        } else {
//            showMainWindow()
//        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let count = RouteManager.shared.activeRulesCount
        
        let openItem = NSMenuItem(title: "Open TunnelGuard", action: #selector(showMainWindow), keyEquivalent: "")
        openItem.target = self
        openItem.image = NSImage(systemSymbolName: "shield.lefthalf.filled", accessibilityDescription: "App Icon")
        menu.addItem(openItem)
    

        let applyItem = NSMenuItem(title: RouteManager.shared.isRulesApplied ? "Stop Rules" : "Apply Rules", action: #selector(toggleFromMenu), keyEquivalent: "")
        applyItem.target = self
        applyItem.image = NSImage(systemSymbolName: RouteManager.shared.isRulesApplied ? "stop.fill" : "play.fill", accessibilityDescription: "Setting Icon")
        menu.addItem(applyItem)

        
        menu.addItem(.separator())
       
        let statusLabel = NSMenuItem( title: "\(count) active rule\(count == 1 ? "" : "s")", action: nil, keyEquivalent: "")
        statusLabel.isEnabled = false
        menu.addItem(statusLabel)
        
        let header = NSMenuItem(title: "TunnelGuard v\(version) (\(build))", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        DispatchQueue.main.async { self.statusItem?.menu = nil }
    }

    @objc func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let win = mainWindow ?? NSApp.windows.first(where: { !($0 is NSPanel) }) {
            win.styleMask.remove(.resizable)
            win.standardWindowButton(.zoomButton)?.isEnabled = false
            win.makeKeyAndOrderFront(nil)
            mainWindow = win
        }
    }

    @objc private func applyAllFromMenu() {
        RouteManager.shared.applyAllActiveRules()
    }
    @objc private func toggleFromMenu() {
        if RouteManager.shared.isRulesApplied {
            return RouteManager.shared.stopAllRules()
        }else{
            return RouteManager.shared.applyAllActiveRules()
        }
    }
    @objc private func stopAllFromMenu() {
        RouteManager.shared.stopAllRules()
    }

    // MARK: - Dock / MenuBar Visibility

    func applyPresencePolicy() {
        let mode = AppSettings.shared.presenceMode
        DispatchQueue.main.async {
            switch mode {
            case .menuBarOnly:
                NSApp.setActivationPolicy(.accessory)
                self.statusItem?.isVisible = true
            case .dockOnly:
                NSApp.setActivationPolicy(.regular)
                self.statusItem?.isVisible = false
            case .both:
                NSApp.setActivationPolicy(.regular)
                self.statusItem?.isVisible = true
            }
        }
    }

    func applyDockPolicy(show: Bool) {
        applyPresencePolicy()
    }

    @objc private func handleDockSettingChanged(_ notification: Notification) {
        applyPresencePolicy()
    }
}

// MARK: - Shared Notification Names
extension Notification.Name {
    static let dockVisibilityChanged = Notification.Name("TunnelGuardDockVisibilityChanged")
    static let settingsSaved         = Notification.Name("TunnelGuardSettingsSaved")
}
