// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "URLPattern",
    products: [
        .library(name: "URLPattern", targets: ["URLPattern"]),
    ],
    targets: [
        .target(name: "URLPattern"),
        .testTarget(name: "URLPatternTests", dependencies: ["URLPattern"]),
    ]
)
