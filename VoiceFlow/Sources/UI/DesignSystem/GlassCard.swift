import SwiftUI

/// Glassmorphism card component
struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DesignToken.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignToken.CornerRadius.large)
                    .fill(DesignToken.Colors.glassBackground)
                    .background(
                        RoundedRectangle(cornerRadius: DesignToken.CornerRadius.large)
                            .stroke(DesignToken.Colors.glassBorder, lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Preview
#Preview {
    GlassCard {
        VStack {
            Text("Glass Card")
                .font(DesignToken.Typography.title)
                .foregroundColor(DesignToken.Colors.textPrimary)
            Text("This is a glassmorphism card")
                .font(DesignToken.Typography.body)
                .foregroundColor(DesignToken.Colors.textSecondary)
        }
    }
    .frame(width: 400)
    .background(GradientBackground())
}
