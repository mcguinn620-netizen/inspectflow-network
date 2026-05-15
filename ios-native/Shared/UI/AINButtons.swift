import SwiftUI

struct AINPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, isLoading: Bool = false, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title; self.systemImage = systemImage
        self.isLoading = isLoading; self.isDisabled = isDisabled; self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AINTheme.Spacing.sm) {
                if isLoading {
                    ProgressView().tint(AINTheme.Color.textOnAccent)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title).font(AINTheme.Font.bodyEmphasized())
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(AINTheme.Color.accent)
            .foregroundColor(AINTheme.Color.textOnAccent)
            .clipShape(RoundedRectangle(cornerRadius: AINTheme.Radius.md, style: .continuous))
            .opacity(isDisabled ? 0.55 : 1)
        }
        .disabled(isDisabled || isLoading)
    }
}

struct AINSecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title; self.systemImage = systemImage; self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AINTheme.Spacing.sm) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(AINTheme.Font.bodyEmphasized())
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundColor(AINTheme.Color.accent)
            .background(AINTheme.Color.accent.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: AINTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AINTheme.Radius.md, style: .continuous)
                    .stroke(AINTheme.Color.accent.opacity(0.25), lineWidth: 1)
            )
        }
    }
}

struct AINIconButton: View {
    let systemImage: String
    var tone: AINStatusTone = .info
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 40, height: 40)
                .foregroundColor(tone.fg)
                .background(tone.bg, in: RoundedRectangle(cornerRadius: AINTheme.Radius.md, style: .continuous))
        }
    }
}
