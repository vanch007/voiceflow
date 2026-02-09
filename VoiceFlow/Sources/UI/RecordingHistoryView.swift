import AppKit
import SwiftUI

final class RecordingHistoryView {
    private var window: NSWindow?
    private let recordingHistory: RecordingHistory

    init(recordingHistory: RecordingHistory) {
        self.recordingHistory = recordingHistory
    }

    func show() {
        if window == nil {
            createWindow()
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func createWindow() {
        let windowWidth: CGFloat = 700
        let windowHeight: CGFloat = 600

        let contentView = NSHostingView(
            rootView: RecordingHistoryContentView(recordingHistory: recordingHistory)
        )

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        w.title = "录音历史"
        w.contentView = contentView
        w.center()
        w.isReleasedWhenClosed = false
        w.level = .normal
        w.minSize = NSSize(width: 500, height: 400)

        window = w
    }
}

private struct RecordingHistoryContentView: View {
    let recordingHistory: RecordingHistory

    @State private var entries: [RecordingEntry] = []
    @State private var searchText: String = ""
    @State private var selectedApp: String = "全部应用"
    @State private var showDeleteConfirmation: Bool = false
    @State private var entryToDelete: RecordingEntry?
    @State private var copiedEntryId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Search and filter bar
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索录音内容...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                HStack {
                    Text("筛选应用:")
                        .foregroundColor(.secondary)
                    Picker("", selection: $selectedApp) {
                        Text("全部应用").tag("全部应用")
                        ForEach(availableApps, id: \.self) { appName in
                            Text(appName).tag(appName)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)

                    Spacer()

                    Text("\(filteredEntries.count) 条记录")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: {
                        showDeleteConfirmation = true
                        entryToDelete = nil // nil means clear all
                    }) {
                        Label("清空历史", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .disabled(entries.isEmpty)
                }
            }
            .padding()

            Divider()

            // Entry list
            if filteredEntries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(entries.isEmpty ? "暂无录音历史" : "没有匹配的记录")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    if !entries.isEmpty {
                        Text("尝试调整搜索或筛选条件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredEntries) { entry in
                        RecordingEntryRow(
                            entry: entry,
                            isCopied: copiedEntryId == entry.id,
                            onCopy: {
                                copyToClipboard(entry.text)
                                copiedEntryId = entry.id
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    if copiedEntryId == entry.id {
                                        copiedEntryId = nil
                                    }
                                }
                            },
                            onDelete: {
                                entryToDelete = entry
                                showDeleteConfirmation = true
                            }
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 700, height: 600)
        .onAppear {
            loadEntries()
            setupEntriesChangedCallback()
        }
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let entry = entryToDelete {
                    recordingHistory.deleteEntry(id: entry.id)
                } else {
                    recordingHistory.clearAll()
                }
                loadEntries()
            }
        } message: {
            if entryToDelete != nil {
                Text("确定要删除这条录音记录吗？")
            } else {
                Text("确定要清空所有录音历史吗？此操作无法撤销。")
            }
        }
    }

    private var availableApps: [String] {
        recordingHistory.uniqueAppNames()
    }

    private var filteredEntries: [RecordingEntry] {
        var result = entries

        // Apply search filter
        if !searchText.isEmpty {
            result = recordingHistory.searchEntries(query: searchText)
        }

        // Apply app filter
        if selectedApp != "全部应用" {
            result = result.filter { $0.appName == selectedApp }
        }

        return result
    }

    private func loadEntries() {
        entries = recordingHistory.entries
    }

    private func setupEntriesChangedCallback() {
        recordingHistory.onEntriesChanged = { [weak recordingHistory] in
            guard let recordingHistory = recordingHistory else { return }
            DispatchQueue.main.async {
                entries = recordingHistory.entries
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

private struct RecordingEntryRow: View {
    let entry: RecordingEntry
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: timestamp and app
            HStack {
                Text(formatTimestamp(entry.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let appName = entry.appName {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(appName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(formatDuration(entry.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Transcription text
            Text(entry.text)
                .font(.body)
                .lineLimit(3)
                .textSelection(.enabled)

            // Performance metrics
            if entry.asrLatencyMs != nil || entry.polishMethod != nil {
                HStack(spacing: 12) {
                    if let asrLatency = entry.asrLatencyMs {
                        Label("\(asrLatency)ms", systemImage: "waveform")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if let polishMethod = entry.polishMethod, polishMethod != "none" {
                        Label(polishMethodName(polishMethod), systemImage: "sparkles")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Action buttons
            HStack {
                Button(action: onCopy) {
                    Label(isCopied ? "已复制" : "复制文本", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "今天 HH:mm"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "昨天 HH:mm"
        } else {
            formatter.dateFormat = "MM-dd HH:mm"
        }
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        if seconds < 60 {
            return "\(seconds)秒"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return "\(minutes):\(String(format: "%02d", remainingSeconds))"
        }
    }

    private func polishMethodName(_ method: String) -> String {
        switch method {
        case "llm": return "LLM润色"
        case "rules": return "规则润色"
        default: return method
        }
    }
}
