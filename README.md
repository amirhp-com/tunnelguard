# 🛡️ TunnelGuard

**macOS VPN Split-Tunnel Manager** — Exclude specific domains from your VPN tunnel with a clean, native macOS interface.

> Version 1.0.0 · Released 2026-03-06 | 1404-12-15
> Developer: [Amirhossein Hosseinpour (AmirhpCom)](https://amirhp.com/landing)
> GitHub: [github.com/amirhp-com](https://github.com/amirhp-com/tunnelguard)
> Inspired by: [a post on dev.to by @vavilov2212](https://dev.to/vavilov2212/routing-only-specific-subnets-through-vpn-split-tunneling-on-macos-2aig)

---

## What is TunnelGuard?

When you connect to a VPN, all your traffic is routed through it — including traffic to services that work fine without it (or break because of it). TunnelGuard gives you fine-grained control over your VPN routing by letting you specify domains whose traffic should bypass the VPN and use your regular internet connection instead.

This is commonly called **split tunneling**. macOS doesn't expose this natively in its VPN UI, but the underlying `route` command makes it possible. TunnelGuard automates it with a beautiful, persistent interface.

---

## Features

- **Domain-based exclusions** — Enter a domain name and TunnelGuard resolves its IPs and adds bypass routes automatically
- **Auto IP Resolution** — Uses DNS to discover all IPs for a given domain
- **Gateway Auto-detection** — Detects your local default gateway or lets you specify one manually
- **Toggle rules on/off** — Pause a rule without deleting it
- **Refresh IPs** — Re-resolve a domain's IPs at any time (useful when IPs change)
- **Activity log** — Full log of all route operations
- **Launch at startup** — Runs as a LaunchAgent and applies your rules at login
- **Menu bar integration** — Lives in your menu bar, out of the way
- **Liquid Glass UI** — Follows macOS design language with dark, translucent aesthetics

---

## How It Works

TunnelGuard uses macOS's built-in `route` command to add explicit routing entries:

```bash
# When you add a domain:
# 1. Resolve domain → IPs
dig +short example.com A

# 2. Add a route via your local gateway (bypassing VPN)
sudo route -n add <resolved-ip> <local-gateway>

# When you remove/disable a rule:
sudo route -n delete <ip>
```

This tells your Mac: "For traffic to this IP, use the local gateway — not the VPN."

**Important:** These routes are session-based. They reset on reboot unless TunnelGuard is set to launch at startup and apply rules on launch (both enabled by default).

---

## Requirements

- macOS 13.0 Ventura or later
- Xcode 15.0+ (to build from source)
- Swift 5.9+
- Admin privileges (for `sudo route` commands)

---

## Installation

### Option A: Pre-built Binary

1. Download the latest release from [Releases](https://github.com/amirhp-com/tunnelguard/releases)
2. Move `TunnelGuard.app` to your `/Applications` folder
3. Right-click → Open (first launch requires Gatekeeper bypass for unsigned apps)
4. Grant permission when prompted for admin access

### Option B: Build from Source

See [Building from Source](#building-from-source) below.

---

## Usage Guide

### Adding Your First Rule

1. Launch TunnelGuard
2. Click **"Add Domain"** in the sidebar or the `+` button
3. Enter the domain (e.g., `office.company.com`, `internal.example.org`)
4. Optionally add a note to remember what this rule is for
5. Click **"Add & Resolve"** — TunnelGuard resolves the domain's IPs and adds routing rules
6. Click **"Apply Rules"** in the sidebar to activate all enabled rules

### Gateway Configuration

By default, TunnelGuard detects your local gateway automatically using:

```bash
netstat -nr | grep default | grep -v ':' | head -1 | awk '{print $2}'
```

If this is incorrect (e.g., you have multiple network interfaces), go to **Settings → VPN Gateway → Manual** and enter your gateway IP (usually `192.168.x.1`).

### Toggling Rules

Each rule has an on/off toggle. Disabling a rule removes its routes immediately. Re-enabling it re-adds them. This is useful for temporarily routing a domain through the VPN without deleting the rule.

### Refreshing IPs

Some services use CDNs or rotate IPs frequently. Click the ↻ refresh icon next to a rule to re-resolve its IPs and update the routes.

### Startup Behavior

Go to **Settings** to configure:

| Setting | Description |
|---------|-------------|
| Launch at startup | Installs a LaunchAgent to start TunnelGuard at login |
| Apply rules on launch | Automatically runs all enabled rules when the app starts |

### Sudoers Configuration (Optional)

For passwordless operation, add the following to `/etc/sudoers` via `sudo visudo`:

```
%admin ALL=(ALL) NOPASSWD: /sbin/route
```

Without this, macOS will prompt for your password each time routes are modified.

---

## Settings Reference

| Setting | Default | Description |
|---------|---------|-------------|
| Gateway Mode | Automatic | Auto-detect or manually specify local gateway |
| Manual Gateway IP | — | Used when mode is Manual |
| DNS Server | 8.8.8.8 | DNS server for resolving domain IPs |
| Launch at startup | Off | Register as a system LaunchAgent |
| Apply rules on launch | On | Run active rules when app opens |
| Show in Dock | On | Whether app appears in macOS Dock |

---

## Building from Source

### Prerequisites

```bash
xcode-select --install   # Install Command Line Tools
```

### Clone & Build

```bash
git clone https://github.com/amirhp-com/tunnelguard.git
cd tunnelguard

# Build using Swift Package Manager
swift build -c release

# Output binary
.build/release/TunnelGuard
```

### Build the .app Bundle

```bash
# 1. Build release binary
swift build -c release

# 2. Create app bundle structure
mkdir -p TunnelGuard.app/Contents/MacOS
mkdir -p TunnelGuard.app/Contents/Resources

# 3. Copy binary
cp .build/release/TunnelGuard TunnelGuard.app/Contents/MacOS/

# 4. Copy Info.plist
cp TunnelGuard.app/Contents/Info.plist TunnelGuard.app/Contents/Info.plist

# 5. (Optional) Code sign
codesign --force --deep --sign - TunnelGuard.app

# 6. Move to Applications
cp -r TunnelGuard.app /Applications/
```

### Open in Xcode

```bash
swift package generate-xcodeproj
open TunnelGuard.xcodeproj
```

---

## Customizing Your Build

TunnelGuard is designed to be forkable and customizable:

### Change App Identity

In `Sources/Models.swift`, update `AppSettings`:
```swift
// Change the LaunchAgent identifier
"com.yourname.tunnelguard"
```

In `TunnelGuard.app/Contents/Info.plist`:
```xml
<key>CFBundleIdentifier</key>
<string>com.yourname.tunnelguard</string>
```

### Change Default DNS Server

In `Sources/Models.swift`:
```swift
@Published var dnsServer: String = "1.1.1.1"  // Cloudflare instead of Google
```

### Modify Route Commands

In `Sources/Models.swift`, `RouteManager.applyRoutes()`:
```swift
// Default: adds a host route
let result = shell("sudo route -n add \(ip) \(gw) 2>&1")

// For subnet routing, you might use:
let result = shell("sudo route -n add -net \(subnet)/24 \(gw) 2>&1")
```

---

## Contributing

Contributions are welcome. Here's how:

1. **Fork** the repository on GitHub
2. **Create a branch** for your feature or fix:
   ```bash
   git checkout -b feature/my-improvement
   ```
3. **Make your changes** — keep commits focused and well-described
4. **Test on macOS** — verify routing behavior works as expected
5. **Open a Pull Request** with a clear description of what changed and why

### Areas That Could Use Help

- **Icon design** — A proper macOS app icon (.icns)
- **Subnet/CIDR support** — Add routes for entire subnets
- **Multiple gateway profiles** — Switch between different VPN setups
- **Automatic IP refresh** — Periodically re-resolve domains on a schedule
- **Import/Export** — Export rules as JSON for sharing or backup
- **Homebrew cask** — Package for easy installation

---

## Disclaimer

TunnelGuard modifies your system's routing table using macOS native commands. This requires administrator privileges. Improper configuration may disrupt your network connectivity.

The developer assumes **no responsibility** for:
- Network disruptions or connectivity loss
- Security incidents arising from bypass routing
- Data loss or corruption
- Any consequences of using this software

This tool is intended for **advanced users** who understand network routing. Always verify your configuration in the Activity Log. Routes added by TunnelGuard do not persist across reboots unless the startup option is enabled.

**Never use this tool to bypass security controls you are required to comply with.**

---

## License

```
Copyleft (c) 2026 Amirhossein Hosseinpour (AmirhpCom)

This work is free. You can redistribute it and/or modify it under the
terms of the Do What The Fuck You Want To Public License, Version 2,
as published by Sam Hocevar. Attribution to the original author is
appreciated but not required.

            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
                    Version 2, December 2004

 Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>

 Everyone is permitted to copy and distribute verbatim or modified
 copies of this license document, and changing it is allowed as long
 as the name is changed.

            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

  0. You just DO WHAT THE FUCK YOU WANT TO.
```

---

## Acknowledgments

Built on macOS's native routing infrastructure. The split-tunneling technique uses `route(8)` and `netstat(1)`, standard UNIX network utilities available on every Mac.

---

*TunnelGuard — Because your VPN shouldn't be your whole network.*
