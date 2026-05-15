import SwiftUI

/// Elevated card surface used as the primary content container.
struct AINCard<Content: View>: View {
    var padding: CGFloat = AINTheme.Spacing.lg
    var background: Color = AINTheme.Color.surface
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: AINTheme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AINTheme.Radius.lg, style: .continuous)
                    .stroke(AINTheme.Color.border, lineWidth: 0.5)
            )
            .ainShadow()
    }
}

struct AINSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: AINTheme.Spacing.xxs) {
                Text(title)
                    .font(AINTheme.Font.headline())
                    .foregroundColor(AINTheme.Color.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(AINTheme.Font.caption())
                        .foregroundColor(AINTheme.Color.textSecondary)
                }
            }
            Spacer(minLength: AINTheme.Spacing.sm)
            trailing
        }
    }
}
