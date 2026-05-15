import SwiftUI

struct AINEmptyState: View {
    let title: String
    var message: String? = nil
    var systemImage: String = "tray"
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AINTheme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundColor(AINTheme.Color.textTertiary)
            Text(title)
                .font(AINTheme.Font.headline())
                .foregroundColor(AINTheme.Color.textPrimary)
            if let message {
                Text(message)
                    .font(AINTheme.Font.body(14))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AINTheme.Color.textSecondary)
                    .padding(.horizontal, AINTheme.Spacing.xl)
            }
            if let actionLabel, let action {
                AINPrimaryButton(actionLabel, action: action).fixedSize()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AINTheme.Spacing.xxl)
    }
}

struct AINErrorState: View {
    let message: String
    var retry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AINTheme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(AINTheme.Color.fail)
            Text("Something went wrong")
                .font(AINTheme.Font.headline())
            Text(message)
                .font(AINTheme.Font.caption(13))
                .foregroundColor(AINTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AINTheme.Spacing.xl)
            if let retry {
                AINSecondaryButton("Try again", action: retry).fixedSize()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AINTheme.Spacing.xl)
    }
}

struct AINLoadingState: View {
    var label: String = "Loading…"
    var body: some View {
        VStack(spacing: AINTheme.Spacing.sm) {
            ProgressView().tint(AINTheme.Color.accent)
            Text(label).font(AINTheme.Font.caption()).foregroundColor(AINTheme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AINTheme.Spacing.xl)
    }
}

/// Skeleton placeholder block with a subtle shimmer.
struct AINSkeleton: View {
    var height: CGFloat = 14
    var cornerRadius: CGFloat = 6
    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(AINTheme.Color.surfaceMuted)
            .frame(height: height)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, AINTheme.Color.border.opacity(0.6), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.5)
                    .offset(x: phase * geo.size.width)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}
