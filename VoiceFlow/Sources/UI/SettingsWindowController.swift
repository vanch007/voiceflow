import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    private let settingsManager: SettingsManager
    private let replacementStorage: ReplacementStorage

    init(settingsManager: SettingsManager, replacementStorage: ReplacementStorage) {
        self.settingsManager = settingsManager
        self.replacementStorage = replacementStorage

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 600),
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
                replacementStorage: replacementStorage
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

    var body: some View {
        TabView {
            // 通用设置标签页
            GeneralSettingsTab(settingsManager: settingsManager)
                .tabItem { Label("通用", systemImage: "gear") }

            // 文本替换标签页
            TextReplacementTab(replacementStorage: replacementStorage)
                .tabItem { Label("文本替换", systemImage: "textformat.alt") }
        }
        .frame(width: 600, height: 600)
        .padding()
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
