import Foundation

/// Scene types for domain-specific voice recognition optimization
enum SceneType: String, Codable, CaseIterable, Identifiable {
    case general
    case social
    case coding
    case writing
    case medical
    case legal
    case technical
    case finance
    case engineering

    var id: String { rawValue }

    /// Display name for the scene type (localized)
    var displayName: String {
        switch self {
        case .general:
            return "通用"
        case .social:
            return "社交"
        case .coding:
            return "编程"
        case .writing:
            return "写作"
        case .medical:
            return "医疗"
        case .legal:
            return "法律"
        case .technical:
            return "技术"
        case .finance:
            return "金融"
        case .engineering:
            return "工程"
        }
    }

    /// SF Symbol icon name for the scene type
    var icon: String {
        switch self {
        case .general:
            return "text.bubble"
        case .social:
            return "person.2"
        case .coding:
            return "chevron.left.forwardslash.chevron.right"
        case .writing:
            return "doc.text"
        case .medical:
            return "stethoscope"
        case .legal:
            return "briefcase"
        case .technical:
            return "cpu"
        case .finance:
            return "dollarsign.circle"
        case .engineering:
            return "hammer.wrench"
        }
    }

    /// Description of the scene type
    var description: String {
        switch self {
        case .general:
            return "适用于日常对话和通用场景"
        case .social:
            return "适用于社交媒体和即时通讯"
        case .coding:
            return "适用于编程和技术文档"
        case .writing:
            return "适用于文章写作和内容创作"
        case .medical:
            return "适用于医疗记录和病历文档，包含医学术语优化"
        case .legal:
            return "适用于法律文档和合同起草，确保法律术语准确性"
        case .technical:
            return "适用于技术文档和工程规范，保留技术术语"
        case .finance:
            return "适用于财务报告和金融分析，确保数字和术语精确"
        case .engineering:
            return "适用于工程设计和规范文档，保留工程术语和测量值"
        }
    }
}
