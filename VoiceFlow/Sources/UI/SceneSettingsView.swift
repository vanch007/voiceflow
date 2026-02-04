import AppKit
import SwiftUI

/// 场景设置标签页
struct SceneSettingsTab: View {
    @ObservedObject private var sceneManager = SceneManager.shared
    @State private var selectedSceneType: SceneType = .general
    @State private var editingProfile: SceneProfile?
    @State private var showingAddRuleSheet = false

    var body: some View {
        HSplitView {
            // 左侧：场景类型列表
            VStack(alignment: .leading, spacing: 0) {
                // 自动检测开关
                HStack {
                    Toggle("自动检测场景", isOn: Binding(
                        get: { sceneManager.isAutoDetectEnabled },
                        set: { sceneManager.isAutoDetectEnabled = $0 }
                    ))
                    .toggleStyle(.switch)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // 场景类型列表
                List(SceneType.allCases, id: \.self, selection: $selectedSceneType) { sceneType in
                    HStack(spacing: 12) {
                        Image(systemName: sceneType.icon)
                            .font(.title2)
                            .foregroundColor(.accentColor)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(sceneType.displayName)
                                    .font(.headline)

                                if sceneManager.currentScene == sceneType && sceneManager.isAutoDetectEnabled {
                                    Text("当前")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }

                            Text(sceneType.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        // 显示配置状态
                        let profile = sceneManager.getProfile(for: sceneType)
                        if profile.enablePolish {
                            Image(systemName: "sparkles")
                                .foregroundColor(.orange)
                                .help("已启用润色")
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(sceneType)
                }
            }
            .frame(minWidth: 250)

            // 右侧：场景配置编辑器
            SceneProfileEditor(
                sceneType: selectedSceneType,
                sceneManager: sceneManager,
                showingAddRuleSheet: $showingAddRuleSheet
            )
        }
        .sheet(isPresented: $showingAddRuleSheet) {
            AddSceneRuleSheet(
                sceneManager: sceneManager,
                selectedSceneType: selectedSceneType,
                isPresented: $showingAddRuleSheet
            )
        }
    }
}

/// 场景配置编辑器
private struct SceneProfileEditor: View {
    let sceneType: SceneType
    @ObservedObject var sceneManager: SceneManager
    @Binding var showingAddRuleSheet: Bool

    @State private var language: ASRLanguage = .auto
    @State private var enablePolish: Bool = false
    @State private var polishStyle: PolishStyle = .neutral
    @State private var customPrompt: String = ""
    @State private var glossary: [GlossaryEntry] = []
    @State private var showingAddGlossarySheet: Bool = false
    @State private var editingGlossaryEntry: GlossaryEntry? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 场景标题
                HStack {
                    Image(systemName: sceneType.icon)
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(sceneType.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(sceneType.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                Divider()

                // 语言设置
                VStack(alignment: .leading, spacing: 8) {
                    Text("识别语言")
                        .fontWeight(.medium)

                    Picker("", selection: $language) {
                        ForEach(ASRLanguage.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: 200)

                    Text("为此场景指定特定语言，或选择「自动检测」")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // 润色设置
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("启用 AI 文本润色", isOn: $enablePolish)

                    if enablePolish {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("润色风格")
                                .fontWeight(.medium)

                            Picker("", selection: $polishStyle) {
                                ForEach(PolishStyle.allCases, id: \.self) { style in
                                    VStack(alignment: .leading) {
                                        Text(style.displayName)
                                    }
                                    .tag(style)
                                }
                            }
                            .pickerStyle(.radioGroup)

                            Text(polishStyle.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 20)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("自定义提示词（可选）")
                                .fontWeight(.medium)

                            TextEditor(text: $customPrompt)
                                .font(.system(.body, design: .monospaced))
                                .frame(height: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )

                            Text("留空使用默认提示词，或输入自定义提示词覆盖")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 20)
                    }
                }

                Divider()

                // 术语字典
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("术语字典")
                            .fontWeight(.medium)

                        Spacer()

                        Button(action: { showingAddGlossarySheet = true }) {
                            Image(systemName: "plus")
                        }
                        .help("添加术语")
                    }

                    Text("将 ASR 可能误识别的词汇自动替换为正确写法")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if glossary.isEmpty {
                        Text("暂无术语")
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(glossary) { entry in
                                    HStack {
                                        Text(entry.term)
                                            .foregroundColor(.secondary)
                                        Image(systemName: "arrow.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(entry.replacement)
                                            .fontWeight(.medium)

                                        if entry.caseSensitive {
                                            Text("Aa")
                                                .font(.caption2)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.2))
                                                .cornerRadius(3)
                                                .help("区分大小写")
                                        }

                                        Spacer()

                                        Button(action: {
                                            editingGlossaryEntry = entry
                                            showingAddGlossarySheet = true
                                        }) {
                                            Image(systemName: "pencil")
                                                .foregroundColor(.accentColor)
                                        }
                                        .buttonStyle(.plain)
                                        .help("编辑")

                                        Button(action: {
                                            glossary.removeAll { $0.id == entry.id }
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                        .help("删除")
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(4)
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                    }
                }

                Divider()

                // 应用规则
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("应用规则")
                            .fontWeight(.medium)

                        Spacer()

                        Button(action: { showingAddRuleSheet = true }) {
                            Image(systemName: "plus")
                        }
                        .help("添加自定义规则")
                    }

                    let rules = sceneManager.getAllRules().filter { $0.sceneType == sceneType }

                    if rules.isEmpty {
                        Text("暂无应用规则")
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(rules, id: \.bundleID) { rule in
                            HStack {
                                Image(systemName: rule.isBuiltin ? "app.fill" : "person.fill")
                                    .foregroundColor(rule.isBuiltin ? .secondary : .accentColor)
                                    .frame(width: 20)

                                Text(rule.appName)

                                Spacer()

                                if rule.isBuiltin {
                                    Text("内置")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Button(action: {
                                        sceneManager.removeRule(bundleID: rule.bundleID)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Spacer()

                // 保存按钮
                HStack {
                    Spacer()

                    Button("恢复默认") {
                        loadProfile(SceneProfile.defaultProfile(for: sceneType))
                    }

                    Button("保存") {
                        saveProfile()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .onAppear {
            loadCurrentProfile()
        }
        .onChange(of: sceneType) { _ in
            loadCurrentProfile()
        }
        .sheet(isPresented: $showingAddGlossarySheet, onDismiss: {
            editingGlossaryEntry = nil
        }) {
            AddGlossaryEntrySheet(
                glossary: $glossary,
                editingEntry: editingGlossaryEntry,
                isPresented: $showingAddGlossarySheet
            )
        }
    }

    private func loadCurrentProfile() {
        let profile = sceneManager.getProfile(for: sceneType)
        loadProfile(profile)
    }

    private func loadProfile(_ profile: SceneProfile) {
        language = profile.language
        enablePolish = profile.enablePolish
        polishStyle = profile.polishStyle
        customPrompt = profile.customPrompt ?? ""
        glossary = profile.glossary
    }

    private func saveProfile() {
        let profile = SceneProfile(
            sceneType: sceneType,
            language: language,
            enablePolish: enablePolish,
            polishStyle: polishStyle,
            enabledPluginIDs: [],
            customPrompt: customPrompt.isEmpty ? nil : customPrompt,
            glossary: glossary
        )
        sceneManager.updateProfile(profile)
    }
}

/// 添加/编辑术语条目的 Sheet
private struct AddGlossaryEntrySheet: View {
    @Binding var glossary: [GlossaryEntry]
    let editingEntry: GlossaryEntry?
    @Binding var isPresented: Bool

    @State private var term: String = ""
    @State private var replacement: String = ""
    @State private var caseSensitive: Bool = false

    private var isEditing: Bool { editingEntry != nil }

    var body: some View {
        VStack(spacing: 20) {
            Text(isEditing ? "编辑术语" : "添加术语")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("识别文本")
                        .fontWeight(.medium)
                    TextField("ASR 可能识别的写法，如「杰森」", text: $term)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("替换为")
                        .fontWeight(.medium)
                    TextField("正确写法，如「JSON」", text: $replacement)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("区分大小写", isOn: $caseSensitive)
                    .toggleStyle(.checkbox)

                Text("术语替换会在 ASR 转录后、AI 润色前执行")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack {
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isEditing ? "保存" : "添加") {
                    saveEntry()
                }
                .buttonStyle(.borderedProminent)
                .disabled(term.isEmpty || replacement.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 350, height: 280)
        .onAppear {
            if let entry = editingEntry {
                term = entry.term
                replacement = entry.replacement
                caseSensitive = entry.caseSensitive
            }
        }
    }

    private func saveEntry() {
        if let existing = editingEntry {
            // 编辑现有条目
            if let index = glossary.firstIndex(where: { $0.id == existing.id }) {
                glossary[index] = GlossaryEntry(
                    id: existing.id,
                    term: term,
                    replacement: replacement,
                    caseSensitive: caseSensitive
                )
            }
        } else {
            // 添加新条目
            let entry = GlossaryEntry(
                term: term,
                replacement: replacement,
                caseSensitive: caseSensitive
            )
            glossary.append(entry)
        }
        isPresented = false
    }
}

/// 添加场景规则的 Sheet
private struct AddSceneRuleSheet: View {
    @ObservedObject var sceneManager: SceneManager
    let selectedSceneType: SceneType
    @Binding var isPresented: Bool

    @State private var appName: String = ""
    @State private var bundleID: String = ""
    @State private var runningApps: [(name: String, bundleID: String)] = []

    var body: some View {
        VStack(spacing: 20) {
            Text("添加应用规则")
                .font(.title2)
                .fontWeight(.semibold)

            // 从运行中的应用选择
            VStack(alignment: .leading, spacing: 8) {
                Text("从运行中的应用选择：")
                    .fontWeight(.medium)

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(runningApps, id: \.bundleID) { app in
                            Button(action: {
                                appName = app.name
                                bundleID = app.bundleID
                            }) {
                                HStack {
                                    Text(app.name)
                                    Spacer()
                                    if bundleID == app.bundleID {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(bundleID == app.bundleID ? Color.accentColor.opacity(0.1) : Color.clear)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 150)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }

            // 手动输入
            VStack(alignment: .leading, spacing: 8) {
                Text("或手动输入：")
                    .fontWeight(.medium)

                TextField("应用名称", text: $appName)
                TextField("Bundle ID", text: $bundleID)
                    .font(.system(.body, design: .monospaced))
            }

            // 目标场景
            HStack {
                Text("目标场景：")
                    .fontWeight(.medium)

                Image(systemName: selectedSceneType.icon)
                    .foregroundColor(.accentColor)

                Text(selectedSceneType.displayName)
            }

            Spacer()

            // 按钮
            HStack {
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("添加") {
                    addRule()
                }
                .buttonStyle(.borderedProminent)
                .disabled(appName.isEmpty || bundleID.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400, height: 450)
        .onAppear {
            loadRunningApps()
        }
    }

    private func loadRunningApps() {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> (name: String, bundleID: String)? in
                guard let name = app.localizedName,
                      let bundleID = app.bundleIdentifier else { return nil }
                return (name: name, bundleID: bundleID)
            }
            .sorted { $0.name < $1.name }

        runningApps = apps
    }

    private func addRule() {
        let rule = SceneRule(
            bundleID: bundleID,
            appName: appName,
            sceneType: selectedSceneType,
            isBuiltin: false
        )
        sceneManager.addRule(rule)
        isPresented = false
    }
}

// MARK: - Preview

#Preview("Scene Settings") {
    SceneSettingsTab()
        .frame(width: 700, height: 500)
}
