import Foundation

/*:
 # InspectFlow Native iOS Playground

 Open this `InspectFlowNative.playground` bundle in Swift Playgrounds or Xcode to
 validate the native app onboarding flow before copying the app sources into a
 Swift Playgrounds App project.

 ## Swift Playgrounds App setup

 1. Create a new app in Swift Playgrounds.
 2. Add this repository as a Swift Package and choose the `InspectFlowConnector` product.
 3. Copy `ios-native/App`, `ios-native/Core`, `ios-native/Features`, and `ios-native/Shared` into the app.
 4. Skip `ios-native/CarPlay`, widget extensions, and share extensions because Swift Playgrounds does not run those targets.
 5. Add an empty Core Data model named `InspectionModel`, then run the app.
 */

struct PlaygroundChecklistItem: Identifiable {
    let id: Int
    let title: String
    let detail: String
}

let inspectFlowPlaygroundChecklist: [PlaygroundChecklistItem] = [
    .init(
        id: 1,
        title: "Add InspectFlowConnector",
        detail: "Use Package.swift from ios-native and select the InspectFlowConnector library product."
    ),
    .init(
        id: 2,
        title: "Copy app source folders",
        detail: "Bring App, Core, Features, and Shared into the Swift Playgrounds App project."
    ),
    .init(
        id: 3,
        title: "Skip unsupported extensions",
        detail: "Do not copy CarPlay, AgendaWidgetExtension, or InspectFlowShareExtension into Playgrounds."
    ),
    .init(
        id: 4,
        title: "Create InspectionModel",
        detail: "Add an empty Core Data model named InspectionModel so persistence references resolve."
    ),
]

for item in inspectFlowPlaygroundChecklist {
    print("\(item.id). \(item.title): \(item.detail)")
}
