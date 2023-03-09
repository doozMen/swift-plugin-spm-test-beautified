// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-plugin-spm-test-beautified",
    products: [
        .plugin(name: "SPMTestBeautified", targets: ["SPMTestBeautified"])
    ],
    dependencies: [],
    targets: [
        .plugin(
            name: "SPMTestBeautified",
            capability: .command(intent:
                    .custom(
                        verb: "spm-test-beautified",
                        description: "Holds all test output until the end. Then lists failed tests only"))),
        .target(name: "FooLib"),
        .testTarget(
            name: "SPMTestBeautifiedTests",
            dependencies: ["FooLib"]),
    ]
)
