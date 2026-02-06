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

            Section("断句优化") {
                Toggle("智能断句（基于停顿时长）", isOn: $settingsManager.useTimestamps)
                Text("使用 AI 模型分析语音停顿，自动插入标点符号")
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

// MARK: - 文本替换标签页（按替换词分组 + 场景筛选）

/// 替换词分组模型
private struct ReplacementGroup: Identifiable, Hashable {
    let id: String  // replacement 作为唯一标识
    let replacement: String
    var triggers: [ReplacementRule]
    var scenes: Set<SceneType>
    var isEnabled: Bool  // 组内是否有启用的规则

    static func == (lhs: ReplacementGroup, rhs: ReplacementGroup) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct TextReplacementTab: View {
    @ObservedObject var replacementStorage: ReplacementStorage
    @State private var selectedGroup: ReplacementGroup?
    @State private var selectedSceneFilter: SceneType? = nil  // nil = 全部
    @State private var showingAddGroupSheet = false
    @State private var searchText = ""

    /// 将规则按替换词分组
    private var groupedRules: [ReplacementGroup] {
        var groups: [String: ReplacementGroup] = [:]

        for rule in replacementStorage.rules {
            let key = rule.replacement.lowercased()
            if var existing = groups[key] {
                existing.triggers.append(rule)
                existing.scenes.formUnion(rule.applicableScenes)
                if rule.isEnabled {
                    existing.isEnabled = true
                }
                groups[key] = existing
            } else {
                groups[key] = ReplacementGroup(
                    id: key,
                    replacement: rule.replacement,
                    triggers: [rule],
                    scenes: Set(rule.applicableScenes),
                    isEnabled: rule.isEnabled
                )
            }
        }

        var result = Array(groups.values)

        // 场景筛选
        if let scene = selectedSceneFilter {
            result = result.filter { group in
                group.scenes.contains(scene) || group.scenes.isEmpty
            }
        }

        // 搜索筛选
        if !searchText.isEmpty {
            result = result.filter { group in
                group.replacement.localizedCaseInsensitiveContains(searchText) ||
                group.triggers.contains { $0.trigger.localizedCaseInsensitiveContains(searchText) }
            }
        }

        // 按替换词排序
        return result.sorted { $0.replacement.lowercased() < $1.replacement.lowercased() }
    }

    var body: some View {
        HSplitView {
            // 左侧：场景筛选 + 分组列表
            VStack(spacing: 0) {
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .padding(.horizontal, 12)
                .padding(.top, 12)

                // 场景筛选器
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        SceneFilterChip(
                            title: "全部",
                            icon: "square.grid.2x2",
                            isSelected: selectedSceneFilter == nil,
                            action: { selectedSceneFilter = nil }
                        )

                        ForEach(SceneType.allCases, id: \.self) { scene in
                            SceneFilterChip(
                                title: scene.displayName,
                                icon: scene.icon,
                                isSelected: selectedSceneFilter == scene,
                                action: { selectedSceneFilter = scene }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }

                Divider()

                // 分组列表
                List(groupedRules, selection: $selectedGroup) { group in
                    ReplacementGroupRow(group: group, storage: replacementStorage)
                        .tag(group)
                }
                .listStyle(.plain)

                Divider()

                // 底部工具栏
                HStack {
                    Button(action: { showingAddGroupSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .help("添加替换词")

                    Spacer()

                    Text("\(groupedRules.count) 个替换词")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }
            .frame(minWidth: 280)

            // 右侧：分组编辑器
            if let group = selectedGroup {
                GroupEditorView(
                    group: group,
                    storage: replacementStorage,
                    onGroupDeleted: { selectedGroup = nil }
                )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "textformat.alt")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("选择一个替换词进行编辑")
                        .foregroundColor(.secondary)
                    Text("或点击 + 添加新的替换词")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingAddGroupSheet) {
            AddReplacementGroupSheet(
                storage: replacementStorage,
                isPresented: $showingAddGroupSheet,
                onAdded: { newGroup in
                    selectedGroup = newGroup
                }
            )
        }
    }
}

// MARK: - 场景筛选芯片

private struct SceneFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 分组行视图

private struct ReplacementGroupRow: View {
    let group: ReplacementGroup
    let storage: ReplacementStorage

    var body: some View {
        HStack(spacing: 12) {
            // 启用状态指示器
            Circle()
                .fill(group.isEnabled ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                // 替换词（主标题）
                Text(group.replacement)
                    .font(.headline)
                    .lineLimit(1)

                // 触发词列表（副标题）
                Text(group.triggers.map(\.trigger).joined(separator: " · "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 触发词数量徽章
            Text("\(group.triggers.count)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 分组编辑器

private struct GroupEditorView: View {
    let group: ReplacementGroup
    let storage: ReplacementStorage
    let onGroupDeleted: () -> Void

    @State private var triggers: [ReplacementRule] = []
    @State private var showingAddTriggerSheet = false
    @State private var editingTrigger: ReplacementRule?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 标题区域
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.replacement)
                            .font(.title)
                            .fontWeight(.bold)

                        HStack(spacing: 8) {
                            if !group.scenes.isEmpty {
                                ForEach(Array(group.scenes), id: \.self) { scene in
                                    HStack(spacing: 4) {
                                        Image(systemName: scene.icon)
                                            .font(.caption2)
                                        Text(scene.displayName)
                                            .font(.caption2)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.accentColor.opacity(0.1))
                                    .cornerRadius(4)
                                }
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "globe")
                                        .font(.caption2)
                                    Text("全局")
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                            }
                        }
                    }

                    Spacer()
                }

                Divider()

                // 触发词列表
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("触发词")
                            .font(.headline)

                        Text("(\(triggers.count)个)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(action: { showingAddTriggerSheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("添加")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }

                    Text("语音识别可能产生的各种写法")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // 触发词卡片列表
                    LazyVStack(spacing: 8) {
                        ForEach(triggers) { trigger in
                            TriggerCardView(
                                trigger: trigger,
                                onEdit: { editingTrigger = trigger },
                                onDelete: { deleteTrigger(trigger) },
                                onToggle: { toggleTrigger(trigger) }
                            )
                        }
                    }
                }

                Divider()

                // 删除整组按钮
                HStack {
                    Spacer()

                    Button(role: .destructive, action: deleteGroup) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("删除此替换词及所有触发词")
                        }
                    }
                    .foregroundColor(.red)
                }
            }
            .padding()
        }
        .onAppear {
            triggers = group.triggers
        }
        .onChange(of: group) { newGroup in
            triggers = newGroup.triggers
        }
        .sheet(isPresented: $showingAddTriggerSheet) {
            AddTriggerSheet(
                replacement: group.replacement,
                existingScenes: Array(group.scenes),
                storage: storage,
                isPresented: $showingAddTriggerSheet
            )
        }
        .sheet(item: $editingTrigger) { trigger in
            EditTriggerSheet(
                trigger: trigger,
                storage: storage,
                isPresented: Binding(
                    get: { editingTrigger != nil },
                    set: { if !$0 { editingTrigger = nil } }
                )
            )
        }
    }

    private func deleteTrigger(_ trigger: ReplacementRule) {
        storage.delete(id: trigger.id)
        triggers.removeAll { $0.id == trigger.id }

        // 如果删除后没有触发词了，通知父视图
        if triggers.isEmpty {
            onGroupDeleted()
        }
    }

    private func toggleTrigger(_ trigger: ReplacementRule) {
        var updated = trigger
        updated.isEnabled.toggle()
        storage.update(updated)
        if let index = triggers.firstIndex(where: { $0.id == trigger.id }) {
            triggers[index] = updated
        }
    }

    private func deleteGroup() {
        for trigger in triggers {
            storage.delete(id: trigger.id)
        }
        onGroupDeleted()
    }
}

// MARK: - 触发词卡片

private struct TriggerCardView: View {
    let trigger: ReplacementRule
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 启用开关
            Toggle("", isOn: Binding(
                get: { trigger.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .scaleEffect(0.8)

            // 触发词文本
            Text(trigger.trigger)
                .font(.body)
                .foregroundColor(trigger.isEnabled ? .primary : .secondary)

            Spacer()

            // 标签
            HStack(spacing: 6) {
                if trigger.caseSensitive {
                    Text("Aa")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(3)
                }

                if trigger.source == .preset {
                    Text("预设")
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15))
                        .foregroundColor(.secondary)
                        .cornerRadius(3)
                }
            }

            // 操作按钮
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.red.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - 添加替换词分组 Sheet

private struct AddReplacementGroupSheet: View {
    let storage: ReplacementStorage
    @Binding var isPresented: Bool
    let onAdded: (ReplacementGroup) -> Void

    @State private var replacement = ""
    @State private var firstTrigger = ""
    @State private var selectedScenes: Set<SceneType> = []
    @State private var caseSensitive = false

    var body: some View {
        VStack(spacing: 20) {
            Text("添加替换词")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("替换为")
                        .fontWeight(.medium)
                    TextField("正确写法，如 Python、JSON", text: $replacement)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("第一个触发词")
                        .fontWeight(.medium)
                    TextField("语音可能识别的写法，如「派森」", text: $firstTrigger)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("适用场景")
                        .fontWeight(.medium)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(SceneType.allCases, id: \.self) { scene in
                            Toggle(isOn: Binding(
                                get: { selectedScenes.contains(scene) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedScenes.insert(scene)
                                    } else {
                                        selectedScenes.remove(scene)
                                    }
                                }
                            )) {
                                HStack(spacing: 4) {
                                    Image(systemName: scene.icon)
                                        .font(.caption)
                                    Text(scene.displayName)
                                        .font(.caption)
                                }
                            }
                            .toggleStyle(.button)
                        }
                    }

                    Text("不选择则为全局规则")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Toggle("区分大小写", isOn: $caseSensitive)
            }

            Spacer()

            HStack {
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("添加") {
                    addGroup()
                }
                .buttonStyle(.borderedProminent)
                .disabled(replacement.isEmpty || firstTrigger.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400, height: 420)
    }

    private func addGroup() {
        let rule = ReplacementRule(
            trigger: firstTrigger,
            replacement: replacement,
            caseSensitive: caseSensitive,
            applicableScenes: Array(selectedScenes),
            source: .user
        )
        storage.add(rule)

        let newGroup = ReplacementGroup(
            id: replacement.lowercased(),
            replacement: replacement,
            triggers: [rule],
            scenes: selectedScenes,
            isEnabled: true
        )
        onAdded(newGroup)
        isPresented = false
    }
}

// MARK: - 添加触发词 Sheet

private struct AddTriggerSheet: View {
    let replacement: String
    let existingScenes: [SceneType]
    let storage: ReplacementStorage
    @Binding var isPresented: Bool

    @State private var trigger = ""
    @State private var caseSensitive = false

    var body: some View {
        VStack(spacing: 20) {
            Text("添加触发词")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 4) {
                Text("替换为")
                    .fontWeight(.medium)
                Text(replacement)
                    .font(.title3)
                    .foregroundColor(.accentColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text("新触发词")
                    .fontWeight(.medium)
                TextField("语音可能识别的写法", text: $trigger)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle("区分大小写", isOn: $caseSensitive)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            HStack {
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("添加") {
                    let rule = ReplacementRule(
                        trigger: trigger,
                        replacement: replacement,
                        caseSensitive: caseSensitive,
                        applicableScenes: existingScenes,
                        source: .user
                    )
                    storage.add(rule)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(trigger.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 350, height: 280)
    }
}

// MARK: - 编辑触发词 Sheet

private struct EditTriggerSheet: View {
    let trigger: ReplacementRule
    let storage: ReplacementStorage
    @Binding var isPresented: Bool

    @State private var triggerText: String
    @State private var caseSensitive: Bool
    @State private var selectedScenes: Set<SceneType>

    init(trigger: ReplacementRule, storage: ReplacementStorage, isPresented: Binding<Bool>) {
        self.trigger = trigger
        self.storage = storage
        self._isPresented = isPresented
        self._triggerText = State(initialValue: trigger.trigger)
        self._caseSensitive = State(initialValue: trigger.caseSensitive)
        self._selectedScenes = State(initialValue: Set(trigger.applicableScenes))
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("编辑触发词")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 4) {
                Text("替换为")
                    .fontWeight(.medium)
                Text(trigger.replacement)
                    .font(.title3)
                    .foregroundColor(.accentColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text("触发词")
                    .fontWeight(.medium)
                TextField("语音可能识别的写法", text: $triggerText)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle("区分大小写", isOn: $caseSensitive)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text("适用场景")
                    .fontWeight(.medium)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(SceneType.allCases, id: \.self) { scene in
                        Toggle(isOn: Binding(
                            get: { selectedScenes.contains(scene) },
                            set: { isSelected in
                                if isSelected {
                                    selectedScenes.insert(scene)
                                } else {
                                    selectedScenes.remove(scene)
                                }
                            }
                        )) {
                            HStack(spacing: 4) {
                                Image(systemName: scene.icon)
                                    .font(.caption)
                                Text(scene.displayName)
                                    .font(.caption)
                            }
                        }
                        .toggleStyle(.button)
                    }
                }
            }

            Spacer()

            HStack {
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("保存") {
                    var updated = trigger
                    updated.trigger = triggerText
                    updated.caseSensitive = caseSensitive
                    updated.applicableScenes = Array(selectedScenes)
                    storage.update(updated)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(triggerText.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400, height: 400)
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

