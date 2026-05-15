import SwiftUI

struct SyncStatusView: View {
    @EnvironmentObject private var syncEngine: SyncEngine

    var body: some View {
        AINStatusPill(label: label, tone: tone, icon: icon)
    }

    private var tone: AINStatusTone {
        switch syncEngine.state {
        case .idle:    return .pass
        case .syncing: return .info
        case .offline: return .warn
        case .failed:  return .fail
        }
    }

    private var icon: String {
        switch syncEngine.state {
        case .idle:    return "checkmark.circle.fill"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .offline: return "wifi.slash"
        case .failed:  return "exclamationmark.triangle.fill"
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
