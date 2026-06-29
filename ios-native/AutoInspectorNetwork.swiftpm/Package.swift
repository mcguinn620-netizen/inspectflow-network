// swift-tools-version: 5.9
// Swift Playgrounds 4.4+ / Xcode 15+ App package for Auto Inspector Network.
//
// Open `AutoInspectorNetwork.swiftpm` in Swift Playgrounds (iPad/macOS) or Xcode.
// This bundle reuses the App/Core/Features/Shared sources from the parent
// `ios-native/` folder. CarPlay, widget, and share-extension targets are
// intentionally excluded — Swift Playgrounds cannot build extension targets.
//
// See ios-native/PLAYGROUNDS.md for setup notes and known limitations.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "AutoInspectorNetwork",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .iOSApplication(
            name: "AutoInspectorNetwork",
            targets: ["AppHost"],
            bundleIdentifier: "com.inspectflow.autoinspector.playgrounds",
            teamIdentifier: "",
            displayVersion: "0.1",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .car),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            capabilities: [
                .camera(purposeString: "Capture inspection photos."),
                .photoLibrary(purposeString: "Attach photos to inspections."),
                .locationWhenInUse(purposeString: "Show your current job location."),
                .microphone(purposeString: "Record inspection voice notes.")
            ]
        )
    ],
    dependencies: [
        .package(name: "InspectFlowConnector", path: "..")
    ],
    targets: [
        .executableTarget(
            name: "AppHost",
            dependencies: [
                .product(name: "InspectFlowConnector", package: "InspectFlowConnector")
            ],
            path: "..",
            exclude: [
                "AutoInspectorNetwork.swiftpm",
                "AutoInspectorNetwork.xcodeproj",
                "AutoInspectorNetwork.xcworkspace",
                "AutoInspectorNetwork",
                "AgendaWidgetExtension",
                "InspectFlowShareExtension",
                "CarPlay",
                "Tests",
                "scripts",
                "docs",
                "Preview Content",
                "InspectFlowNative.playground",
                "Package.swift",
                "PLAYGROUNDS.md",
                "README.md",
                "project.yml",
                "Info.plist",
                "AutoInspectorNetwork.entitlements",
                "AutoInspectorNetworkRelease.entitlements",
                "AutoInspectorNetwork-Bridging-Header.h",
                ".codex",
                ".gitignore",
                "Core/InspectFlowConnector"
            ],
            sources: [
                "App",
                "Core",
                "Features",
                "Shared"
            ],
            resources: [
                .process("Assets.xcassets"),
                .process("AutoInspectorNetwork.xcdatamodeld"),
                .process("InspectionModel.xcdatamodeld")
            ]
        )
    ]
)
