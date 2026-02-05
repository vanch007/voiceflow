import Foundation

/// 场景类型枚举，定义不同的使用场景
enum SceneType: String, Codable, CaseIterable {
    case social = "social"      // 社交聊天
    case coding = "coding"      // IDE编程
    case writing = "writing"    // 写作
    case general = "general"    // 通用

    var displayName: String {
        switch self {
        case .social: return "社交聊天"
        case .coding: return "IDE编程"
        case .writing: return "写作"
        case .general: return "通用"
        }
    }

    var icon: String {
        switch self {
        case .social: return "bubble.left.and.bubble.right"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .writing: return "doc.text"
        case .general: return "square.grid.2x2"
        }
    }

    var description: String {
        switch self {
        case .social: return "口语化、简短、自然对话风格"
        case .coding: return "保留代码术语、变量名，不润色"
        case .writing: return "正式书面语、完整句子"
        case .general: return "默认配置、最小修改"
        }
    }
}
