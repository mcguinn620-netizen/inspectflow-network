import SwiftUI

// MARK: - Bottom Sheet

struct AINBottomSheet<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let detents: Set<PresentationDetent>
    @ViewBuilder let sheetContent: () -> SheetContent

    // 'Content' here now correctly resolves to SwiftUI's internal ViewModifier.Content
    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            sheetContent()
                .presentationDetents(detents)
                .presentationDragIndicator(.visible)
        }
    }
}

extension View {
    func ainBottomSheet<C: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.medium, .large],
        @ViewBuilder content: @escaping () -> C
    ) -> some View {
        // Correctly applies the custom modifier defined above
        self.modifier(AINBottomSheet(isPresented: isPresented, detents: detents, sheetContent: content))
    }
}

// MARK: - Confirmation Dialog

struct AINConfirmDialog: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    var message: String? = nil
    var confirmLabel: String = "Confirm"
    var isDestructive: Bool = false
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(title, isPresented: $isPresented, titleVisibility: .visible) {
            Button(confirmLabel, role: isDestructive ? .destructive : nil, action: onConfirm)
            Button("Cancel", role: .cancel) { }
        } message: {
            if let message { Text(message) }
        }
    }
}

extension View {
    func ainConfirmDialog(
        isPresented: Binding<Bool>,
        title: String,
        message: String? = nil,
        confirmLabel: String = "Confirm",
        isDestructive: Bool = false,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(AINConfirmDialog(
            isPresented: isPresented,
            title: title,
            message: message,
            confirmLabel: confirmLabel,
            isDestructive: isDestructive,
            onConfirm: onConfirm
        ))
    }
}

// MARK: - Toast Banner

/// Lightweight toast banner. Surface from any view via `.ainToast(...)`.
struct AINToast: Equatable {
    enum Tone { case info, success, warn, error }
    let message: String
    var tone: Tone = .info

    var statusTone: AINStatusTone {
        switch tone {
        case .info: return .info
        case .success: return .pass
        case .warn: return .warn
        case .error: return .fail
        }
    }

    var icon: String {
        switch tone {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}

private struct AINToastModifier: ViewModifier {
    @Binding var toast: AINToast?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let t = toast {
                HStack(spacing: AINTheme.Spacing.sm) {
                    Image(systemName: t.icon).foregroundColor(t.statusTone.fg)
                    Text(t.message).font(AINTheme.Font.body(14)).foregroundColor(AINTheme.Color.textPrimary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AINTheme.Spacing.lg)
                .padding(.vertical, AINTheme.Spacing.md)
                .background(AINTheme.Color.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: AINTheme.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AINTheme.Radius.lg, style: .continuous)
                        .stroke(t.statusTone.fg.opacity(0.25), lineWidth: 1)
                )
                .ainShadow(AINTheme.Shadow.popover)
                .padding(.horizontal, AINTheme.Spacing.lg)
                .padding(.top, AINTheme.Spacing.sm)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                        withAnimation { toast = nil }
                    }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: toast)
    }
}

extension View {
    func ainToast(_ toast: Binding<AINToast?>) -> some View {
        modifier(AINToastModifier(toast: toast))
    }
}
