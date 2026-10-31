// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Bloomin8Companion",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "Bloomin8Core", targets: ["Bloomin8Core"])
    ],
    targets: [
        .target(name: "Bloomin8Core"),
        .testTarget(name: "Bloomin8CoreTests", dependencies: ["Bloomin8Core"])
    ]
)
