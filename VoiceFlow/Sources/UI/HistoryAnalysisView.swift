import SwiftUI
import Foundation

/// 历史分析结果展示视图
struct HistoryAnalysisView: View {
    let result: HistoryAnalysisResult
    let onAddToGlossary: (String, String) -> Void  // (term, replacement)
    let onAddToKeywords: ([String]) -> Void
    let onDismiss: () -> Void

    @State private var selectedKeywords: Set<String> = []
    @State private var selectedTerms: Set<Int> = []

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("历史分析结果")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("\(result.appName) - 分析了 \(result.analyzedCount) 条记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // 内容区域
            HSplitView {
                // 左侧：关键词列表
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("高频关键词")
                            .font(.headline)
                        Spacer()
                        Text("\(result.keywords.count) 个")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if result.keywords.isEmpty {
                        emptyStateView("未发现高频关键词")
                    } else {
                        List(result.keywords, id: \.term, selection: $selectedKeywords) { keyword in
                            HStack {
                                Text(keyword.term)
                                    .fontWeight(.medium)

                                Spacer()

                                Text("×\(keyword.frequency)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                confidenceBadge(keyword.confidence)
                            }
                            .tag(keyword.term)
                        }
                    }

                    if !selectedKeywords.isEmpty {
                        Button("添加选中项到场景关键词") {
                            onAddToKeywords(Array(selectedKeywords))
                            selectedKeywords.removeAll()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .frame(minWidth: 250)

                // 右侧：建议术语列表
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("建议术语")
                            .font(.headline)
                        Spacer()
                        Text("\(result.suggestedTerms.count) 个")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("LLM 识别的可能被错误转录的专业术语")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if result.suggestedTerms.isEmpty {
                        emptyStateView("未发现需要纠正的术语")
                    } else {
                        List(Array(result.suggestedTerms.enumerated()), id: \.offset) { index, term in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(term.original)
                                        .strikethrough()
                                        .foregroundColor(.red)

                                    Image(systemName: "arrow.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Text(term.correction)
                                        .fontWeight(.medium)
                                        .foregroundColor(.green)

                                    Spacer()

                                    Button("添加") {
                                        onAddToGlossary(term.original, term.correction)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }

                                Text(term.reason)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding()
                .frame(minWidth: 300)
            }

            Divider()

            // 底部操作栏
            HStack {
                Text("分析时间: \(formatDate(result.timestamp))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("关闭") {
                    onDismiss()
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    @ViewBuilder
    private func emptyStateView(_ message: String) -> some View {
        VStack {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(message)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func confidenceBadge(_ confidence: Double) -> some View {
        let color: Color = confidence >= 0.8 ? .green : (confidence >= 0.5 ? .orange : .gray)
        Text(String(format: "%.0f%%", confidence * 100))
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// 场景分析触发按钮
struct SceneAnalysisButton: View {
    let appName: String
    let isAnalyzing: Bool
    let onAnalyze: () -> Void

    var body: some View {
        Button(action: onAnalyze) {
            HStack(spacing: 6) {
                if isAnalyzing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "sparkle.magnifyingglass")
                }
                Text(isAnalyzing ? "分析中..." : "分析历史")
            }
        }
        .disabled(isAnalyzing)
        .help("分析 \(appName) 的录音历史，提取关键词和术语建议")
    }
}

#Preview("History Analysis Result") {
    let mockResult = HistoryAnalysisResult(
        appName: "Xcode",
        analyzedCount: 42,
        keywords: [
            KeywordEntry(term: "函数", frequency: 15, confidence: 0.95),
            KeywordEntry(term: "变量", frequency: 12, confidence: 0.88),
            KeywordEntry(term: "编译", frequency: 8, confidence: 0.72),
            KeywordEntry(term: "调试", frequency: 6, confidence: 0.65),
        ],
        suggestedTerms: [
            SuggestedTermEntry(original: "斯威夫特", correction: "Swift", reason: "编程语言名称"),
            SuggestedTermEntry(original: "艾克斯科德", correction: "Xcode", reason: "开发工具名称"),
        ],
        timestamp: Date()
    )

    HistoryAnalysisView(
        result: mockResult,
        onAddToGlossary: { term, replacement in
            print("Add to glossary: \(term) -> \(replacement)")
        },
        onAddToKeywords: { keywords in
            print("Add keywords: \(keywords)")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
    .frame(width: 700, height: 500)
}

#Preview("Scene Analysis Button") {
    VStack(spacing: 20) {
        SceneAnalysisButton(appName: "Xcode", isAnalyzing: false, onAnalyze: {})
        SceneAnalysisButton(appName: "Xcode", isAnalyzing: true, onAnalyze: {})
    }
    .padding()
}
