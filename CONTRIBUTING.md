# Contributing to TunnelGuard

Thanks for your interest in contributing! TunnelGuard is a native macOS app written in Swift — contributions of all sizes are welcome.

## Getting Started

### Prerequisites

- macOS 13.0+ (Ventura or later)
- Xcode 15.0+ with Command Line Tools
- Swift 5.9+

### Setup

```bash
git clone https://github.com/amirhp-com/tunnelguard.git
cd tunnelguard/source
open TunnelGuard.xcodeproj
```

Build with **Cmd+B** or from terminal:

```bash
make build
```

### Project Structure

```
Sources/
  TunnelGuardApp.swift   — App entry point, AppDelegate, menu bar, lifecycle
  Models.swift           — RouteManager, AppSettings, HostsFileManager, PrivilegeHelper
  Views.swift            — All SwiftUI views, theme system, custom components
```

## How to Contribute

1. **Fork** the repository
2. **Create a feature branch:** `git checkout -b feature/my-improvement`
3. **Make changes** and test on macOS
4. **Build successfully:** `make build`
5. **Open a Pull Request** with a clear description

### Commit Messages

Use descriptive commit messages:
- `fix: resolve gateway detection on M-series Macs`
- `feat: add CIDR notation support`
- `security: validate DNS server input`

### Code Style

- Follow existing patterns in the codebase
- Use Swift naming conventions (camelCase for variables/functions, PascalCase for types)
- Validate all user inputs before passing to shell commands
- Use `isSafeIPv4()` and `isSafeDomain()` for input validation
- Keep views, models, and app logic separated

### Security

- **Never** interpolate unsanitized user input into shell commands
- Use `shellQuote()` for path arguments
- Validate IPs with `isSafeIPv4()` before use in route commands
- Validate domains with `isSafeDomain()` before use in DNS commands

## Areas That Could Use Help

- **Subnet/CIDR support** — Add routes for entire subnets
- **IPv6 support** — Resolve AAAA records and add IPv6 routes
- **Multiple gateway profiles** — Switch between VPN setups
- **Automatic IP refresh** — Periodically re-resolve on a schedule
- **Homebrew cask** — Package for easy installation
- **Localization** — Translate UI strings
- **Accessibility** — VoiceOver labels and keyboard navigation
- **Unit tests** — Test input validation, URL cleaning, hosts file generation

## License

By contributing, you agree that your contributions will be licensed under the project's existing license.
