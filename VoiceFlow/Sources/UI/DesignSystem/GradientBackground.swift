import SwiftUI

/// Static gradient background (no animation)
struct GradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                DesignToken.Colors.backgroundGradientStart,
                DesignToken.Colors.backgroundGradientEnd
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Preview
#Preview {
    GradientBackground()
        .frame(width: 680, height: 540)
}
