import Foundation

/// 关键词条目（LLM 分析结果）
struct KeywordEntry: Codable, Equatable {
    let term: String
    let frequency: Int
    let confidence: Double
}

/// 建议术语条目（LLM 分析结果）
struct SuggestedTermEntry: Codable, Equatable {
    let original: String      // 可能的错误写法
    let correction: String    // 正确写法
    let reason: String        // 建议原因
}

/// 历史分析结果
struct HistoryAnalysisResult: Codable, Equatable {
    /// 应用名称
    let appName: String

    /// 分析的记录数量
    let analyzedCount: Int

    /// 提取的关键词列表
    let keywords: [KeywordEntry]

    /// 建议的术语列表
    let suggestedTerms: [SuggestedTermEntry]

    /// 分析时间戳
    let timestamp: Date

    /// 从服务器响应解析
    static func fromServerResponse(_ dict: [String: Any]) -> HistoryAnalysisResult? {
        guard let appName = dict["app_name"] as? String,
              let analyzedCount = dict["analyzed_count"] as? Int else {
            return nil
        }

        var keywords: [KeywordEntry] = []
        if let keywordDicts = dict["keywords"] as? [[String: Any]] {
            for kw in keywordDicts {
                if let term = kw["term"] as? String,
                   let frequency = kw["frequency"] as? Int,
                   let confidence = kw["confidence"] as? Double {
                    keywords.append(KeywordEntry(term: term, frequency: frequency, confidence: confidence))
                }
            }
        }

        var suggestedTerms: [SuggestedTermEntry] = []
        if let termDicts = dict["suggested_terms"] as? [[String: Any]] {
            for term in termDicts {
                if let original = term["original"] as? String,
                   let correction = term["correction"] as? String,
                   let reason = term["reason"] as? String {
                    suggestedTerms.append(SuggestedTermEntry(original: original, correction: correction, reason: reason))
                }
            }
        }

        return HistoryAnalysisResult(
            appName: appName,
            analyzedCount: analyzedCount,
            keywords: keywords,
            suggestedTerms: suggestedTerms,
            timestamp: Date()
        )
    }
}
