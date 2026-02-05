import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    private let settingsManager: SettingsManager
    private let replacementStorage: ReplacementStorage
    private let recordingHistory: RecordingHistory

    init(settingsManager: SettingsManager, replacementStorage: ReplacementStorage, recordingHistory: RecordingHistory) {
        self.settingsManager = settingsManager
        self.replacementStorage = replacementStorage
        self.recordingHistory = recordingHistory

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "设置"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)

        let contentView = NSHostingView(
            rootView: SettingsContentView(
                settingsManager: settingsManager,
                replacementStorage: replacementStorage,
                recordingHistory: recordingHistory
            )
        )
        window.contentView = contentView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct SettingsContentView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var replacementStorage: ReplacementStorage
    let recordingHistory: RecordingHistory
    @State private var pluginInfoList: [PluginInfo] = []

    var body: some View {
        TabView {
            // 通用设置标签页
            GeneralSettingsTab(settingsManager: settingsManager)
                .tabItem { Label("通用", systemImage: "gear") }

            // LLM 设置标签页
            LLMSettingsView(settingsManager: settingsManager)
                .tabItem { Label("LLM", systemImage: "brain") }

            // 场景设置标签页
            SceneSettingsTab()
                .tabItem { Label("场景", systemImage: "sparkles.rectangle.stack") }

            // 录音记录标签页
            RecordingHistoryTab(recordingHistory: recordingHistory)
                .tabItem { Label("录音记录", systemImage: "waveform") }

            // 文本替换标签页
            TextReplacementTab(replacementStorage: replacementStorage)
                .tabItem { Label("文本替换", systemImage: "textformat.alt") }

            // 插件标签页
            PluginSettingsTab(pluginInfoList: $pluginInfoList)
                .tabItem { Label("插件", systemImage: "puzzlepiece") }
        }
        .frame(width: 800, height: 600)
        .padding()
        .onAppear {
            pluginInfoList = PluginManager.shared.getAllPlugins()
            PluginManager.shared.onPluginLoaded = { _ in
                DispatchQueue.main.async {
                    pluginInfoList = PluginManager.shared.getAllPlugins()
                }
            }
            PluginManager.shared.onPluginUnloaded = { _ in
                DispatchQueue.main.async {
                    pluginInfoList = PluginManager.shared.getAllPlugins()
                }
            }
            PluginManager.shared.onPluginStateChanged = { _ in
                DispatchQueue.main.async {
                    pluginInfoList = PluginManager.shared.getAllPlugins()
                }
            }
        }
        .onDisappear {
            PluginManager.shared.onPluginLoaded = nil
            PluginManager.shared.onPluginUnloaded = nil
            PluginManager.shared.onPluginStateChanged = nil
        }
    }
}

// 通用设置标签页（复用现有SettingsWindow的内容）
private struct GeneralSettingsTab: View {
    @ObservedObject var settingsManager: SettingsManager

    var body: some View {
        Form {
            Section("热键设置") {
                Toggle("启用长按 Option 录音", isOn: $settingsManager.hotkeyEnabled)
                Text("长按左侧或右侧 Option (⌥) 键开始录音，松开停止")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("模型选择") {
                Picker("识别模型", selection: $settingsManager.modelSize) {
                    ForEach(ModelSize.allCases, id: \.self) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("语言设置") {
                Picker("识别语言", selection: $settingsManager.asrLanguage) {
                    ForEach(ASRLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                Text("选择「自动检测」可让模型自动识别语言，或指定特定语言以提高准确率。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("文本处理") {
                Toggle("启用 AI 文本润色", isOn: $settingsManager.textPolishEnabled)
                Text("自动去除语气词（嗯、那个、然后等）并改善语法")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("启动选项") {
                Toggle("开机自动启动", isOn: $settingsManager.autoLaunchEnabled)
            }
        }
        .formStyle(.grouped)
    }
}

// 文本替换标签页（新增）
private struct TextReplacementTab: View {
    @ObservedObject var replacementStorage: ReplacementStorage
    @State private var selectedRule: ReplacementRule?
    @State private var isEditing = false

    var body: some View {
        HSplitView {
            // 左侧：规则列表
            VStack {
                List(selection: $selectedRule) {
                    ForEach(replacementStorage.rules) { rule in
                        HStack {
                            Toggle("", isOn: binding(for: rule))
                                .labelsHidden()
                            VStack(alignment: .leading) {
                                Text(rule.trigger)
                                    .font(.headline)
                                Text(rule.replacement.prefix(30))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tag(rule)
                    }
                }

                HStack {
                    Button(action: addRule) {
                        Image(systemName: "plus")
                    }
                    Button(action: deleteRule) {
                        Image(systemName: "minus")
                    }
                    .disabled(selectedRule == nil)
                }
                .padding(8)
            }
            .frame(minWidth: 250)

            // 右侧：规则编辑器
            if let rule = selectedRule {
                RuleEditorView(rule: rule, storage: replacementStorage)
            } else {
                Text("选择一个规则进行编辑")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func binding(for rule: ReplacementRule) -> Binding<Bool> {
        Binding(
            get: { rule.isEnabled },
            set: { newValue in
                var updated = rule
                updated.isEnabled = newValue
                replacementStorage.update(updated)
            }
        )
    }

    private func addRule() {
        let newRule = ReplacementRule(trigger: "新触发词", replacement: "替换内容")
        replacementStorage.add(newRule)
        selectedRule = newRule
    }

    private func deleteRule() {
        guard let rule = selectedRule else { return }
        replacementStorage.delete(id: rule.id)
        selectedRule = nil
    }
}

private struct RuleEditorView: View {
    let rule: ReplacementRule
    let storage: ReplacementStorage

    @State private var trigger: String
    @State private var replacement: String

    init(rule: ReplacementRule, storage: ReplacementStorage) {
        self.rule = rule
        self.storage = storage
        _trigger = State(initialValue: rule.trigger)
        _replacement = State(initialValue: rule.replacement)
    }

    var body: some View {
        Form {
            TextField("触发词", text: $trigger)
            TextEditor(text: $replacement)
                .frame(minHeight: 100)

            Button("保存") {
                var updated = rule
                updated.trigger = trigger
                updated.replacement = replacement
                storage.update(updated)
            }
        }
        .padding()
    }
}

// 录音记录标签页
private struct RecordingHistoryTab: View {
    let recordingHistory: RecordingHistory
    @State private var entries: [RecordingEntry] = []
    @State private var searchQuery: String = ""
    @State private var selectedEntry: RecordingEntry?
    @State private var selectedApp: String = "全部"
    @State private var sortAscending: Bool = false  // false = 倒序（最新在前）

    // 获取所有应用列表
    var appList: [String] {
        var apps = Set<String>()
        for entry in entries {
            if let appName = entry.appName, !appName.isEmpty {
                apps.insert(appName)
            }
        }
        return ["全部"] + apps.sorted()
    }

    var filteredEntries: [RecordingEntry] {
        var result = entries

        // 应用筛选
        if selectedApp != "全部" {
            result = result.filter { $0.appName == selectedApp }
        }

        // 搜索筛选
        if !searchQuery.isEmpty {
            result = result.filter { $0.text.localizedCaseInsensitiveContains(searchQuery) }
        }

        // 时间排序
        if sortAscending {
            result = result.sorted { $0.timestamp < $1.timestamp }
        } else {
            result = result.sorted { $0.timestamp > $1.timestamp }
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                TextField("搜索...", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)

                // 应用筛选
                Picker("应用", selection: $selectedApp) {
                    ForEach(appList, id: \.self) { app in
                        Text(app).tag(app)
                    }
                }
                .frame(width: 150)

                // 排序按钮
                Button(action: {
                    sortAscending.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                        Text(sortAscending ? "旧→新" : "新→旧")
                    }
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("全部删除") {
                    clearAll()
                }
                .disabled(entries.isEmpty)
            }
            .padding()

            Divider()

            // 列表
            List(filteredEntries, selection: $selectedEntry) { entry in
                HStack {
                    Text(formatTimestamp(entry.timestamp))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 140, alignment: .leading)

                    // 应用名称
                    Text(entry.appName ?? "-")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 100, alignment: .leading)
                        .lineLimit(1)

                    Text(entry.text)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    Text(formatDuration(entry.duration))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .trailing)
                }
                .tag(entry)
                .contextMenu {
                    Button("复制文本") {
                        copyText(entry)
                    }
                    Button("删除", role: .destructive) {
                        deleteEntry(entry)
                    }
                }
            }
        }
        .onAppear {
            entries = recordingHistory.entries
            recordingHistory.onEntriesChanged = {
                entries = recordingHistory.entries
            }
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        if seconds < 60 {
            return "\(seconds)秒"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return "\(minutes)分\(remainingSeconds)秒"
        }
    }

    private func copyText(_ entry: RecordingEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)
    }

    private func deleteEntry(_ entry: RecordingEntry) {
        recordingHistory.deleteEntry(id: entry.id)
    }

    private func clearAll() {
        recordingHistory.clearAll()
    }
}

// 插件设置标签页
private struct PluginSettingsTab: View {
    @Binding var pluginInfoList: [PluginInfo]
    @State private var selectedPlugin: PluginInfo?

    var body: some View {
        HSplitView {
            // 左侧：插件列表
            VStack(alignment: .leading) {
                List(pluginInfoList, id: \.manifest.id, selection: Binding(
                    get: { selectedPlugin?.manifest.id },
                    set: { newID in
                        selectedPlugin = pluginInfoList.first { $0.manifest.id == newID }
                    }
                )) { plugin in
                    HStack {
                        Circle()
                            .fill(plugin.isEnabled ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading) {
                            Text(plugin.manifest.name)
                                .font(.headline)
                            Text("v\(plugin.manifest.version)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(plugin.manifest.id)
                }

                if pluginInfoList.isEmpty {
                    VStack {
                        Spacer()
                        Text("暂无插件")
                            .foregroundColor(.secondary)
                        Text("将插件放入 ~/Library/Application Support/VoiceFlow/Plugins/ 目录")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                    }
                }

                HStack {
                    Button(action: refreshPlugins) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("刷新插件列表")

                    Button(action: openPluginsFolder) {
                        Image(systemName: "folder")
                    }
                    .help("打开插件目录")
                }
                .padding(8)
            }
            .frame(minWidth: 200)

            // 右侧：插件详情
            if let plugin = selectedPlugin {
                PluginDetailView(plugin: plugin, onToggle: {
                    togglePlugin(plugin)
                })
                .frame(minWidth: 350)
            } else {
                VStack {
                    Spacer()
                    Text("选择一个插件查看详情")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func refreshPlugins() {
        PluginManager.shared.discoverPlugins()
        pluginInfoList = PluginManager.shared.getAllPlugins()
    }

    private func openPluginsFolder() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let pluginsDir = appSupport.appendingPathComponent("VoiceFlow/Plugins")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: pluginsDir, withIntermediateDirectories: true)

        NSWorkspace.shared.open(pluginsDir)
    }

    private func togglePlugin(_ plugin: PluginInfo) {
        if plugin.isEnabled {
            PluginManager.shared.disablePlugin(plugin.manifest.id)
        } else {
            PluginManager.shared.enablePlugin(plugin.manifest.id)
        }
        pluginInfoList = PluginManager.shared.getAllPlugins()
        selectedPlugin = pluginInfoList.first { $0.manifest.id == plugin.manifest.id }
    }
}

private struct PluginDetailView: View {
    let plugin: PluginInfo
    let onToggle: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 标题
                HStack {
                    Image(systemName: platformIcon)
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(plugin.manifest.name)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("v\(plugin.manifest.version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("启用", isOn: Binding(
                        get: { plugin.isEnabled },
                        set: { _ in onToggle() }
                    ))
                    .toggleStyle(.switch)
                }

                // 描述信息（开关下方）
                Text(plugin.manifest.description)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                // 状态
                HStack {
                    Text("状态:")
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusText)
                            .foregroundColor(.secondary)
                    }
                }

                // 作者
                VStack(alignment: .leading, spacing: 4) {
                    Text("开发者:")
                        .fontWeight(.medium)
                    Text(plugin.manifest.author)
                        .foregroundColor(.secondary)
                }

                // 描述
                VStack(alignment: .leading, spacing: 4) {
                    Text("描述:")
                        .fontWeight(.medium)
                    Text(plugin.manifest.description)
                        .foregroundColor(.secondary)
                }

                // 平台
                VStack(alignment: .leading, spacing: 4) {
                    Text("平台:")
                        .fontWeight(.medium)
                    HStack(spacing: 4) {
                        Image(systemName: platformIcon)
                            .foregroundColor(.accentColor)
                        Text(platformText)
                            .foregroundColor(.secondary)
                    }
                }

                // 权限
                if !plugin.manifest.permissions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("权限:")
                            .fontWeight(.medium)
                        ForEach(plugin.manifest.permissions, id: \.self) { permission in
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text(permission)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // 插件 ID
                VStack(alignment: .leading, spacing: 4) {
                    Text("ID:")
                        .fontWeight(.medium)
                    Text(plugin.manifest.id)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
        }
    }

    private var platformIcon: String {
        switch plugin.manifest.platform {
        case .swift:
            return "swift"
        case .python:
            return "chevron.left.forwardslash.chevron.right"
        case .both:
            return "doc.on.doc"
        }
    }

    private var platformText: String {
        switch plugin.manifest.platform {
        case .swift:
            return "Swift"
        case .python:
            return "Python"
        case .both:
            return "Swift + Python"
        }
    }

    private var statusColor: Color {
        switch plugin.state {
        case .enabled:
            return .green
        case .disabled, .loaded:
            return .gray
        case .failed:
            return .red
        }
    }

    private var statusText: String {
        switch plugin.state {
        case .enabled:
            return "已启用"
        case .disabled:
            return "已禁用"
        case .loaded:
            return "已加载"
        case .failed(let error):
            return "失败: \(error.localizedDescription)"
        }
    }
}
#Preview("Settings - Default") {
    SettingsContentView(
        settingsManager: SettingsManager.shared,
        replacementStorage: ReplacementStorage(),
        recordingHistory: RecordingHistory()
    )
}

#Preview("Settings - General Tab") {
    GeneralSettingsTab(settingsManager: SettingsManager.shared)
        .frame(width: 600, height: 600)
}

#Preview("Settings - Text Replacement") {
    TextReplacementTab(replacementStorage: ReplacementStorage())
        .frame(width: 600, height: 600)
}

private func mockPlugins() -> [PluginInfo] {
    let manifest1 = PluginManifest(
        id: "com.example.echo",
        name: "Echo",
        version: "1.0.0",
        author: "Example Dev",
        description: "Echoes back the transcription.",
        entrypoint: "EchoPlugin.bundle",
        permissions: ["transcription"],
        platform: .swift
    )
    let manifest2 = PluginManifest(
        id: "com.example.polish",
        name: "Polish",
        version: "1.2.0",
        author: "Example Dev",
        description: "Polishes text grammar and style.",
        entrypoint: "PolishPlugin.bundle",
        permissions: ["transcription"],
        platform: .swift
    )
    let info1 = PluginInfo(manifest: manifest1, state: .enabled)
    let info2 = PluginInfo(manifest: manifest2, state: .disabled)
    return [info1, info2]
}

private struct PluginSettingsPreviewWrapper: View {
    @State private var list: [PluginInfo] = mockPlugins()
    var body: some View {
        PluginSettingsTab(pluginInfoList: $list)
            .frame(width: 600, height: 600)
    }
}

#Preview("Settings - Plugins") {
    PluginSettingsPreviewWrapper()
}

