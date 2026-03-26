# Changelog

All notable changes to TunnelGuard are documented in this file.

## [2.6.0] — 2026-03-26

### Security
- **Input sanitization** — All shell command inputs (IPs, domains, DNS server, paths) are now validated before interpolation into shell commands. Added `isSafeIPv4`, `isSafeDomain`, and `shellQuote` helpers.
- **AppleScript escaping** — Fixed incomplete escaping in `PrivilegeHelper.runAsAdmin()` — now escapes `$` and backticks in addition to `\` and `"`.
- **Sudoers entry restricted** — Changed from `ALL=(ALL)` to `ALL=(root)` with path-specific argument restrictions for `cp`, `chmod`, `chown` (limited to `/etc/hosts` only).
- **Secure temp files** — Replaced predictable timestamp-based temp filenames with UUID-based names to prevent TOCTOU attacks.
- **Hardened Runtime** — Enabled macOS Hardened Runtime in Xcode project settings.
- **Gateway validation** — Invalid gateway values (e.g., `link#28`) are no longer stored in `detectedGatewayIP`.

### Added
- **Network change detection** — Monitors network reachability via `SCNetworkReachability`. Auto re-detects gateway and re-applies rules when network changes (VPN connect/disconnect, Wi-Fi switch).
- **Import/Export rules** — Export rules as JSON for backup or sharing. Import from JSON file with duplicate detection.
- **Keyboard shortcuts** — `Cmd+N` (new rule), `Cmd+Shift+R` (apply/stop), `Cmd+1/2/3` (tab switch).
- **Rule filtering** — Filter rules by status: All, Active, Paused.
- **Rule sorting** — Sort by Domain (alpha), Date (newest first), or IP count.
- **Rule duplication** — Duplicate button in rule row actions.
- **Persistent log file** — Logs written to `~/Library/Logs/TunnelGuard/tunnelguard.log` with 1MB rotation.
- **Hosts file backup** — Creates `/tmp/tunnelguard_hosts_backup` before every `/etc/hosts` modification.
- **Confirmation dialogs** — Clear logs and admin grant/revoke now require confirmation.
- **Apply button loading state** — Spinner and "Applying..." text while rules are being applied, button disabled to prevent double-clicks.
- **DNS server validation** — Inline validation error shown for invalid DNS server IP in Settings.
- **Gateway IP validation** — Inline validation error shown for invalid manual gateway IP.
- **Manual IP validation** — Invalid IPs are rejected with error message showing which IPs are invalid.
- **Domain format validation** — Only alphanumeric characters, dots, and hyphens accepted (RFC 1035).
- **Duplicate domain prevention** — Cannot add a rule for a domain that already exists.

### Improved
- **EditRuleSheet** — Now shows validation errors, validates domain format and manual IPs, auto re-resolves IPs when domain name is changed, shows loading state during re-resolution.
- **URL auto-cleaning** — Pasted URLs automatically cleaned: strips protocol, path, query, fragment, port, and `www.` prefix.
- **Hot-add domains** — New domains auto-apply routes and hosts entries when rules are already active.

## [2.0.0] — 2026-03-07

### Added
- **DNS Bypass (`/etc/hosts`)** — Write resolved IPs to `/etc/hosts` with TunnelGuard markers, bypassing VPN DNS.
- **VPN DNS detection** — Shows VPN-pushed DNS servers with warning when override is detected.
- **Current hosts entries display** — Real-time view of `/etc/hosts` entries.
- **DNS cache flush** — Automatic `dscacheutil -flushcache` after hosts file changes.
- **Route state persistence** — Applied/stopped state saved to UserDefaults.
- **Existing route detection** — Checks `netstat -nr` on startup for routes from previous session.
- **Startup diagnostics** — Logs version, rules, gateway, DNS, hosts status on launch.
- **Non-blocking operations** — Route commands run on background thread.
- **Expanded admin access** — Sudoers entry covers hosts file management commands.

### Fixed
- Delete confirmation stays on Rules tab.
- Single window enforcement on dock icon click.

## [1.9.5] — 2026-03-07

### Improved
- Menu-bar icon changes dynamically based on rules state.
- Sidebar status badge with live rule count.
- Context menu reflects active/inactive state.

## [1.9.0] — 2026-03-06

### Added
- Admin access grant/revoke from Settings.
- Smart DNS resolution with system default fallback.
- Gateway IP validation with manual entry option.
- Apply/Stop toggle with color indication.
- Toast notifications for all operations.
- Edit rules inline.
- Manual IP entry with "M" badge.
- Multiple IP support per domain.
- Delete confirmation dialog.
- Single instance enforcement.
- Full command logging.

### Fixed
- `dig` bind error with explicit DNS server and nslookup fallback.
- `osascript` admin prompt blocked by App Sandbox (sandbox removed).
- Add Rule button resize during loading.

## [1.0.0] — 2026-03-06

### Added
- Initial release.
- Domain-based VPN split-tunnel routing.
- Auto IP resolution via `dig`.
- Gateway auto-detection.
- Rule toggle, refresh, delete.
- Activity log with color-coded output.
- Menu bar integration.
- Launch at startup with auto-apply.
- Dark theme with liquid glass UI.
