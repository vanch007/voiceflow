import Foundation

// 注意：SceneType 和 ASRLanguage 在同一模块中定义

/// 术语字典条目
struct GlossaryEntry: Codable, Equatable, Identifiable {
    let id: UUID
    var term: String           // ASR可能识别的写法
    var replacement: String    // 正确写法
    var caseSensitive: Bool    // 是否区分大小写

    init(id: UUID = UUID(), term: String, replacement: String, caseSensitive: Bool = false) {
        self.id = id
        self.term = term
        self.replacement = replacement
        self.caseSensitive = caseSensitive
    }
}

/// 润色风格
enum PolishStyle: String, Codable, CaseIterable {
    case casual = "casual"          // 口语化
    case formal = "formal"          // 正式
    case technical = "technical"    // 技术
    case neutral = "neutral"        // 中性

    var displayName: String {
        switch self {
        case .casual: return "口语化"
        case .formal: return "正式"
        case .technical: return "技术"
        case .neutral: return "中性"
        }
    }

    var description: String {
        switch self {
        case .casual: return "简短、自然的对话风格"
        case .formal: return "正式、完整的书面语句"
        case .technical: return "保留技术术语和变量名"
        case .neutral: return "最小程度的修正"
        }
    }
}

/// 场景预设配置
struct SceneProfile: Codable, Equatable {
    var sceneType: SceneType
    var language: ASRLanguage
    var enablePolish: Bool
    var polishStyle: PolishStyle
    var enabledPluginIDs: [String]
    var customPrompt: String?
    var glossary: [GlossaryEntry]

    // MARK: - 默认提示词

    /// 各场景的默认提示词
    static let defaultPrompts: [SceneType: String] = [
        .social: """
            将语音转录文本转换为适合社交聊天的形式：
            - 保持口语化、简短自然
            - 保留语气词和情感表达（如"哈哈"、"嗯"、"啊"）
            - 不需要严格的标点符号
            - 可以使用网络流行语和表情符号
            """,
        .coding: """
            将语音转录文本转换为适合编程场景的形式：
            - 严格保留代码术语、变量名、函数名
            - 不翻译英文技术词汇（如 API、JSON、function）
            - 保持专业准确，避免口语化表达
            - 数字和符号保持原样
            """,
        .writing: """
            将语音转录文本转换为正式书面语：
            - 使用完整的句子结构
            - 添加恰当的标点符号
            - 去除口语化的语气词
            - 确保逻辑清晰、段落分明
            """,
        .general: """
            对语音转录文本做最小程度的修正：
            - 保持原意不变
            - 仅修正明显的语法错误
            - 添加基本标点符号
            """
    ]

    // MARK: - 默认术语字典

    /// 各场景的默认术语字典
    static let defaultGlossaries: [SceneType: [GlossaryEntry]] = [
        .social: [],
        .coding: [
            // 编程语言
            GlossaryEntry(term: "派森", replacement: "Python"),
            GlossaryEntry(term: "派生", replacement: "Python"),
            GlossaryEntry(term: "拍摄", replacement: "Python"),
            GlossaryEntry(term: "爪哇", replacement: "Java"),
            GlossaryEntry(term: "加瓦", replacement: "Java"),
            GlossaryEntry(term: "斯威夫特", replacement: "Swift"),
            GlossaryEntry(term: "锈", replacement: "Rust"),
            GlossaryEntry(term: "拉斯特", replacement: "Rust"),
            GlossaryEntry(term: "围棋", replacement: "Go"),
            GlossaryEntry(term: "狗", replacement: "Go"),
            GlossaryEntry(term: "科特林", replacement: "Kotlin"),

            // 前端框架
            GlossaryEntry(term: "瑞艾克特", replacement: "React"),
            GlossaryEntry(term: "瑞克特", replacement: "React"),
            GlossaryEntry(term: "锐克特", replacement: "React"),
            GlossaryEntry(term: "维优", replacement: "Vue"),
            GlossaryEntry(term: "view", replacement: "Vue"),
            GlossaryEntry(term: "安古拉", replacement: "Angular"),
            GlossaryEntry(term: "奈克斯特", replacement: "Next.js"),
            GlossaryEntry(term: "纳克斯特", replacement: "Nuxt"),

            // 数据格式
            GlossaryEntry(term: "杰森", replacement: "JSON"),
            GlossaryEntry(term: "节省", replacement: "JSON"),
            GlossaryEntry(term: "杰克森", replacement: "JSON"),
            GlossaryEntry(term: "亚姆", replacement: "YAML"),
            GlossaryEntry(term: "雅莫", replacement: "YAML"),

            // 技术术语
            GlossaryEntry(term: "阿派", replacement: "API"),
            GlossaryEntry(term: "阿皮", replacement: "API"),
            GlossaryEntry(term: "艾皮爱", replacement: "API"),
            GlossaryEntry(term: "埃塞德凯", replacement: "SDK"),
            GlossaryEntry(term: "艾斯迪凯", replacement: "SDK"),
            GlossaryEntry(term: "吉特", replacement: "Git"),
            GlossaryEntry(term: "盖特", replacement: "Git"),
            GlossaryEntry(term: "吉特哈布", replacement: "GitHub"),
            GlossaryEntry(term: "多克", replacement: "Docker"),
            GlossaryEntry(term: "道克", replacement: "Docker"),
            GlossaryEntry(term: "库伯内提斯", replacement: "Kubernetes"),
            GlossaryEntry(term: "K八S", replacement: "K8s"),
            GlossaryEntry(term: "艾奇提提皮", replacement: "HTTP"),
            GlossaryEntry(term: "休息", replacement: "REST"),
            GlossaryEntry(term: "瑞斯特", replacement: "REST"),
            GlossaryEntry(term: "格拉夫Q艾尔", replacement: "GraphQL"),
            GlossaryEntry(term: "爱思Q艾尔", replacement: "SQL"),
            GlossaryEntry(term: "西Q艾尔", replacement: "SQL"),
            GlossaryEntry(term: "诺艾斯Q艾尔", replacement: "NoSQL"),

            // 数据库
            GlossaryEntry(term: "迈艾斯Q艾尔", replacement: "MySQL"),
            GlossaryEntry(term: "波斯特格瑞", replacement: "PostgreSQL"),
            GlossaryEntry(term: "蒙戈", replacement: "MongoDB"),
            GlossaryEntry(term: "蒙古", replacement: "MongoDB"),
            GlossaryEntry(term: "瑞迪斯", replacement: "Redis"),
            GlossaryEntry(term: "雷迪斯", replacement: "Redis"),

            // AI/ML
            GlossaryEntry(term: "艾尔艾尔艾姆", replacement: "LLM"),
            GlossaryEntry(term: "大语言模型", replacement: "LLM"),
            GlossaryEntry(term: "拉格", replacement: "RAG"),
            GlossaryEntry(term: "及皮提", replacement: "GPT"),
            GlossaryEntry(term: "吉皮提", replacement: "GPT"),
            GlossaryEntry(term: "克劳德", replacement: "Claude"),
            GlossaryEntry(term: "M艾尔艾克斯", replacement: "MLX"),
        ],
        .writing: [
            // 常见错别字修正
            GlossaryEntry(term: "的地得", replacement: "的"),
        ],
        .general: []
    ]

    /// 默认配置
    static func defaultProfile(for sceneType: SceneType) -> SceneProfile {
        let defaultGlossary = defaultGlossaries[sceneType] ?? []

        switch sceneType {
        case .social:
            return SceneProfile(
                sceneType: .social,
                language: .auto,
                enablePolish: true,
                polishStyle: .casual,
                enabledPluginIDs: [],
                customPrompt: nil,
                glossary: defaultGlossary
            )
        case .coding:
            return SceneProfile(
                sceneType: .coding,
                language: .auto,
                enablePolish: false,
                polishStyle: .technical,
                enabledPluginIDs: [],
                customPrompt: nil,
                glossary: defaultGlossary
            )
        case .writing:
            return SceneProfile(
                sceneType: .writing,
                language: .auto,
                enablePolish: true,
                polishStyle: .formal,
                enabledPluginIDs: [],
                customPrompt: nil,
                glossary: defaultGlossary
            )
        case .general:
            return SceneProfile(
                sceneType: .general,
                language: .auto,
                enablePolish: false,
                polishStyle: .neutral,
                enabledPluginIDs: [],
                customPrompt: nil,
                glossary: defaultGlossary
            )
        }
    }

    /// 获取有效的提示词（优先使用自定义，否则使用默认）
    func getEffectivePrompt() -> String? {
        if let custom = customPrompt, !custom.isEmpty {
            return custom
        }
        return SceneProfile.defaultPrompts[sceneType]
    }
}
