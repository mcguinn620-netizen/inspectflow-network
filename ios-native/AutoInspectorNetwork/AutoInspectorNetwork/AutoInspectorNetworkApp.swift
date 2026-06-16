//
//  AutoInspectorNetworkApp.swift
//  AutoInspectorNetwork
//
//  Created by Matt McGuinn on 6/15/26.
//

import SwiftUI

@main
struct AutoInspectorNetworkApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
