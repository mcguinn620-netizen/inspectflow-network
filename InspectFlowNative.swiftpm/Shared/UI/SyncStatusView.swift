import SwiftUI

struct SyncStatusView: View {
    @EnvironmentObject private var syncEngine: SyncEngine

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }

    private var color: Color {
        switch syncEngine.state {
        case .idle: return .green
        case .syncing: return .blue
        case .offline: return .orange
        case .failed: return .red
        }
    }

    private var label: String {
        switch syncEngine.state {
        case .idle: return "Synced"
        case .syncing: return "Syncing"
        case .offline: return "Offline"
        case .failed: return "Sync Failed"
        }
    }
}
