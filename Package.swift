// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Moss",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Moss", targets: ["Moss"])
    ],
    targets: [
        .executableTarget(
            name: "Moss",
            path: "Sources/Moss"
        ),
    ]
)
