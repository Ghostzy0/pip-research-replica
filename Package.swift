// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PipResearchReplica",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ResearchBaseline", targets: ["ResearchBaseline"])
    ],
    targets: [
        .target(name: "ResearchCore"),
        .target(name: "ResearchDesktop", dependencies: ["ResearchCore"]),
        .executableTarget(name: "ResearchBaseline", dependencies: ["ResearchDesktop"]),
        .testTarget(name: "ResearchCoreTests", dependencies: ["ResearchCore"]),
        .testTarget(name: "ResearchDesktopTests", dependencies: ["ResearchDesktop", "ResearchCore"])
    ],
    swiftLanguageModes: [.v5]
)
