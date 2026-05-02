import SwiftUI
struct EmptyStateView: View { let message:String; var body: some View { ContentUnavailableView(message, systemImage: "tray") }}
