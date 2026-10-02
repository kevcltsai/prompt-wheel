// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PromptWheel",
    platforms: [.macOS("15.2")],
    products: [.executable(name: "PromptWheel", targets: ["PromptWheel"])],
    targets: [
        .target(name: "PromptWheelCore"),
        .executableTarget(name: "PromptWheel", dependencies: ["PromptWheelCore"]),
        // A dependency-free test runner also works with Command Line Tools alone.
        .executableTarget(name: "PromptWheelChecks", dependencies: ["PromptWheelCore"],
                          path: "Tests/PromptWheelChecks")
    ]
)
