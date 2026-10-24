// swift-tools-version: 6.0
// Extracted from nightscout/Trio v1.0.2: the algorithm file set of Trio's own AlgorithmPackage
// (branch enable-oref-as-non-testing-package @ 95cb8acf1, whose algorithm equals main @ 0b29cd534
// up to access control).
// Trio is licensed AGPL-3.0; this extraction is therefore AGPL-3.0.
// Original source: Trio/Sources/APS/OpenAPSSwift/ plus the model + helper
// files it transitively references from Trio/Sources/{Models,Helpers}/.

import PackageDescription

let package = Package(
    name: "OpenAPSSwift",
    platforms: [
        .macOS(.v14),
        .iOS("17.6")
    ],
    products: [
        .library(name: "OpenAPSSwift", targets: ["OpenAPSSwift"]),
        .executable(name: "OpenAPSSwiftSmoke", targets: ["OpenAPSSwiftSmoke"])
    ],
    targets: [
        .target(
            name: "OpenAPSSwift",
            path: "Sources/OpenAPSSwift",
            swiftSettings: [.define("TRIO_ALGORITHM_PACKAGE")]
        ),
        // Trio's own algorithm tests (TrioTests/OpenAPSSwiftTests at the same commit), run against
        // this extraction. They import `Trio`; the alias points that at this module.
        .testTarget(
            name: "OpenAPSSwiftTests",
            dependencies: ["OpenAPSSwift"],
            path: "Tests/OpenAPSSwiftTests",
            exclude: ["Parity/goldens"],
            resources: [.copy("json")],
            swiftSettings: [.unsafeFlags(["-module-alias", "Trio=OpenAPSSwift"])]
        ),
        .executableTarget(
            name: "OpenAPSSwiftSmoke",
            dependencies: ["OpenAPSSwift"],
            path: "Sources/OpenAPSSwiftSmoke"
        )
    ],
    swiftLanguageModes: [.v5]
)
