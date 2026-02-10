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

    // 使用统一的 ReplacementStorage
    @ObservedObject private var replacementStorage = ReplacementStorage()

    // 提示词管理器
    @ObservedObject private var promptManager = PromptManager.shared

    // 词汇表管理器
    @ObservedObject private var vocabularyStorage = VocabularyStorage()

    @State private var language: ASRLanguage? = nil  // nil 表示跟随全局设置
    @State private var enablePolish: Bool = false
    @State private var polishStyle: PolishStyle = .neutral
    @State private var customPrompt: String = ""
    @State private var showingAddGlossarySheet: Bool = false
    @State private var editingRule: ReplacementRule? = nil
    @State private var selectedVocabularyIDs: Set<UUID> = []

    // 提示词编辑状态
    @State private var useCustomPrompt: Bool = false
    @State private var editablePrompt: String = ""

    // Import/Export 状态
    @State private var showExportSuccess = false
    @State private var showExportError = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""

    /// 获取当前场景的术语规则
    private var sceneGlossaryRules: [ReplacementRule] {
        replacementStorage.rules.filter { rule in
            rule.applicableScenes.contains(sceneType)
        }
    }

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
                        Text("跟随全局设置 (\(SettingsManager.shared.asrLanguage.displayName))").tag(nil as ASRLanguage?)
                        Divider()
                        ForEach(ASRLanguage.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang as ASRLanguage?)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: 280)

                    Text("选择「跟随全局设置」使用通用设置中的语言，或为此场景指定特定语言")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // AI 纠错设置
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("启用 AI 纠错", isOn: $enablePolish)

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
                            HStack {
                                Text("提示词设置")
                                    .fontWeight(.medium)

                                Spacer()

                                if promptManager.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                            }

                            Picker("", selection: $useCustomPrompt) {
                                Text("使用默认提示词").tag(false)
                                Text("使用自定义提示词").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()

                            if !useCustomPrompt {
                                // 默认提示词显示区（只读）
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("默认提示词")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    ScrollView {
                                        Text(promptManager.defaultPrompts[sceneType.rawValue] ?? "加载中...")
                                            .font(.system(.body, design: .monospaced))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(8)
                                    }
                                    .frame(height: 100)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            } else {
                                // 自定义提示词编辑区
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("自定义提示词")
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        Spacer()

                                        Button(action: {
                                            // 从默认提示词复制
                                            if let defaultPrompt = promptManager.defaultPrompts[sceneType.rawValue] {
                                                editablePrompt = defaultPrompt
                                            }
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "doc.on.doc")
                                                Text("从默认复制")
                                            }
                                            .font(.caption)
                                        }
                                        .buttonStyle(.borderless)
                                    }

                                    TextEditor(text: $editablePrompt)
                                        .font(.system(.body, design: .monospaced))
                                        .frame(height: 100)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )

                                    Text("自定义提示词将在润色时替代默认提示词使用")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.leading, 20)
                    }
                }

                Divider()

                // 词汇表关联
                VStack(alignment: .leading, spacing: 8) {
                    Text("关联词汇表")
                        .fontWeight(.medium)

                    Text("选择要在此场景中使用的词汇表，用于 ASR 热词偏置以提高识别准确度")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if vocabularyStorage.vocabularies.isEmpty {
                        HStack {
                            Text("暂无词汇表")
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)

                            Spacer()

                            Button(action: {
                                // 打开词汇表管理（在 SettingsWindow 中实现）
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle")
                                    Text("创建词汇表")
                                }
                                .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(vocabularyStorage.vocabularies) { vocabulary in
                                    HStack {
                                        Toggle(isOn: Binding(
                                            get: { selectedVocabularyIDs.contains(vocabulary.id) },
                                            set: { isSelected in
                                                if isSelected {
                                                    selectedVocabularyIDs.insert(vocabulary.id)
                                                } else {
                                                    selectedVocabularyIDs.remove(vocabulary.id)
                                                }
                                            }
                                        )) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(vocabulary.name)
                                                    .fontWeight(.medium)

                                                if !vocabulary.description.isEmpty {
                                                    Text(vocabulary.description)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                        }
                                        .toggleStyle(.checkbox)

                                        Spacer()

                                        Text("\(vocabulary.entryCount) 词条")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(selectedVocabularyIDs.contains(vocabulary.id) ? Color.accentColor.opacity(0.1) : Color.clear)
                                    .cornerRadius(4)
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                    }
                }

                Divider()

                // 术语字典（从 ReplacementStorage 读取）
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("术语字典")
                            .fontWeight(.medium)

                        Spacer()

                        Button(action: {
                            editingRule = nil
                            showingAddGlossarySheet = true
                        }) {
                            Image(systemName: "plus")
                        }
                        .help("添加术语")
                    }

                    Text("将 ASR 可能误识别的词汇自动替换为正确写法（存储在文本替换规则中）")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if sceneGlossaryRules.isEmpty {
                        Text("暂无术语")
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(sceneGlossaryRules) { rule in
                                    HStack {
                                        Text(rule.trigger)
                                            .foregroundColor(.secondary)
                                        Image(systemName: "arrow.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(rule.replacement)
                                            .fontWeight(.medium)

                                        if rule.caseSensitive {
                                            Text("Aa")
                                                .font(.caption2)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.2))
                                                .cornerRadius(3)
                                                .help("区分大小写")
                                        }

                                        if rule.source == .preset {
                                            Text("预设")
                                                .font(.caption2)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(Color.gray.opacity(0.2))
                                                .cornerRadius(3)
                                                .help("预设规则")
                                        }

                                        // 显示是否启用
                                        if !rule.isEnabled {
                                            Text("已禁用")
                                                .font(.caption2)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(Color.red.opacity(0.2))
                                                .cornerRadius(3)
                                        }

                                        Spacer()

                                        Button(action: {
                                            editingRule = rule
                                            showingAddGlossarySheet = true
                                        }) {
                                            Image(systemName: "pencil")
                                                .foregroundColor(.accentColor)
                                        }
                                        .buttonStyle(.plain)
                                        .help("编辑")

                                        Button(action: {
                                            replacementStorage.delete(id: rule.id)
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

                Divider()

                // Import/Export 场景管理
                VStack(alignment: .leading, spacing: 8) {
                    Text("场景管理")
                        .fontWeight(.medium)

                    HStack(spacing: 12) {
                        Button(action: exportScene) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("导出场景")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(action: importScene) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("导入场景")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
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
            promptManager.loadPrompts()
        }
        .onChange(of: sceneType) { _ in
            loadCurrentProfile()
        }
        .onChange(of: promptManager.customPrompts) { _ in
            // 提示词加载完成后刷新状态
            useCustomPrompt = promptManager.isUsingCustomPrompt(for: sceneType.rawValue)
            if useCustomPrompt {
                editablePrompt = promptManager.customPrompts[sceneType.rawValue] ?? ""
            }
        }
        .sheet(isPresented: $showingAddGlossarySheet, onDismiss: {
            editingRule = nil
        }) {
            AddSceneGlossarySheet(
                replacementStorage: replacementStorage,
                sceneType: sceneType,
                editingRule: editingRule,
                isPresented: $showingAddGlossarySheet
            )
        }
        .alert("导出成功", isPresented: $showExportSuccess) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("场景配置已成功导出")
        }
        .alert("导出失败", isPresented: $showExportError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("无法导出场景配置，请检查文件路径权限")
        }
        .alert("导入失败", isPresented: $showImportError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(importErrorMessage)
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
        selectedVocabularyIDs = Set(profile.vocabularyRuleIDs)

        // 加载提示词状态
        useCustomPrompt = promptManager.isUsingCustomPrompt(for: sceneType.rawValue)
        if useCustomPrompt {
            editablePrompt = promptManager.customPrompts[sceneType.rawValue] ?? ""
        } else {
            editablePrompt = ""
        }
    }

    private func saveProfile() {
        // 保存提示词到服务器
        if useCustomPrompt && !editablePrompt.isEmpty {
            promptManager.saveCustomPrompt(for: sceneType.rawValue, prompt: editablePrompt)
        } else if !useCustomPrompt && promptManager.isUsingCustomPrompt(for: sceneType.rawValue) {
            // 从自定义切换回默认
            promptManager.resetToDefault(for: sceneType.rawValue)
        }

        let profile = SceneProfile(
            sceneType: sceneType,
            language: language,
            enablePolish: enablePolish,
            polishStyle: polishStyle,
            enabledPluginIDs: [],
            customPrompt: useCustomPrompt ? editablePrompt : nil,
            vocabularyRuleIDs: Array(selectedVocabularyIDs)
        )
        sceneManager.updateProfile(profile)
    }

    private func exportScene() {
        let savePanel = NSSavePanel()
        savePanel.title = "导出场景配置"
        savePanel.message = "选择保存位置"
        savePanel.nameFieldStringValue = "\(sceneType.rawValue).vfscene"
        savePanel.allowedContentTypes = [.init(filenameExtension: "vfscene")!]
        savePanel.canCreateDirectories = true

        savePanel.begin { [self] response in
            guard response == .OK, let url = savePanel.url else { return }

            let success = SceneManager.shared.exportScene(
                sceneType: sceneType,
                toPath: url.path
            )

            if success {
                showExportSuccess = true
            } else {
                showExportError = true
            }
        }
    }

    private func importScene() {
        let openPanel = NSOpenPanel()
        openPanel.title = "导入场景配置"
        openPanel.message = "选择要导入的场景文件"
        openPanel.allowedContentTypes = [.init(filenameExtension: "vfscene")!]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false

        openPanel.begin { [self] response in
            guard response == .OK, let url = openPanel.url else { return }

            let result = SceneManager.shared.importScene(fromPath: url.path)

            switch result {
            case .success(let profile):
                loadProfile(profile)
                NSLog("[SceneSettingsView] Successfully imported scene: \(profile.sceneType.rawValue)")

            case .failure(let error):
                importErrorMessage = error.localizedDescription
                showImportError = true
            }
        }
    }
}

/// 添加/编辑术语条目的 Sheet（使用 ReplacementStorage）
private struct AddSceneGlossarySheet: View {
    @ObservedObject var replacementStorage: ReplacementStorage
    let sceneType: SceneType
    let editingRule: ReplacementRule?
    @Binding var isPresented: Bool

    @State private var term: String = ""
    @State private var replacement: String = ""
    @State private var caseSensitive: Bool = false
    @State private var isEnabled: Bool = true

    private var isEditing: Bool { editingRule != nil }

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

                Toggle("启用此规则", isOn: $isEnabled)
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
        .frame(width: 350, height: 320)
        .onAppear {
            if let rule = editingRule {
                term = rule.trigger
                replacement = rule.replacement
                caseSensitive = rule.caseSensitive
                isEnabled = rule.isEnabled
            }
        }
    }

    private func saveEntry() {
        if let existing = editingRule {
            // Update existing rule
            var updatedRule = existing
            updatedRule.trigger = term
            updatedRule.replacement = replacement
            updatedRule.caseSensitive = caseSensitive
            updatedRule.isEnabled = isEnabled
            replacementStorage.update(updatedRule)
        } else {
            // Add new rule for this scene
            let rule = ReplacementRule(
                trigger: term,
                replacement: replacement,
                isEnabled: isEnabled,
                caseSensitive: caseSensitive,
                applicableScenes: [sceneType],
                source: .user
            )
            replacementStorage.add(rule)
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

            VStack(alignment: .leading, spacing: 8) {
                Text("或手动输入：")
                    .fontWeight(.medium)

                TextField("应用名称", text: $appName)
                TextField("Bundle ID", text: $bundleID)
                    .font(.system(.body, design: .monospaced))
            }

            HStack {
                Text("目标场景：")
                    .fontWeight(.medium)

                Image(systemName: selectedSceneType.icon)
                    .foregroundColor(.accentColor)

                Text(selectedSceneType.displayName)
            }

            Spacer()

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
