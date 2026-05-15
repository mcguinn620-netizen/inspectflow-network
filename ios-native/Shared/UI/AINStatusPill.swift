import SwiftUI

enum AINStatusTone {
    case pass, warn, fail, neutral, info

    var fg: Color {
        switch self {
        case .pass:    return AINTheme.Color.pass
        case .warn:    return AINTheme.Color.warn
        case .fail:    return AINTheme.Color.fail
        case .neutral: return AINTheme.Color.textSecondary
        case .info:    return AINTheme.Color.accent
        }
    }
    var bg: Color { fg.opacity(0.12) }
}

struct AINStatusPill: View {
    let label: String
    var tone: AINStatusTone = .neutral
    var icon: String? = nil

    var body: some View {
        HStack(spacing: AINTheme.Spacing.xs) {
            if let icon { Image(systemName: icon).font(.system(size: 11, weight: .semibold)) }
            Text(label).font(AINTheme.Font.caption(12)).fontWeight(.semibold)
        }
        .padding(.horizontal, AINTheme.Spacing.sm)
        .padding(.vertical, AINTheme.Spacing.xs + 1)
        .foregroundColor(tone.fg)
        .background(tone.bg, in: Capsule())
    }
}

extension AINStatusPill {
    /// Convenience for inspection / trip status strings.
    static func forStatus(_ status: String) -> AINStatusPill {
        switch status.lowercased() {
        case "pass", "complete", "completed", "approved":
            return AINStatusPill(label: status.capitalized, tone: .pass, icon: "checkmark.circle.fill")
        case "fail", "failed", "rejected":
            return AINStatusPill(label: status.capitalized, tone: .fail, icon: "xmark.octagon.fill")
        case "warn", "warning", "needs_attention", "paused":
            return AINStatusPill(label: status.capitalized, tone: .warn, icon: "exclamationmark.triangle.fill")
        case "active", "in_progress", "syncing":
            return AINStatusPill(label: status.capitalized, tone: .info, icon: "bolt.fill")
        default:
            return AINStatusPill(label: status.capitalized, tone: .neutral)
        }
    }
}
