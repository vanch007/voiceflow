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

    // MARK: - LLM 相关字段

    /// 是否使用 LLM 润色（覆盖全局设置）
    var useLLMPolish: Bool?

    /// LLM 分析建议的关键词
    var keywords: [String]

    /// LLM 建议的术语（待添加到字典）
    var suggestedTerms: [String]

    /// 上次分析时间
    var lastAnalyzedAt: Date?

    init(
        sceneType: SceneType,
        language: ASRLanguage,
        enablePolish: Bool,
        polishStyle: PolishStyle,
        enabledPluginIDs: [String],
        customPrompt: String?,
        glossary: [GlossaryEntry],
        useLLMPolish: Bool? = nil,
        keywords: [String] = [],
        suggestedTerms: [String] = [],
        lastAnalyzedAt: Date? = nil
    ) {
        self.sceneType = sceneType
        self.language = language
        self.enablePolish = enablePolish
        self.polishStyle = polishStyle
        self.enabledPluginIDs = enabledPluginIDs
        self.customPrompt = customPrompt
        self.glossary = glossary
        self.useLLMPolish = useLLMPolish
        self.keywords = keywords
        self.suggestedTerms = suggestedTerms
        self.lastAnalyzedAt = lastAnalyzedAt
    }

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
            """,
        .medical: "Preserve all medical terminology exactly. Use formal, professional language appropriate for medical documentation. Ensure accuracy of drug names, conditions, and procedures.",
        .legal: "Preserve all legal terms of art exactly. Use formal, precise language appropriate for legal documentation. Maintain strict accuracy.",
        .technical: "Preserve all technical terminology, acronyms, specifications, and measurements exactly. Use clear, precise technical language.",
        .finance: "Preserve all financial terminology and numerical values exactly. Use formal, precise language appropriate for financial documentation.",
        .engineering: "Preserve all engineering terminology, specifications, measurements, and technical notation exactly. Use precise technical language."
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
            GlossaryEntry(term: "的地得", replacement: "的"),
        ],
        .general: [],
        .medical: [
            GlossaryEntry(term: "acetaminophen", replacement: "acetaminophen"),
            GlossaryEntry(term: "ibuprofen", replacement: "ibuprofen"),
            GlossaryEntry(term: "aspirin", replacement: "aspirin"),
            GlossaryEntry(term: "amoxicillin", replacement: "amoxicillin"),
            GlossaryEntry(term: "metformin", replacement: "metformin"),
            GlossaryEntry(term: "lisinopril", replacement: "lisinopril"),
            GlossaryEntry(term: "atorvastatin", replacement: "atorvastatin"),
            GlossaryEntry(term: "amlodipine", replacement: "amlodipine"),
            GlossaryEntry(term: "omeprazole", replacement: "omeprazole"),
            GlossaryEntry(term: "losartan", replacement: "losartan"),
            GlossaryEntry(term: "albuterol", replacement: "albuterol"),
            GlossaryEntry(term: "gabapentin", replacement: "gabapentin"),
            GlossaryEntry(term: "hydrochlorothiazide", replacement: "hydrochlorothiazide"),
            GlossaryEntry(term: "sertraline", replacement: "sertraline"),
            GlossaryEntry(term: "simvastatin", replacement: "simvastatin"),
            GlossaryEntry(term: "hypertension", replacement: "hypertension"),
            GlossaryEntry(term: "diabetes", replacement: "diabetes"),
            GlossaryEntry(term: "diabetes mellitus", replacement: "diabetes mellitus"),
            GlossaryEntry(term: "myocardial infarction", replacement: "myocardial infarction"),
            GlossaryEntry(term: "cerebrovascular accident", replacement: "cerebrovascular accident"),
            GlossaryEntry(term: "pneumonia", replacement: "pneumonia"),
            GlossaryEntry(term: "asthma", replacement: "asthma"),
            GlossaryEntry(term: "chronic obstructive pulmonary disease", replacement: "chronic obstructive pulmonary disease"),
            GlossaryEntry(term: "copd", replacement: "COPD"),
            GlossaryEntry(term: "congestive heart failure", replacement: "congestive heart failure"),
            GlossaryEntry(term: "atrial fibrillation", replacement: "atrial fibrillation"),
            GlossaryEntry(term: "gastroesophageal reflux disease", replacement: "gastroesophageal reflux disease"),
            GlossaryEntry(term: "gerd", replacement: "GERD"),
            GlossaryEntry(term: "osteoarthritis", replacement: "osteoarthritis"),
            GlossaryEntry(term: "rheumatoid arthritis", replacement: "rheumatoid arthritis"),
            GlossaryEntry(term: "myocardial", replacement: "myocardial"),
            GlossaryEntry(term: "cerebral", replacement: "cerebral"),
            GlossaryEntry(term: "pulmonary", replacement: "pulmonary"),
            GlossaryEntry(term: "cardiovascular", replacement: "cardiovascular"),
            GlossaryEntry(term: "gastrointestinal", replacement: "gastrointestinal"),
            GlossaryEntry(term: "respiratory", replacement: "respiratory"),
            GlossaryEntry(term: "hepatic", replacement: "hepatic"),
            GlossaryEntry(term: "renal", replacement: "renal"),
            GlossaryEntry(term: "endocrine", replacement: "endocrine"),
            GlossaryEntry(term: "neurological", replacement: "neurological"),
            GlossaryEntry(term: "angioplasty", replacement: "angioplasty"),
            GlossaryEntry(term: "catheterization", replacement: "catheterization"),
            GlossaryEntry(term: "endoscopy", replacement: "endoscopy"),
            GlossaryEntry(term: "colonoscopy", replacement: "colonoscopy"),
            GlossaryEntry(term: "bronchoscopy", replacement: "bronchoscopy"),
            GlossaryEntry(term: "intubation", replacement: "intubation"),
            GlossaryEntry(term: "tracheostomy", replacement: "tracheostomy"),
            GlossaryEntry(term: "thoracotomy", replacement: "thoracotomy"),
            GlossaryEntry(term: "laparoscopy", replacement: "laparoscopy"),
            GlossaryEntry(term: "appendectomy", replacement: "appendectomy"),
            GlossaryEntry(term: "diagnosis", replacement: "diagnosis"),
            GlossaryEntry(term: "prognosis", replacement: "prognosis"),
            GlossaryEntry(term: "symptom", replacement: "symptom"),
            GlossaryEntry(term: "syndrome", replacement: "syndrome"),
            GlossaryEntry(term: "pathology", replacement: "pathology"),
            GlossaryEntry(term: "etiology", replacement: "etiology"),
            GlossaryEntry(term: "epidemiology", replacement: "epidemiology"),
            GlossaryEntry(term: "prophylaxis", replacement: "prophylaxis"),
            GlossaryEntry(term: "therapeutic", replacement: "therapeutic"),
            GlossaryEntry(term: "palliative", replacement: "palliative"),
            GlossaryEntry(term: "acute", replacement: "acute"),
            GlossaryEntry(term: "chronic", replacement: "chronic"),
            GlossaryEntry(term: "benign", replacement: "benign"),
            GlossaryEntry(term: "malignant", replacement: "malignant"),
            GlossaryEntry(term: "metastasis", replacement: "metastasis"),
        ],
        .legal: [
            GlossaryEntry(term: "plaintiff", replacement: "plaintiff"),
            GlossaryEntry(term: "defendant", replacement: "defendant"),
            GlossaryEntry(term: "affidavit", replacement: "affidavit"),
            GlossaryEntry(term: "deposition", replacement: "deposition"),
            GlossaryEntry(term: "subpoena", replacement: "subpoena"),
            GlossaryEntry(term: "habeas corpus", replacement: "habeas corpus"),
            GlossaryEntry(term: "res judicata", replacement: "res judicata"),
            GlossaryEntry(term: "stare decisis", replacement: "stare decisis"),
            GlossaryEntry(term: "prima facie", replacement: "prima facie"),
            GlossaryEntry(term: "voir dire", replacement: "voir dire"),
            GlossaryEntry(term: "amicus curiae", replacement: "amicus curiae"),
            GlossaryEntry(term: "pro bono", replacement: "pro bono"),
            GlossaryEntry(term: "pro se", replacement: "pro se"),
            GlossaryEntry(term: "in camera", replacement: "in camera"),
            GlossaryEntry(term: "ex parte", replacement: "ex parte"),
            GlossaryEntry(term: "summary judgment", replacement: "summary judgment"),
            GlossaryEntry(term: "motion to dismiss", replacement: "motion to dismiss"),
            GlossaryEntry(term: "preliminary injunction", replacement: "preliminary injunction"),
            GlossaryEntry(term: "temporary restraining order", replacement: "temporary restraining order"),
            GlossaryEntry(term: "tro", replacement: "TRO"),
            GlossaryEntry(term: "discovery", replacement: "discovery"),
            GlossaryEntry(term: "interrogatory", replacement: "interrogatory"),
            GlossaryEntry(term: "admissibility", replacement: "admissibility"),
            GlossaryEntry(term: "hearsay", replacement: "hearsay"),
            GlossaryEntry(term: "impeachment", replacement: "impeachment"),
            GlossaryEntry(term: "cross examination", replacement: "cross-examination"),
            GlossaryEntry(term: "direct examination", replacement: "direct examination"),
            GlossaryEntry(term: "sustained", replacement: "sustained"),
            GlossaryEntry(term: "overruled", replacement: "overruled"),
            GlossaryEntry(term: "consideration", replacement: "consideration"),
            GlossaryEntry(term: "breach of contract", replacement: "breach of contract"),
            GlossaryEntry(term: "force majeure", replacement: "force majeure"),
            GlossaryEntry(term: "indemnification", replacement: "indemnification"),
            GlossaryEntry(term: "liquidated damages", replacement: "liquidated damages"),
            GlossaryEntry(term: "specific performance", replacement: "specific performance"),
            GlossaryEntry(term: "rescission", replacement: "rescission"),
            GlossaryEntry(term: "warranty", replacement: "warranty"),
            GlossaryEntry(term: "covenant", replacement: "covenant"),
            GlossaryEntry(term: "estoppel", replacement: "estoppel"),
            GlossaryEntry(term: "easement", replacement: "easement"),
            GlossaryEntry(term: "lien", replacement: "lien"),
            GlossaryEntry(term: "encumbrance", replacement: "encumbrance"),
            GlossaryEntry(term: "adverse possession", replacement: "adverse possession"),
            GlossaryEntry(term: "eminent domain", replacement: "eminent domain"),
            GlossaryEntry(term: "fee simple", replacement: "fee simple"),
            GlossaryEntry(term: "life estate", replacement: "life estate"),
            GlossaryEntry(term: "tenancy in common", replacement: "tenancy in common"),
            GlossaryEntry(term: "joint tenancy", replacement: "joint tenancy"),
            GlossaryEntry(term: "mens rea", replacement: "mens rea"),
            GlossaryEntry(term: "actus reus", replacement: "actus reus"),
            GlossaryEntry(term: "beyond reasonable doubt", replacement: "beyond reasonable doubt"),
            GlossaryEntry(term: "miranda rights", replacement: "Miranda rights"),
            GlossaryEntry(term: "probable cause", replacement: "probable cause"),
            GlossaryEntry(term: "grand jury", replacement: "grand jury"),
            GlossaryEntry(term: "indictment", replacement: "indictment"),
            GlossaryEntry(term: "arraignment", replacement: "arraignment"),
            GlossaryEntry(term: "plea bargain", replacement: "plea bargain"),
            GlossaryEntry(term: "acquittal", replacement: "acquittal"),
            GlossaryEntry(term: "conviction", replacement: "conviction"),
        ],
        .technical: [
            GlossaryEntry(term: "iso", replacement: "ISO"),
            GlossaryEntry(term: "ieee", replacement: "IEEE"),
            GlossaryEntry(term: "ansi", replacement: "ANSI"),
            GlossaryEntry(term: "nist", replacement: "NIST"),
            GlossaryEntry(term: "iec", replacement: "IEC"),
            GlossaryEntry(term: "astm", replacement: "ASTM"),
            GlossaryEntry(term: "din", replacement: "DIN"),
            GlossaryEntry(term: "jis", replacement: "JIS"),
            GlossaryEntry(term: "tcp ip", replacement: "TCP/IP"),
            GlossaryEntry(term: "http", replacement: "HTTP"),
            GlossaryEntry(term: "https", replacement: "HTTPS"),
            GlossaryEntry(term: "ftp", replacement: "FTP"),
            GlossaryEntry(term: "smtp", replacement: "SMTP"),
            GlossaryEntry(term: "dns", replacement: "DNS"),
            GlossaryEntry(term: "dhcp", replacement: "DHCP"),
            GlossaryEntry(term: "ssh", replacement: "SSH"),
            GlossaryEntry(term: "tls", replacement: "TLS"),
            GlossaryEntry(term: "ssl", replacement: "SSL"),
            GlossaryEntry(term: "vpn", replacement: "VPN"),
            GlossaryEntry(term: "lan", replacement: "LAN"),
            GlossaryEntry(term: "wan", replacement: "WAN"),
            GlossaryEntry(term: "vlan", replacement: "VLAN"),
            GlossaryEntry(term: "cpu", replacement: "CPU"),
            GlossaryEntry(term: "gpu", replacement: "GPU"),
            GlossaryEntry(term: "ram", replacement: "RAM"),
            GlossaryEntry(term: "rom", replacement: "ROM"),
            GlossaryEntry(term: "ssd", replacement: "SSD"),
            GlossaryEntry(term: "hdd", replacement: "HDD"),
            GlossaryEntry(term: "usb", replacement: "USB"),
            GlossaryEntry(term: "pci", replacement: "PCI"),
            GlossaryEntry(term: "bios", replacement: "BIOS"),
            GlossaryEntry(term: "uefi", replacement: "UEFI"),
            GlossaryEntry(term: "kilobyte", replacement: "kilobyte"),
            GlossaryEntry(term: "megabyte", replacement: "megabyte"),
            GlossaryEntry(term: "gigabyte", replacement: "gigabyte"),
            GlossaryEntry(term: "terabyte", replacement: "terabyte"),
            GlossaryEntry(term: "hertz", replacement: "hertz"),
            GlossaryEntry(term: "megahertz", replacement: "megahertz"),
            GlossaryEntry(term: "gigahertz", replacement: "gigahertz"),
            GlossaryEntry(term: "bandwidth", replacement: "bandwidth"),
            GlossaryEntry(term: "latency", replacement: "latency"),
            GlossaryEntry(term: "throughput", replacement: "throughput"),
            GlossaryEntry(term: "operating system", replacement: "operating system"),
            GlossaryEntry(term: "firmware", replacement: "firmware"),
            GlossaryEntry(term: "middleware", replacement: "middleware"),
            GlossaryEntry(term: "virtualization", replacement: "virtualization"),
            GlossaryEntry(term: "hypervisor", replacement: "hypervisor"),
            GlossaryEntry(term: "container", replacement: "container"),
            GlossaryEntry(term: "microservices", replacement: "microservices"),
            GlossaryEntry(term: "api gateway", replacement: "API gateway"),
            GlossaryEntry(term: "load balancer", replacement: "load balancer"),
            GlossaryEntry(term: "proxy", replacement: "proxy"),
            GlossaryEntry(term: "cache", replacement: "cache"),
            GlossaryEntry(term: "database", replacement: "database"),
            GlossaryEntry(term: "redundancy", replacement: "redundancy"),
            GlossaryEntry(term: "failover", replacement: "failover"),
            GlossaryEntry(term: "scalability", replacement: "scalability"),
            GlossaryEntry(term: "encryption", replacement: "encryption"),
            GlossaryEntry(term: "authentication", replacement: "authentication"),
            GlossaryEntry(term: "authorization", replacement: "authorization"),
        ],
        .finance: [
            GlossaryEntry(term: "stock", replacement: "stock"),
            GlossaryEntry(term: "bond", replacement: "bond"),
            GlossaryEntry(term: "equity", replacement: "equity"),
            GlossaryEntry(term: "derivative", replacement: "derivative"),
            GlossaryEntry(term: "option", replacement: "option"),
            GlossaryEntry(term: "futures", replacement: "futures"),
            GlossaryEntry(term: "swap", replacement: "swap"),
            GlossaryEntry(term: "warrant", replacement: "warrant"),
            GlossaryEntry(term: "mutual fund", replacement: "mutual fund"),
            GlossaryEntry(term: "etf", replacement: "ETF"),
            GlossaryEntry(term: "reit", replacement: "REIT"),
            GlossaryEntry(term: "hedge fund", replacement: "hedge fund"),
            GlossaryEntry(term: "private equity", replacement: "private equity"),
            GlossaryEntry(term: "venture capital", replacement: "venture capital"),
            GlossaryEntry(term: "assets", replacement: "assets"),
            GlossaryEntry(term: "liabilities", replacement: "liabilities"),
            GlossaryEntry(term: "revenue", replacement: "revenue"),
            GlossaryEntry(term: "expense", replacement: "expense"),
            GlossaryEntry(term: "depreciation", replacement: "depreciation"),
            GlossaryEntry(term: "amortization", replacement: "amortization"),
            GlossaryEntry(term: "accrual", replacement: "accrual"),
            GlossaryEntry(term: "deferred revenue", replacement: "deferred revenue"),
            GlossaryEntry(term: "accounts receivable", replacement: "accounts receivable"),
            GlossaryEntry(term: "accounts payable", replacement: "accounts payable"),
            GlossaryEntry(term: "balance sheet", replacement: "balance sheet"),
            GlossaryEntry(term: "income statement", replacement: "income statement"),
            GlossaryEntry(term: "cash flow statement", replacement: "cash flow statement"),
            GlossaryEntry(term: "gaap", replacement: "GAAP"),
            GlossaryEntry(term: "ifrs", replacement: "IFRS"),
            GlossaryEntry(term: "portfolio", replacement: "portfolio"),
            GlossaryEntry(term: "diversification", replacement: "diversification"),
            GlossaryEntry(term: "asset allocation", replacement: "asset allocation"),
            GlossaryEntry(term: "market capitalization", replacement: "market capitalization"),
            GlossaryEntry(term: "dividend", replacement: "dividend"),
            GlossaryEntry(term: "yield", replacement: "yield"),
            GlossaryEntry(term: "return on investment", replacement: "return on investment"),
            GlossaryEntry(term: "roi", replacement: "ROI"),
            GlossaryEntry(term: "alpha", replacement: "alpha"),
            GlossaryEntry(term: "beta", replacement: "beta"),
            GlossaryEntry(term: "volatility", replacement: "volatility"),
            GlossaryEntry(term: "liquidity", replacement: "liquidity"),
            GlossaryEntry(term: "arbitrage", replacement: "arbitrage"),
            GlossaryEntry(term: "interest rate", replacement: "interest rate"),
            GlossaryEntry(term: "compound interest", replacement: "compound interest"),
            GlossaryEntry(term: "apr", replacement: "APR"),
            GlossaryEntry(term: "apy", replacement: "APY"),
            GlossaryEntry(term: "mortgage", replacement: "mortgage"),
            GlossaryEntry(term: "loan", replacement: "loan"),
            GlossaryEntry(term: "credit", replacement: "credit"),
            GlossaryEntry(term: "debt", replacement: "debt"),
            GlossaryEntry(term: "collateral", replacement: "collateral"),
            GlossaryEntry(term: "leverage", replacement: "leverage"),
            GlossaryEntry(term: "margin", replacement: "margin"),
            GlossaryEntry(term: "default", replacement: "default"),
            GlossaryEntry(term: "bankruptcy", replacement: "bankruptcy"),
            GlossaryEntry(term: "credit rating", replacement: "credit rating"),
            GlossaryEntry(term: "underwriting", replacement: "underwriting"),
            GlossaryEntry(term: "ipo", replacement: "IPO"),
            GlossaryEntry(term: "merger", replacement: "merger"),
            GlossaryEntry(term: "acquisition", replacement: "acquisition"),
        ],
        .engineering: [
            GlossaryEntry(term: "mechanical engineering", replacement: "mechanical engineering"),
            GlossaryEntry(term: "electrical engineering", replacement: "electrical engineering"),
            GlossaryEntry(term: "civil engineering", replacement: "civil engineering"),
            GlossaryEntry(term: "chemical engineering", replacement: "chemical engineering"),
            GlossaryEntry(term: "structural engineering", replacement: "structural engineering"),
            GlossaryEntry(term: "aerospace engineering", replacement: "aerospace engineering"),
            GlossaryEntry(term: "automotive engineering", replacement: "automotive engineering"),
            GlossaryEntry(term: "industrial engineering", replacement: "industrial engineering"),
            GlossaryEntry(term: "steel", replacement: "steel"),
            GlossaryEntry(term: "aluminum", replacement: "aluminum"),
            GlossaryEntry(term: "titanium", replacement: "titanium"),
            GlossaryEntry(term: "composite", replacement: "composite"),
            GlossaryEntry(term: "polymer", replacement: "polymer"),
            GlossaryEntry(term: "ceramic", replacement: "ceramic"),
            GlossaryEntry(term: "alloy", replacement: "alloy"),
            GlossaryEntry(term: "carbon fiber", replacement: "carbon fiber"),
            GlossaryEntry(term: "reinforced concrete", replacement: "reinforced concrete"),
            GlossaryEntry(term: "prestressed concrete", replacement: "prestressed concrete"),
            GlossaryEntry(term: "machining", replacement: "machining"),
            GlossaryEntry(term: "welding", replacement: "welding"),
            GlossaryEntry(term: "casting", replacement: "casting"),
            GlossaryEntry(term: "forging", replacement: "forging"),
            GlossaryEntry(term: "stamping", replacement: "stamping"),
            GlossaryEntry(term: "extrusion", replacement: "extrusion"),
            GlossaryEntry(term: "injection molding", replacement: "injection molding"),
            GlossaryEntry(term: "cnc", replacement: "CNC"),
            GlossaryEntry(term: "cad", replacement: "CAD"),
            GlossaryEntry(term: "cam", replacement: "CAM"),
            GlossaryEntry(term: "finite element analysis", replacement: "finite element analysis"),
            GlossaryEntry(term: "fea", replacement: "FEA"),
            GlossaryEntry(term: "cfd", replacement: "CFD"),
            GlossaryEntry(term: "tolerance", replacement: "tolerance"),
            GlossaryEntry(term: "clearance", replacement: "clearance"),
            GlossaryEntry(term: "interference", replacement: "interference"),
            GlossaryEntry(term: "tensile strength", replacement: "tensile strength"),
            GlossaryEntry(term: "yield strength", replacement: "yield strength"),
            GlossaryEntry(term: "shear stress", replacement: "shear stress"),
            GlossaryEntry(term: "fatigue", replacement: "fatigue"),
            GlossaryEntry(term: "creep", replacement: "creep"),
            GlossaryEntry(term: "hardness", replacement: "hardness"),
            GlossaryEntry(term: "ductility", replacement: "ductility"),
            GlossaryEntry(term: "brittleness", replacement: "brittleness"),
            GlossaryEntry(term: "elasticity", replacement: "elasticity"),
            GlossaryEntry(term: "plasticity", replacement: "plasticity"),
            GlossaryEntry(term: "asme", replacement: "ASME"),
            GlossaryEntry(term: "sae", replacement: "SAE"),
            GlossaryEntry(term: "aisc", replacement: "AISC"),
            GlossaryEntry(term: "asce", replacement: "ASCE"),
            GlossaryEntry(term: "ashrae", replacement: "ASHRAE"),
            GlossaryEntry(term: "actuator", replacement: "actuator"),
            GlossaryEntry(term: "servo", replacement: "servo"),
            GlossaryEntry(term: "hydraulic", replacement: "hydraulic"),
            GlossaryEntry(term: "pneumatic", replacement: "pneumatic"),
            GlossaryEntry(term: "bearing", replacement: "bearing"),
            GlossaryEntry(term: "gear", replacement: "gear"),
            GlossaryEntry(term: "shaft", replacement: "shaft"),
            GlossaryEntry(term: "coupling", replacement: "coupling"),
            GlossaryEntry(term: "valve", replacement: "valve"),
            GlossaryEntry(term: "pump", replacement: "pump"),
            GlossaryEntry(term: "compressor", replacement: "compressor"),
            GlossaryEntry(term: "turbine", replacement: "turbine"),
            GlossaryEntry(term: "heat exchanger", replacement: "heat exchanger"),
            GlossaryEntry(term: "manifold", replacement: "manifold"),
            GlossaryEntry(term: "sensor", replacement: "sensor"),
            GlossaryEntry(term: "transducer", replacement: "transducer"),
        ]
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
        case .medical:
            return SceneProfile(
                sceneType: .medical,
                language: .auto,
                enablePolish: true,
                polishStyle: .formal,
                enabledPluginIDs: [],
                customPrompt: nil,
                glossary: defaultGlossary
            )
        case .legal:
            return SceneProfile(
                sceneType: .legal,
                language: .auto,
                enablePolish: true,
                polishStyle: .formal,
                enabledPluginIDs: [],
                customPrompt: nil,
                glossary: defaultGlossary
            )
        case .technical:
            return SceneProfile(
                sceneType: .technical,
                language: .auto,
                enablePolish: false,
                polishStyle: .technical,
                enabledPluginIDs: [],
                customPrompt: nil,
                glossary: defaultGlossary
            )
        case .finance:
            return SceneProfile(
                sceneType: .finance,
                language: .auto,
                enablePolish: true,
                polishStyle: .formal,
                enabledPluginIDs: [],
                customPrompt: nil,
                glossary: defaultGlossary
            )
        case .engineering:
            return SceneProfile(
                sceneType: .engineering,
                language: .auto,
                enablePolish: false,
                polishStyle: .technical,
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
