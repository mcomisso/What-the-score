// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WhatScoreKit",
    platforms: [.iOS(.v17), .watchOS(.v11)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "WhatScoreKit",
            targets: ["WhatScoreKit"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "WhatScoreKit",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "WhatScoreKitTests",
            dependencies: ["WhatScoreKit"]
        ),
    ]
)
