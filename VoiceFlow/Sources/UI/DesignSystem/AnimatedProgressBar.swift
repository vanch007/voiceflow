import SwiftUI

/// Static progress bar for onboarding steps (no animation)
struct AnimatedProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    private var progress: CGFloat {
        guard totalSteps > 0 else { return 0 }
        return CGFloat(currentStep + 1) / CGFloat(totalSteps)
    }

    var body: some View {
        VStack(spacing: DesignToken.Spacing.sm) {
            // Progress text
            HStack {
                Text("步骤 \(currentStep + 1) / \(totalSteps)")
                    .font(DesignToken.Typography.caption)
                    .foregroundColor(DesignToken.Colors.textSecondary)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(DesignToken.Typography.caption)
                    .foregroundColor(DesignToken.Colors.primary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignToken.Colors.glassBackground)
                        .frame(height: 8)

                    // Static progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [DesignToken.Colors.primary, DesignToken.Colors.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, DesignToken.Spacing.lg)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 40) {
        AnimatedProgressBar(currentStep: 0, totalSteps: 4)
        AnimatedProgressBar(currentStep: 1, totalSteps: 4)
        AnimatedProgressBar(currentStep: 2, totalSteps: 4)
        AnimatedProgressBar(currentStep: 3, totalSteps: 4)
    }
    .padding()
    .frame(width: 680, height: 540)
    .background(
        LinearGradient(
            colors: [Color(hex: "1C1C1E"), Color(hex: "2C2C2E")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
