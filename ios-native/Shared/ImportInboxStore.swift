//
//  ImportInboxStore.swift
//  AutoInspectorNetwork
//
//  Created by Matt McGuinn on 6/11/26.
//

import Foundation

@MainActor
final class ImportInboxStore: ObservableObject {

    @Published var imports: [SharedImport] = []

    func load() {

        let defaults = UserDefaults(
            suiteName: "group.com.inspectflow.shared"
        )

        guard let raw =
            defaults?.array(
                forKey: "sharedImports"
            ) as? [Data]
        else {
            return
        }

        let decoder = JSONDecoder()

        imports = raw.compactMap {
            try? decoder.decode(
                SharedImport.self,
                from: $0
            )
        }
    }

    func clear() {

        let defaults = UserDefaults(
            suiteName: "group.com.inspectflow.shared"
        )

        defaults?.removeObject(
            forKey: "sharedImports"
        )

        imports.removeAll()
    }
}
