import Foundation

/// Text replacement engine that applies rules to transcribed text
final class TextReplacementEngine {
    private let storage: ReplacementStorage

    init(storage: ReplacementStorage) {
        self.storage = storage
        NSLog("[TextReplacementEngine] Initialized")
    }

    /// Apply replacement rules to input text (scene-aware)
    /// - Parameters:
    ///   - text: The original transcribed text
    ///   - scene: Optional scene type for filtering rules
    /// - Returns: Text with replacements applied
    func applyReplacements(to text: String, scene: SceneType? = nil) -> String {
        let rules = storage.getRules(for: scene)
        NSLog("[TextReplacementEngine] Input: '%@', scene: %@, rules count: %d", text, scene?.rawValue ?? "nil", rules.count)

        var result = text

        // Apply each enabled rule
        for rule in rules {
            let options: String.CompareOptions = rule.caseSensitive
                ? [.literal]
                : [.caseInsensitive, .literal]

            // Build candidate triggers: original + stripped trailing punctuation
            var triggers = [rule.trigger]
            let stripped = Self.stripTrailingPunctuation(rule.trigger)
            if !stripped.isEmpty && stripped != rule.trigger {
                triggers.append(stripped)
            }

            for trigger in triggers {
                if let matchRange = result.range(of: trigger, options: options) {
                    result.replaceSubrange(matchRange, with: rule.replacement)
                    NSLog("[TextReplacementEngine] Applied rule: '%@' → '%@'", rule.trigger, String(rule.replacement.prefix(30)))
                    break
                }
            }
        }

        // Convert Chinese numbers to Arabic numbers
        result = ChineseNumberConverter.convert(result)

        if result != text {
            NSLog("[TextReplacementEngine] Text transformed: '\(text.prefix(30))' → '\(result.prefix(30))'")
        }

        return result
    }

    /// Strip trailing punctuation (Chinese and English) from a string
    private static func stripTrailingPunctuation(_ str: String) -> String {
        let punctuation: Set<Character> = [
            "。", "，", "！", "？", "；", "：", "、", "…",
            ".", ",", "!", "?", ";", ":", " "
        ]
        var result = str
        while let last = result.last, punctuation.contains(last) {
            result.removeLast()
        }
        return result
    }
}

// MARK: - Chinese Number to Arabic Number Converter

enum ChineseNumberConverter {

    // 基本数字映射
    private static let digitMap: [Character: Int] = [
        "零": 0, "〇": 0,
        "一": 1, "壹": 1,
        "二": 2, "贰": 2, "两": 2,
        "三": 3, "叁": 3,
        "四": 4, "肆": 4,
        "五": 5, "伍": 5,
        "六": 6, "陆": 6,
        "七": 7, "柒": 7,
        "八": 8, "捌": 8,
        "九": 9, "玖": 9,
    ]

    // 节内权位: 十百千
    private static let innerUnitMap: [Character: Int] = [
        "十": 10, "拾": 10,
        "百": 100, "佰": 100,
        "千": 1000, "仟": 1000,
    ]

    // 节权位: 万亿兆
    private static let sectionUnitMap: [Character: Int] = [
        "万": 10_000, "萬": 10_000,
        "亿": 100_000_000, "億": 100_000_000,
    ]

    // 所有中文数字相关字符
    private static let allChineseNumberChars: Set<Character> = {
        var chars = Set<Character>()
        digitMap.keys.forEach { chars.insert($0) }
        innerUnitMap.keys.forEach { chars.insert($0) }
        sectionUnitMap.keys.forEach { chars.insert($0) }
        return chars
    }()

    /// 将文本中的中文数字转换为阿拉伯数字
    static func convert(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        var result = ""
        var i = text.startIndex

        while i < text.endIndex {
            let ch = text[i]

            if allChineseNumberChars.contains(ch) {
                // 收集连续的中文数字字符
                let start = i
                var end = text.index(after: i)
                while end < text.endIndex && allChineseNumberChars.contains(text[end]) {
                    end = text.index(after: end)
                }

                let chineseNum = String(text[start..<end])

                // 判断是序列模式（如电话号码"一三八"→"138"）还是权位模式（如"一百二十三"→"123"）
                if isSequenceMode(chineseNum) {
                    result += convertSequence(chineseNum)
                } else {
                    result += String(convertWithUnits(chineseNum))
                }

                i = end
            } else {
                result.append(ch)
                i = text.index(after: i)
            }
        }

        return result
    }

    /// 判断是否为序列模式（无权位词，如"一三八零零"→"13800"）
    private static func isSequenceMode(_ str: String) -> Bool {
        for ch in str {
            if innerUnitMap[ch] != nil || sectionUnitMap[ch] != nil {
                return false
            }
        }
        return true
    }

    /// 序列模式：每个中文数字直接映射为对应数字（如"一三八"→"138"）
    private static func convertSequence(_ str: String) -> String {
        var result = ""
        for ch in str {
            if let d = digitMap[ch] {
                result += String(d)
            }
        }
        return result
    }

    /// 权位模式：解析中文数字的进位结构（如"一千二百三十四"→1234）
    /// 支持: 十百千(节内权位) + 万亿(节权位)
    private static func convertWithUnits(_ str: String) -> Int {
        let chars = Array(str)
        var total = 0       // 最终结果
        var section = 0     // 当前节的值（万以下或亿以下）
        var current = 0     // 当前待处理的数字
        var hasDigit = false

        for ch in chars {
            if let d = digitMap[ch] {
                current = d
                hasDigit = true
            } else if let unit = innerUnitMap[ch] {
                // "十百千" — 节内权位
                if !hasDigit {
                    // 处理省略写法，如"十二"=12（省略了"一"）
                    current = 1
                }
                section += current * unit
                current = 0
                hasDigit = false
            } else if let unit = sectionUnitMap[ch] {
                // "万亿" — 节权位
                if hasDigit {
                    section += current
                    current = 0
                    hasDigit = false
                }
                if section == 0 { section = 1 }
                total += section * unit
                section = 0
            }
        }

        // 处理剩余
        if hasDigit {
            section += current
        }
        total += section

        return total
    }
}
