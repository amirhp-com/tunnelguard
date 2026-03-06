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
                .frame(minWidth: 800, minHeight: 620)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
        }
        .windowStyle(.hiddenTitleBar)
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
        button.image = NSImage(systemSymbolName: "shield.lefthalf.filled",
                               accessibilityDescription: "TunnelGuard")
        button.target = self
        button.action = #selector(menuBarButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func menuBarButtonClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            showMainWindow()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let header = NSMenuItem(title: "TunnelGuard v1.0.0", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let count = RouteManager.shared.activeRulesCount
        let statusLabel = NSMenuItem(
            title: "\(count) active rule\(count == 1 ? "" : "s")",
            action: nil, keyEquivalent: "")
        statusLabel.isEnabled = false
        menu.addItem(statusLabel)
        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "Open TunnelGuard", action: #selector(showMainWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let applyItem = NSMenuItem(title: "Apply All Rules", action: #selector(applyAllFromMenu), keyEquivalent: "")
        applyItem.target = self
        menu.addItem(applyItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit TunnelGuard", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        // Clear menu so left-click stays as showMainWindow
        DispatchQueue.main.async { self.statusItem?.menu = nil }
    }

    @objc func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let win = mainWindow ?? NSApp.windows.first(where: { !($0 is NSPanel) }) {
            win.makeKeyAndOrderFront(nil)
            mainWindow = win
        }
    }

    @objc private func applyAllFromMenu() {
        RouteManager.shared.applyAllActiveRules()
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
