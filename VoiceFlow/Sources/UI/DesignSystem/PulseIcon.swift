import SwiftUI

/// Static icon component (no animation)
struct StaticIcon: View {
    let icon: String
    let size: CGFloat
    let color: Color

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size))
            .foregroundColor(color)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 40) {
        StaticIcon(icon: "mic.fill", size: 60, color: Color(hex: "0A84FF"))
        StaticIcon(icon: "checkmark.circle.fill", size: 60, color: Color(hex: "30D158"))
    }
    .frame(width: 680, height: 540)
    .background(
        LinearGradient(
            colors: [Color(hex: "1C1C1E"), Color(hex: "2C2C2E")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
