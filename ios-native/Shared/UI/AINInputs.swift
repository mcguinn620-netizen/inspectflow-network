import SwiftUI

struct AINTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var systemImage: String? = nil
    var monospaced: Bool = false
    var keyboard: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: AINTheme.Spacing.xs) {
            Text(title)
                .font(AINTheme.Font.caption(12))
                .foregroundColor(AINTheme.Color.textSecondary)
            HStack(spacing: AINTheme.Spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundColor(AINTheme.Color.textTertiary)
                }
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(monospaced ? AINTheme.Font.mono(15) : AINTheme.Font.body())
                .keyboardType(keyboard)
                .autocorrectionDisabled(monospaced)
                .textInputAutocapitalization(monospaced ? .characters : .sentences)
            }
            .padding(.horizontal, AINTheme.Spacing.md)
            .frame(minHeight: 48)
            .background(AINTheme.Color.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: AINTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AINTheme.Radius.md, style: .continuous)
                    .stroke(AINTheme.Color.border, lineWidth: 0.5)
            )
        }
    }
}

struct AINSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search"

    var body: some View {
        HStack(spacing: AINTheme.Spacing.sm) {
            Image(systemName: "magnifyingglass").foregroundColor(AINTheme.Color.textTertiary)
            TextField(placeholder, text: $text)
                .font(AINTheme.Font.body())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(AINTheme.Color.textTertiary)
                }
            }
        }
        .padding(.horizontal, AINTheme.Spacing.md)
        .frame(height: 40)
        .background(AINTheme.Color.surfaceMuted)
        .clipShape(Capsule())
    }
}

struct AINToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AINTheme.Font.bodyEmphasized())
                if let subtitle {
                    Text(subtitle).font(AINTheme.Font.caption()).foregroundColor(AINTheme.Color.textSecondary)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(AINTheme.Color.accent)
        }
        .padding(.vertical, AINTheme.Spacing.sm)
    }
}

struct AINPickerRow<T: Hashable>: View {
    let title: String
    @Binding var selection: T
    let options: [(T, String)]

    var body: some View {
        HStack {
            Text(title).font(AINTheme.Font.bodyEmphasized())
            Spacer()
            Menu {
                ForEach(options, id: \.0) { (value, label) in
                    Button(label) { selection = value }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(options.first { $0.0 == selection }?.1 ?? "")
                        .foregroundColor(AINTheme.Color.textSecondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundColor(AINTheme.Color.textTertiary)
                }
            }
        }
        .padding(.vertical, AINTheme.Spacing.sm)
    }
}
