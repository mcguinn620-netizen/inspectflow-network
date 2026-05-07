// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "InspectFlowNative",
    platforms: [.iOS(.v16)],
    products: [
        .iOSApplication(
            name: "InspectFlowNative",
            targets: ["AppModule"],
            bundleIdentifier: "com.inspectflow.native",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            iconAssetName: "AppIcon",
            accentColorAssetName: "AccentColor",
            supportedDeviceFamilies: [.phone, .pad],
            supportedInterfaceOrientations: [.portrait, .landscapeLeft, .landscapeRight]
        )
    ],
    targets: [
        .target(
            name: "AppModule",
            path: ".",
            exclude: [
                "Package.swift",
                "Config",
                "InspectFlowNative.xcodeproj",
                "README.md"
            ],
            resources: [.process("Resources")]
        )
    ]
)
