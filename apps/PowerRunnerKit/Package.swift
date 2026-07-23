// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PowerRunnerKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PowerEvidence", targets: ["PowerEvidence"]),
        .library(name: "PowerRunnerCore", targets: ["PowerRunnerCore"]),
        .library(name: "PowerTextProgram", targets: ["PowerTextProgram"]),
        .library(name: "PowerAppleTarget", targets: ["PowerAppleTarget"]),
        .library(name: "PowerMLXRuntime", targets: ["PowerMLXRuntime"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/ml-explore/mlx-swift-lm",
            exact: "3.31.4"
        ),
        .package(
            url: "https://github.com/huggingface/swift-huggingface",
            exact: "0.9.0"
        ),
        .package(
            url: "https://github.com/huggingface/swift-transformers",
            exact: "1.3.0"
        ),
    ],
    targets: [
        .target(name: "PowerEvidence"),
        .target(
            name: "PowerRunnerCore",
            dependencies: ["PowerEvidence"]
        ),
        .target(
            name: "PowerTextProgram",
            dependencies: ["PowerEvidence", "PowerRunnerCore"]
        ),
        .target(
            name: "PowerAppleTarget",
            dependencies: ["PowerEvidence", "PowerRunnerCore"]
        ),
        .target(
            name: "PowerMLXRuntime",
            dependencies: [
                "PowerEvidence",
                "PowerRunnerCore",
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Tokenizers", package: "swift-transformers"),
            ]
        ),
        .testTarget(
            name: "PowerEvidenceTests",
            dependencies: ["PowerEvidence"]
        ),
        .testTarget(
            name: "PowerRunnerCoreTests",
            dependencies: ["PowerEvidence", "PowerRunnerCore"]
        ),
        .testTarget(
            name: "PowerTextProgramTests",
            dependencies: ["PowerEvidence", "PowerRunnerCore", "PowerTextProgram"]
        ),
        .testTarget(
            name: "PowerAppleTargetTests",
            dependencies: ["PowerEvidence", "PowerRunnerCore", "PowerAppleTarget"]
        ),
        .testTarget(
            name: "PowerMLXRuntimeTests",
            dependencies: ["PowerEvidence", "PowerRunnerCore", "PowerMLXRuntime"]
        ),
    ]
)
