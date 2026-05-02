import SwiftUI
struct TrayBarView: View { @EnvironmentObject var store:AppStore; var body: some View { Text("Tray: \(store.tray.count) items") }}
