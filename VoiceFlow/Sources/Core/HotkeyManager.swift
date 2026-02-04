import AppKit

final class HotkeyManager {
    var onLongPress: (() -> Void)?
    var onLongPressEnd: (() -> Void)?

    private var currentConfig: HotkeyConfig
    private var optionKeyIsDown = false
    private var optionKeyPressTime: TimeInterval = 0
    private var longPressTimer: Timer?
    private var monitor: Any?
    private let longPressThreshold: TimeInterval = 0.3  // 长按阈值 300ms
    private var isEnabled = true
    private let userDefaultsKey = "voiceflow.hotkeyConfig"

    init() {
        // Load config from UserDefaults or use default
        currentConfig = HotkeyManager.loadConfig()
    }

    func enable() {
        isEnabled = true
        NSLog("[HotkeyManager] Hotkey enabled")
    }

    func disable() {
        isEnabled = false
        NSLog("[HotkeyManager] Hotkey disabled")
    }

    func start() {
        NSLog("[HotkeyManager] 正在创建事件监听器 (Option 键长按)...")

        // 使用 NSEvent 全局监听 flagsChanged 事件
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleEvent(event: event)
        }

        if monitor != nil {
            NSLog("[HotkeyManager] 事件监听启动成功！长按 Option (⌥) 键触发录音。")
        } else {
            NSLog("[HotkeyManager] 创建事件监听失败！请检查辅助功能权限。")
        }
    }

    private func handleEvent(event: NSEvent) {
        let flags = event.modifierFlags
        let optionPressed = flags.contains(.option)
        let keyCode = event.keyCode

        // Left Option: 58, Right Option: 61
        guard keyCode == 58 || keyCode == 61 else { return }

        guard isEnabled else { return }

        NSLog("[HotkeyManager] Option 键状态变化: pressed=\(optionPressed), keyCode=\(keyCode)")

        if optionPressed && !optionKeyIsDown {
            // Option 键按下
            optionKeyIsDown = true
            optionKeyPressTime = ProcessInfo.processInfo.systemUptime

            // 启动定时器检测长按
            longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressThreshold, repeats: false) { [weak self] _ in
                guard let self = self, self.optionKeyIsDown else { return }
                if self.isEnabled {
                    NSLog("[HotkeyManager] Option 键长按触发")
                    DispatchQueue.main.async {
                        self.onLongPress?()
                    }
                }
            }
        } else if !optionPressed && optionKeyIsDown {
            // Option 键释放
            optionKeyIsDown = false
            longPressTimer?.invalidate()
            longPressTimer = nil

            let pressDuration = ProcessInfo.processInfo.systemUptime - optionKeyPressTime
            if pressDuration >= longPressThreshold && isEnabled {
                // 长按结束
                NSLog("[HotkeyManager] Option 键长按结束 (持续 \(String(format: "%.2f", pressDuration))s)")
                DispatchQueue.main.async { [weak self] in
                    self?.onLongPressEnd?()
                }
            }
        }
    }

    deinit {
        longPressTimer?.invalidate()
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Configuration Persistence

    private static func loadConfig() -> HotkeyConfig {
        guard let savedData = UserDefaults.standard.data(forKey: "voiceflow.hotkeyConfig"),
              let config = try? JSONDecoder().decode(HotkeyConfig.self, from: savedData) else {
            return HotkeyConfig.default
        }
        return config
    }

    func saveConfig(_ config: HotkeyConfig) {
        guard let encoded = try? JSONEncoder().encode(config) else {
            NSLog("[HotkeyManager] Failed to encode config")
            return
        }
        UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        currentConfig = config
        NSLog("[HotkeyManager] Config saved: \(config.displayString)")
    }

    func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        currentConfig = HotkeyConfig.default
        NSLog("[HotkeyManager] Config reset to default: \(currentConfig.displayString)")
    }

    func getCurrentConfig() -> HotkeyConfig {
        return currentConfig
    }
}
