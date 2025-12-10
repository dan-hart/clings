// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "clings",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "clings", targets: ["ClingsCLI"]),
        .library(name: "ClingsCore", targets: ["ClingsCore"])
    ],
    dependencies: [
        // CLI framework (Apple's official)
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        // SQLite for local database (sessions, cache, stats)
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0"),
        // Date parsing (natural language dates)
        .package(url: "https://github.com/malcommac/SwiftDate.git", from: "7.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "ClingsCLI",
            dependencies: [
                "ClingsCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(
            name: "ClingsCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "SwiftDate", package: "SwiftDate")
            ]
        ),
        .testTarget(
            name: "ClingsCoreTests",
            dependencies: ["ClingsCore"]
        ),
        .testTarget(
            name: "ClingsCLITests",
            dependencies: ["ClingsCLI"]
        )
    ]
)
