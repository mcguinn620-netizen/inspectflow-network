import SwiftUI

struct NativeNowIndicator: View {
    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)

            Rectangle()
                .fill(.red)
                .frame(height: 2)
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}
