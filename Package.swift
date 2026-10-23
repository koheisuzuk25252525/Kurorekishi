// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "Chronicle",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "ChronicleCore", targets: ["ChronicleCore"])],
    targets: [
        .target(name: "ChronicleCore", resources: [.process("Resources")]),
        .testTarget(name: "ChronicleCoreTests", dependencies: ["ChronicleCore"], resources: [.process("Fixtures")])
    ]
)
