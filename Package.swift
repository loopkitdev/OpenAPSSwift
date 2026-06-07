// swift-tools-version: 6.0
// Extracted from nightscout/Trio @ feat/dev-oref-swift.
// Trio is licensed AGPL-3.0; this extraction is therefore AGPL-3.0.
// Original source: Trio/Sources/APS/OpenAPSSwift/ plus the model + helper
// files it transitively references from Trio/Sources/{Models,Helpers}/.

import PackageDescription

let package = Package(
    name: "OpenAPSSwift",
    platforms: [
        .macOS(.v13),
        .iOS(.v15)
    ],
    products: [
        .library(name: "OpenAPSSwift", targets: ["OpenAPSSwift"]),
        .executable(name: "OpenAPSSwiftSmoke", targets: ["OpenAPSSwiftSmoke"])
    ],
    targets: [
        .target(
            name: "OpenAPSSwift",
            path: "Sources/OpenAPSSwift"
        ),
        .executableTarget(
            name: "OpenAPSSwiftSmoke",
            dependencies: ["OpenAPSSwift"],
            path: "Sources/OpenAPSSwiftSmoke"
        )
    ]
)
