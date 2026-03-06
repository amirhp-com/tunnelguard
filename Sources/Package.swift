// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TunnelGuard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TunnelGuard", targets: ["TunnelGuard"])
    ],
    targets: [
        .executableTarget(
            name: "TunnelGuard",
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-framework", "AppKit"])
            ]
        )
    ]
)
