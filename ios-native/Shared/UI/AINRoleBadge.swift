import SwiftUI

#if DEBUG
struct AINRoleBadge: View {
    let role: String

    private var group: DebugRoleGroup { DebugRoleGroup.from(role) }

    private var color: Color {
        switch group {
        case .admin:      return Color(red: 0.95, green: 0.32, blue: 0.40) // red
        case .manager:    return Color(red: 0.60, green: 0.40, blue: 0.85) // purple
        case .dispatcher: return AINTheme.Color.accent                     // blue
        case .inspector:  return AINTheme.Color.pass                       // green
        case .client:     return AINTheme.Color.neutral                    // slate
        }
    }

    private var label: String {
        role.split(separator: "_").map { $0.capitalized }.joined(separator: " ")
    }

    var body: some View {
        Text(label)
            .font(AINTheme.Font.caption(11))
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundColor(color)
            .background(color.opacity(0.15), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
    }
}
#endif
