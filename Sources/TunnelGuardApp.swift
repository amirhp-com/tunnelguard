import SwiftUI
import AppKit
import Foundation
import Combine

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
                        // Close any extra windows SwiftUI may have created
                        let contentWindows = NSApp.windows.filter { !($0 is NSPanel) }
                        if contentWindows.count > 1 {
                            // Keep only the first one, close extras
                            for win in contentWindows.dropFirst() {
                                win.close()
                            }
                        }
                        if let win = contentWindows.first {
                            win.styleMask.remove(.resizable)
                            win.standardWindowButton(.zoomButton)?.isEnabled = false
                            win.setContentSize(NSSize(width: 900, height: 620))
                            win.center()
                            // Set delegate to intercept window close
                            win.delegate = self.appDelegate
                            self.appDelegate.mainWindow = win
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 620)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        .handlesExternalEvents(matching: [])
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem?
    var mainWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

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

        // Log startup info
        RouteManager.shared.logStartupInfo()

        // Detect if routes from a previous session are still active
        RouteManager.shared.detectExistingRoutes()

        if RouteManager.shared.isRulesApplied {
            // Routes are already active from previous session — just update the UI state
            RouteManager.shared.log("Routes still active from previous session — ready to manage")
        } else if AppSettings.shared.applyOnLaunch {
            // No existing routes — apply fresh
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
            if self.mainWindow == nil {
                self.mainWindow = NSApp.windows.first(where: { !($0 is NSPanel) })
                self.mainWindow?.delegate = self
            }
        }

        // Add keyboard shortcut handler for ⌘W
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // ⌘W — hide window instead of closing
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
                if let win = self?.mainWindow ?? NSApp.windows.first(where: { !($0 is NSPanel) && $0.isVisible }) {
                    win.orderOut(nil)
                    return nil // consume the event
                }
            }
            return event
        }
    }

    // MARK: - NSWindowDelegate

    /// Intercept window close to hide instead of destroy — prevents SwiftUI state loss
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil) // hide the window
        return false         // prevent actual close
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Close any duplicate windows that SwiftUI may have created
        let contentWindows = NSApp.windows.filter { !($0 is NSPanel) }
        if contentWindows.count > 1 {
            for win in contentWindows where win != mainWindow {
                win.close()
            }
        }
        showMainWindow()
        return false  // false = we handled it, don't create a new window
    }

    // MARK: - Menu Bar Setup

    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }
        button.target = self
        button.action = #selector(menuBarButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateMenuBarIcon()

        // Observe isRulesApplied and update icon automatically
        RouteManager.shared.$isRulesApplied
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)
    }

    private func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }
        let symbolName = RouteManager.shared.isRulesApplied
        ? "network.badge.shield.half.filled"
        : "network"
        button.image = NSImage(systemSymbolName: symbolName,
                               accessibilityDescription: "TunnelGuard")
    }

    @objc private func menuBarButtonClicked(_ sender: NSStatusBarButton) {
        showContextMenu()
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
    static let hostsFileChanged      = Notification.Name("TunnelGuardHostsFileChanged")
}
