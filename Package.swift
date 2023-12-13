// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "URLMatch",
    products: [
        .library(name: "URLMatch", targets: ["URLMatch"]),
    ],
    targets: [
        .target(name: "URLMatch"),
        .testTarget(name: "URLMatchTests", dependencies: ["URLMatch"]),
    ]
)
