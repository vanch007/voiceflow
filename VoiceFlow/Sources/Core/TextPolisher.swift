import Foundation

/// Swift 原生文本润色器（移植自 Python server/text_polisher.py）
/// 用于 Native ASR 模式下的规则润色，无需 Python 服务器
final class TextPolisher {
    static let shared = TextPolisher()

    // MARK: - 语气词正则模式

    /// 中文语气词
    private let chineseFillers: [NSRegularExpression] = {
        let patterns = [
            "嗯+",
            "呃+",
            "啊{2,}",
            "哦+",
            "(?<=[，。！？、\\s])额+(?=[，。！？、\\s]|$)|^额+(?=[，。！？、\\s]|$)",
            "(?:^|[，。！？\\s])就是说(?=[，。！？\\s]|$)",
            "怎么说呢[，,\\s]*",
            "反正[，,\\s]*(?=[，。])",
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: []) }
    }()

    /// 英文语气词
    private let englishFillers: [NSRegularExpression] = {
        let patterns = [
            "\\bum+\\b",
            "\\buh+\\b",
            "\\blike\\b(?=\\s*,)",
            "\\byou know\\b",
            "\\bbasically\\b(?=\\s*,)",
            "\\bliterally\\b(?=\\s*,)",
            "\\bright\\b(?=\\s*,)",
            "\\bso\\b(?=\\s*,)",
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
    }()

    /// 韩文语气词
    private let koreanFillers: [NSRegularExpression] = {
        let patterns = [
            "어+",
            "음+",
            "그+",
            "저+",
            "뭐+",
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: []) }
    }()

    /// 合并的语气词模式
    private let combinedFillerPattern: NSRegularExpression? = {
        let allPatterns = [
            // Chinese
            "嗯+", "呃+", "啊{2,}", "哦+",
            "(?<=[，。！？、\\s])额+(?=[，。！？、\\s]|$)|^额+(?=[，。！？、\\s]|$)",
            "(?:^|[，。！？\\s])就是说(?=[，。！？\\s]|$)",
            "怎么说呢[，,\\s]*",
            "反正[，,\\s]*(?=[，。])",
            // English
            "\\bum+\\b", "\\buh+\\b",
            "\\blike\\b(?=\\s*,)", "\\byou know\\b",
            "\\bbasically\\b(?=\\s*,)", "\\bliterally\\b(?=\\s*,)",
            "\\bright\\b(?=\\s*,)", "\\bso\\b(?=\\s*,)",
            // Korean
            "어+", "음+", "그+", "저+", "뭐+",
        ]
        let combined = "\\s*(" + allPatterns.joined(separator: "|") + ")\\s*"
        return try? NSRegularExpression(pattern: combined, options: [])
    }()

    // MARK: - 自纠正检测

    private let chineseCorrectionPatterns: [NSRegularExpression] = {
        let patterns = [
            "不对[，,\\s]*",
            "我说错了[，,\\s]*",
            "改一下[，,\\s]*",
            "纠正一下[，,\\s]*",
            "错了[，,\\s]*",
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: []) }
    }()

    private let englishCorrectionPatterns: [NSRegularExpression] = {
        let patterns = [
            "\\bno wait[,\\s]*",
            "\\bI mean[,\\s]*",
            "\\bcorrection[,\\s]*",
            "\\bactually[,\\s]*",
            "\\bsorry[,\\s]*",
            "\\blet me rephrase[,\\s]*",
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
    }()

    // MARK: - 列表格式化

    private let listPatterns: [NSRegularExpression] = {
        let patterns = [
            "第[一二三四五六七八九十]+(步|点|条|个)",
            "首先|其次|然后|最后|接着|之后",
            "\\b(first|second|third|then|next|finally)\\b",
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
    }()

    // MARK: - 辅助正则

    private let multipleSpaces = try! NSRegularExpression(pattern: "\\s+", options: [])
    private let leadingPunctuation = try! NSRegularExpression(pattern: "^[\\s，,。.！!？?、;；:：]+", options: [])
    private let doubleCommas = try! NSRegularExpression(pattern: "[，,]\\s*[，,]", options: [])
    private let doublePeriods = try! NSRegularExpression(pattern: "[。.]\\s*[。.]", options: [])
    private let endingPunctuation = try! NSRegularExpression(pattern: "[.!?。！？,，;；:：]$", options: [])
    private let chineseOrKorean = try! NSRegularExpression(pattern: "[\\u4e00-\\u9fff\\uac00-\\ud7af]", options: [])
    private let sentenceBreaks = try! NSRegularExpression(pattern: "[，,。.！!？?\\s]", options: [])

    // MARK: - Public API

    /// 润色文本：移除语气词、修复标点、格式化结构
    func polish(_ text: String) -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return text
        }

        var polished = text
        let nsRange = { NSRange(polished.startIndex..., in: polished) }

        // Step 1: 移除语气词
        if let pattern = combinedFillerPattern {
            polished = pattern.stringByReplacingMatches(in: polished, range: nsRange(), withTemplate: " ")
        }

        // Step 2: 清理多余空格
        polished = multipleSpaces.stringByReplacingMatches(in: polished, range: NSRange(polished.startIndex..., in: polished), withTemplate: " ")

        // Step 3: 清理开头孤立标点
        polished = leadingPunctuation.stringByReplacingMatches(in: polished, range: NSRange(polished.startIndex..., in: polished), withTemplate: "")

        // Step 4: 清理重复标点
        polished = doubleCommas.stringByReplacingMatches(in: polished, range: NSRange(polished.startIndex..., in: polished), withTemplate: "，")
        polished = doublePeriods.stringByReplacingMatches(in: polished, range: NSRange(polished.startIndex..., in: polished), withTemplate: "。")

        // Step 5: 去除首尾空白
        polished = polished.trimmingCharacters(in: .whitespacesAndNewlines)

        // Step 6: 列表格式化
        polished = formatList(polished)

        // Step 7: 末尾补句号
        let endRange = NSRange(polished.startIndex..., in: polished)
        if !polished.isEmpty && endingPunctuation.firstMatch(in: polished, range: endRange) == nil {
            if chineseOrKorean.firstMatch(in: polished, range: endRange) != nil {
                polished += "。"
            } else {
                polished += "."
            }
        }

        return polished
    }

    /// 检测并应用自纠正
    func detectAndCorrect(_ text: String) -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return text
        }

        var result = text

        // 中文纠正
        for pattern in chineseCorrectionPatterns {
            let range = NSRange(result.startIndex..., in: result)
            if let match = pattern.firstMatch(in: result, range: range) {
                let correctionPos = match.range.location
                let correctionEnd = match.range.location + match.range.length
                let beforeText = String(result[result.startIndex..<result.index(result.startIndex, offsetBy: correctionPos)])

                // 查找最近的断句符
                let breaks = sentenceBreaks.matches(in: beforeText, range: NSRange(beforeText.startIndex..., in: beforeText))
                if let lastBreak = breaks.last {
                    let breakEnd = lastBreak.range.location + lastBreak.range.length
                    let idx1 = result.index(result.startIndex, offsetBy: breakEnd)
                    let idx2 = result.index(result.startIndex, offsetBy: correctionEnd)
                    result = String(result[result.startIndex..<idx1]) + String(result[idx2...])
                } else {
                    let idx = result.index(result.startIndex, offsetBy: correctionEnd)
                    result = String(result[idx...])
                }
            }
        }

        // 英文纠正
        for pattern in englishCorrectionPatterns {
            let range = NSRange(result.startIndex..., in: result)
            if let match = pattern.firstMatch(in: result, range: range) {
                let correctionPos = match.range.location
                let correctionEnd = match.range.location + match.range.length
                let beforeText = String(result[result.startIndex..<result.index(result.startIndex, offsetBy: correctionPos)])

                let breaks = sentenceBreaks.matches(in: beforeText, range: NSRange(beforeText.startIndex..., in: beforeText))
                if let lastBreak = breaks.last {
                    let breakEnd = lastBreak.range.location + lastBreak.range.length
                    let idx1 = result.index(result.startIndex, offsetBy: breakEnd)
                    let idx2 = result.index(result.startIndex, offsetBy: correctionEnd)
                    result = String(result[result.startIndex..<idx1]) + String(result[idx2...])
                } else {
                    let idx = result.index(result.startIndex, offsetBy: correctionEnd)
                    result = String(result[idx...])
                }
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private

    private func formatList(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        let hasListPattern = listPatterns.contains { $0.firstMatch(in: text, range: range) != nil }
        guard hasListPattern else { return text }

        var result = text

        // 在中文序数词前添加换行
        if let pattern = try? NSRegularExpression(pattern: "(?<=[。.！!？?\\s])?(第[一二三四五六七八九十]+[步点条个])") {
            result = pattern.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "\n$1")
        }

        // 在顺序词前添加换行
        if let pattern = try? NSRegularExpression(pattern: "(?<=[。.！!？?\\s])(首先|其次|然后|最后|接着|之后)") {
            result = pattern.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "\n$1")
        }

        // 清理多余换行
        if let pattern = try? NSRegularExpression(pattern: "\n+") {
            result = pattern.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "\n")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 判断文本是否包含中文字符
    static func isChinese(_ text: String) -> Bool {
        return text.unicodeScalars.contains { $0.value >= 0x4e00 && $0.value <= 0x9fff }
    }
}
