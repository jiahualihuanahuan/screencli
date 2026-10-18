// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScreenCLI",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "screencli", targets: ["ScreenCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "ScreenCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)
