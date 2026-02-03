import AppKit
import SwiftUI

final class SettingsWindow {
    private var window: NSWindow?

    init() {}

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
        let windowWidth: CGFloat = 600
        let windowHeight: CGFloat = 400

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - windowWidth / 2
        let y = screenFrame.midY - windowHeight / 2

        let frame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)

        let w = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.title = "설정"
        w.isReleasedWhenClosed = false
        w.level = .normal
        w.contentView = NSHostingView(rootView: SettingsContentView())

        window = w
    }
}

private struct SettingsContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab()
                .tabItem {
                    Label("통용", systemImage: "gearshape")
                }
                .tag(0)

            ShortcutsSettingsTab()
                .tabItem {
                    Label("바로 가기 키", systemImage: "keyboard")
                }
                .tag(1)

            VoiceRecognitionSettingsTab()
                .tabItem {
                    Label("음성 인식", systemImage: "mic")
                }
                .tag(2)
        }
        .padding(20)
        .frame(width: 600, height: 400)
    }
}

private struct GeneralSettingsTab: View {
    @ObservedObject private var settings = SettingsObserver.shared

    var body: some View {
        Form {
            Section(header: Text("언어").font(.headline)) {
                Picker("언어", selection: $settings.language) {
                    Text("한국어").tag("ko")
                    Text("English").tag("en")
                    Text("中文").tag("zh")
                }
                .pickerStyle(.radioGroup)
            }

            Section(header: Text("음향 효과").font(.headline)) {
                Toggle("음향 효과 사용", isOn: $settings.soundEffectsEnabled)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ShortcutsSettingsTab: View {
    @ObservedObject private var settings = SettingsObserver.shared
    @State private var isCapturingShortcut = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section(header: Text("활성화 단축키").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("활성화 단축키:")
                        .font(.subheadline)

                    ShortcutCaptureField(
                        shortcut: $settings.activationShortcut,
                        isCapturing: $isCapturingShortcut,
                        errorMessage: $errorMessage
                    )

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Text("단축키 필드를 클릭하고 원하는 키 조합을 누르세요")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section(header: Text("정보").font(.headline)) {
                Text("• 시스템 예약 단축키(Cmd+Q, Cmd+W 등)는 사용할 수 없습니다")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• 단축키를 재설정하려면 필드를 클릭하세요")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct VoiceRecognitionSettingsTab: View {
    @ObservedObject private var settings = SettingsObserver.shared

    var body: some View {
        Form {
            Section(header: Text("음성 인식").font(.headline)) {
                Toggle("음성 인식 사용", isOn: $settings.voiceRecognitionEnabled)
            }

            Section(header: Text("언어").font(.headline)) {
                Picker("음성 인식 언어", selection: $settings.voiceRecognitionLanguage) {
                    Text("한국어").tag("ko")
                    Text("English").tag("en")
                    Text("中文").tag("zh")
                }
                .pickerStyle(.radioGroup)
                .disabled(!settings.voiceRecognitionEnabled)
            }

            Section(header: Text("민감도").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("민감도:")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.0f%%", settings.voiceRecognitionSensitivity * 100))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $settings.voiceRecognitionSensitivity, in: 0.0...1.0, step: 0.1)
                        .disabled(!settings.voiceRecognitionEnabled)

                    Text("높은 민감도는 더 작은 소리도 감지하지만 잘못된 인식이 증가할 수 있습니다")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ShortcutCaptureField: NSViewRepresentable {
    @Binding var shortcut: String
    @Binding var isCapturing: Bool
    @Binding var errorMessage: String?

    func makeNSView(context: Context) -> NSTextField {
        let textField = CaptureTextField()
        textField.isEditable = false
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.placeholderString = "단축키를 입력하세요"
        textField.font = .systemFont(ofSize: 13)
        textField.delegate = context.coordinator
        textField.stringValue = formatShortcut(shortcut)
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if !isCapturing {
            nsView.stringValue = formatShortcut(shortcut)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func formatShortcut(_ shortcut: String) -> String {
        // Convert "ctrl-double-tap" to "Ctrl Double-Tap"
        let components = shortcut.split(separator: "-")
        return components.map { $0.capitalized }.joined(separator: " ")
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ShortcutCaptureField

        init(_ parent: ShortcutCaptureField) {
            self.parent = parent
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.isCapturing = true
            parent.errorMessage = nil
            textField.stringValue = "키 조합을 누르세요..."
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            parent.isCapturing = false
        }
    }
}

// Custom NSTextField that captures keyboard events
private class CaptureTextField: NSTextField {
    private var capturedModifiers: NSEvent.ModifierFlags = []
    private var capturedKey: String?

    override func keyDown(with event: NSEvent) {
        capturedModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        capturedKey = event.charactersIgnoringModifiers

        var components: [String] = []

        if capturedModifiers.contains(.control) {
            components.append("ctrl")
        }
        if capturedModifiers.contains(.option) {
            components.append("opt")
        }
        if capturedModifiers.contains(.shift) {
            components.append("shift")
        }
        if capturedModifiers.contains(.command) {
            components.append("cmd")
        }

        if let key = capturedKey, !key.isEmpty {
            components.append(key.lowercased())
        }

        if !components.isEmpty {
            let shortcutString = components.joined(separator: "-")
            stringValue = components.map { $0.capitalized }.joined(separator: " ")

            // Update the binding through the coordinator
            if let coordinator = delegate as? ShortcutCaptureField.Coordinator {
                // Validate shortcut
                let reservedShortcuts = ["cmd-q", "cmd-w", "cmd-h", "cmd-m"]
                if reservedShortcuts.contains(shortcutString.lowercased()) {
                    coordinator.parent.errorMessage = "이 단축키는 시스템에서 예약되어 있습니다"
                } else {
                    coordinator.parent.shortcut = shortcutString
                    coordinator.parent.errorMessage = nil
                }
            }

            // End editing after capturing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.window?.makeFirstResponder(nil)
            }
        }
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func becomeFirstResponder() -> Bool {
        return true
    }
}

// ObservableObject wrapper for SettingsManager to enable SwiftUI bindings
private class SettingsObserver: ObservableObject {
    static let shared = SettingsObserver()

    @Published var language: String {
        didSet {
            SettingsManager.shared.language = language
        }
    }

    @Published var soundEffectsEnabled: Bool {
        didSet {
            SettingsManager.shared.soundEffectsEnabled = soundEffectsEnabled
        }
    }

    @Published var activationShortcut: String {
        didSet {
            SettingsManager.shared.activationShortcut = activationShortcut
        }
    }

    @Published var voiceRecognitionEnabled: Bool {
        didSet {
            SettingsManager.shared.voiceEnabled = voiceRecognitionEnabled
        }
    }

    @Published var voiceRecognitionLanguage: String {
        didSet {
            SettingsManager.shared.voiceLanguage = voiceRecognitionLanguage
        }
    }

    @Published var voiceRecognitionSensitivity: Double {
        didSet {
            SettingsManager.shared.voiceSensitivity = voiceRecognitionSensitivity
        }
    }

    private init() {
        // Initialize with current values from SettingsManager
        self.language = SettingsManager.shared.language
        self.soundEffectsEnabled = SettingsManager.shared.soundEffectsEnabled
        self.activationShortcut = SettingsManager.shared.activationShortcut
        self.voiceRecognitionEnabled = SettingsManager.shared.voiceEnabled
        self.voiceRecognitionLanguage = SettingsManager.shared.voiceLanguage
        self.voiceRecognitionSensitivity = SettingsManager.shared.voiceSensitivity

        // Listen for external changes to SettingsManager
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: SettingsManager.settingsDidChangeNotification,
            object: nil
        )
    }

    @objc private func settingsDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let category = userInfo["category"] as? String,
              let key = userInfo["key"] as? String else {
            return
        }

        // Update published properties if changed externally
        if category == "general" {
            if key == "language" {
                let newValue = SettingsManager.shared.language
                if newValue != language {
                    language = newValue
                }
            } else if key == "soundEffectsEnabled" {
                let newValue = SettingsManager.shared.soundEffectsEnabled
                if newValue != soundEffectsEnabled {
                    soundEffectsEnabled = newValue
                }
            }
        } else if category == "shortcuts" {
            if key == "activation" {
                let newValue = SettingsManager.shared.activationShortcut
                if newValue != activationShortcut {
                    activationShortcut = newValue
                }
            }
        } else if category == "voice" {
            if key == "enabled" {
                let newValue = SettingsManager.shared.voiceEnabled
                if newValue != voiceRecognitionEnabled {
                    voiceRecognitionEnabled = newValue
                }
            } else if key == "language" {
                let newValue = SettingsManager.shared.voiceLanguage
                if newValue != voiceRecognitionLanguage {
                    voiceRecognitionLanguage = newValue
                }
            } else if key == "sensitivity" {
                let newValue = SettingsManager.shared.voiceSensitivity
                if newValue != voiceRecognitionSensitivity {
                    voiceRecognitionSensitivity = newValue
                }
            }
        }
    }
}
