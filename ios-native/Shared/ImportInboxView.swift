//
//  ImportInboxView.swift
//  AutoInspectorNetwork
//
//  Created by Matt McGuinn on 6/11/26.
//

import SwiftUI
import Foundation

struct ImportInboxView: View {

    @StateObject
    private var store = ImportInboxStore()

    var body: some View {

        List(store.imports) { item in

            VStack(alignment: .leading) {

                Text(item.title)

                Text(item.kind.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Imports")
        .task {
            store.load()
        }
    }
}
