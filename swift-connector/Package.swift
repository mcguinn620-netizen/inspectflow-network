// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "InspectFlowConnector",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v8)],
    products: [
        .library(name: "InspectFlowConnector", targets: ["InspectFlowConnector"])
    ],
    targets: [
        .target(name: "InspectFlowConnector", path: "Sources/InspectFlowConnector"),
        .testTarget(
            name: "InspectFlowConnectorTests",
            dependencies: ["InspectFlowConnector"],
            path: "Tests/InspectFlowConnectorTests"
        )
    ]
)
