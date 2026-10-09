// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FiscalQuarter",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "FiscalQuarterCore", targets: ["FiscalQuarterCore"]),
        .executable(name: "fq", targets: ["fq"]),
    ],
    targets: [
        .target(
            name: "FiscalQuarterCore",
            path: "FiscalQuarterCore"
        ),
        .executableTarget(
            name: "fq",
            dependencies: ["FiscalQuarterCore"],
            path: "FiscalQuarterCLI"
        ),
        .testTarget(
            name: "FiscalQuarterTests",
            dependencies: ["FiscalQuarterCore"],
            path: "FiscalQuarterTests"
        ),
    ]
)
