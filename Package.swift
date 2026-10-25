// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PortRadar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PortRadar", targets: ["PortRadar"])
    ],
    targets: [
        .executableTarget(
            name: "PortRadar",
            path: "Sources/PortRadar",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Carbon")
            ]
        )
    ]
)
