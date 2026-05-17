// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PersonalAffairsApple",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "PersonalAffairsCore", targets: ["PersonalAffairsCore"]),
        .executable(name: "PersonalAffairsApp", targets: ["PersonalAffairsApp"])
    ],
    targets: [
        .target(
            name: "PersonalAffairsCore",
            path: "Sources/PersonalAffairsCore"
        ),
        .executableTarget(
            name: "PersonalAffairsApp",
            dependencies: ["PersonalAffairsCore"],
            path: "Sources/PersonalAffairsApp"
        ),
        .testTarget(
            name: "PersonalAffairsCoreTests",
            dependencies: ["PersonalAffairsCore"],
            path: "Tests/PersonalAffairsCoreTests"
        )
    ]
)

