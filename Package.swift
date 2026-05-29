// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Mira",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Mira", targets: ["Mira"])
    ],
    targets: [
        .executableTarget(
            name: "Mira"
        )
    ]
)
