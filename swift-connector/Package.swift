// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "InspectFlowConnector",
    platforms: [.iOS(.v16), .macOS(.v12)],
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
