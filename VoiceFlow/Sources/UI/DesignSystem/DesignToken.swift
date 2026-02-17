import SwiftUI

/// Design tokens for consistent styling across the app
enum DesignToken {
    // MARK: - Colors
    enum Colors {
        static let backgroundGradientStart = Color(hex: "1C1C1E")
        static let backgroundGradientEnd = Color(hex: "2C2C2E")
        static let primary = Color(hex: "0A84FF")
        static let accent = Color(hex: "30D158")
        static let warning = Color(hex: "FF9F0A")
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "8E8E93")
        static let glassBackground = Color.white.opacity(0.1)
        static let glassBorder = Color.white.opacity(0.2)
        static let success = Color(hex: "30D158")
        static let error = Color(hex: "FF453A")
    }

    // MARK: - Typography
    enum Typography {
        static let title = Font.system(size: 28, weight: .semibold)
        static let subtitle = Font.system(size: 18, weight: .regular)
        static let body = Font.system(size: 14, weight: .regular)
        static let caption = Font.system(size: 12, weight: .regular)
    }

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 24
    }

    // MARK: - Animation
    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let slow = SwiftUI.Animation.easeOut(duration: 0.3)
        static let spring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.7)
        static let pulse = SwiftUI.Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
