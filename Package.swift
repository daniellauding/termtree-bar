// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TermtreeBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TermtreeBar", targets: ["TermtreeBar"]),
    ],
    targets: [
        .executableTarget(
            name: "TermtreeBar",
            path: "Sources/TermtreeBar"
        ),
    ]
)
