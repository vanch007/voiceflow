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

            Text("바로 가기 키")
                .tabItem {
                    Label("바로 가기 키", systemImage: "keyboard")
                }
                .tag(1)

            Text("음성 인식")
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

    private init() {
        // Initialize with current values from SettingsManager
        self.language = SettingsManager.shared.language
        self.soundEffectsEnabled = SettingsManager.shared.soundEffectsEnabled

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
        }
    }
}
