import AppKit

extension Notification.Name {
    static let hotkeyConfigDidChange = Notification.Name("hotkeyConfigDidChange")
}

final class HotkeyManager {
    var onLongPress: (() -> Void)?
    var onLongPressEnd: (() -> Void)?

    private var currentConfig: HotkeyConfig
    private var keyIsDown = false
    private var keyPressTime: TimeInterval = 0
    private var longPressTimer: Timer?
    private var monitor: Any?
    private var keyDownMonitor: Any?
    private var isEnabled = true
    private let userDefaultsKey = "voiceflow.hotkeyConfig"

    // Double-tap detection
    private var lastTapTime: TimeInterval = 0
    private var tapCount = 0

    init() {
        // Load config from UserDefaults or use default
        currentConfig = HotkeyManager.loadConfig()

        // Listen for config changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigChange(_:)),
            name: .hotkeyConfigDidChange,
            object: nil
        )
    }

    @objc private func handleConfigChange(_ notification: Notification) {
        if let config = notification.userInfo?["config"] as? HotkeyConfig {
            updateConfig(config)
        } else {
            // Reload from UserDefaults
            currentConfig = HotkeyManager.loadConfig()
            NSLog("[HotkeyManager] Config reloaded: \(currentConfig.displayString)")
        }
    }

    func updateConfig(_ config: HotkeyConfig) {
        currentConfig = config
        NSLog("[HotkeyManager] Config updated to: \(config.displayString)")
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
        NSLog("[HotkeyManager] 正在创建事件监听器 (\(currentConfig.displayString))...")

        // Monitor for modifier key changes (for modifier-based triggers)
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event: event)
        }

        // Monitor for key down events (for combination triggers with non-modifier keys)
        keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event: event)
        }

        if monitor != nil {
            NSLog("[HotkeyManager] 事件监听启动成功！触发方式: \(currentConfig.displayString)")
        } else {
            NSLog("[HotkeyManager] 创建事件监听失败！请检查辅助功能权限。")
        }
    }

    private func handleFlagsChanged(event: NSEvent) {
        guard isEnabled else { return }

        switch currentConfig.triggerType {
        case .doubleTap:
            handleDoubleTapTrigger(event: event)
        case .longPress:
            handleLongPressTrigger(event: event)
        case .combination:
            handleCombinationTrigger(event: event)
        }
    }

    private func handleKeyDown(event: NSEvent) {
        guard isEnabled else { return }
        guard currentConfig.triggerType == .combination else { return }

        // Check if this is a combination with a non-modifier key (like Space)
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Check if the key matches and modifiers are held
        if keyCode == currentConfig.keyCode && modifiers.contains(currentConfig.modifiers) {
            // Trigger long press immediately for combination keys
            if !keyIsDown {
                keyIsDown = true
                keyPressTime = ProcessInfo.processInfo.systemUptime
                NSLog("[HotkeyManager] 组合键触发: \(currentConfig.displayString)")
                DispatchQueue.main.async { [weak self] in
                    self?.onLongPress?()
                }
            }
        }
    }

    private func handleLongPressTrigger(event: NSEvent) {
        let keyCode = event.keyCode
        let targetKeyCode = currentConfig.keyCode

        // Check for the specific modifier key
        let isTargetKey = isMatchingModifierKey(keyCode: keyCode, targetKeyCode: targetKeyCode)
        guard isTargetKey else { return }

        let isKeyPressed = isModifierKeyPressed(event: event, keyCode: targetKeyCode)

        if isKeyPressed && !keyIsDown {
            // Key pressed - start long press timer
            keyIsDown = true
            keyPressTime = ProcessInfo.processInfo.systemUptime

            longPressTimer = Timer.scheduledTimer(withTimeInterval: currentConfig.interval, repeats: false) { [weak self] _ in
                guard let self = self, self.keyIsDown else { return }
                if self.isEnabled {
                    NSLog("[HotkeyManager] 长按触发: \(self.currentConfig.displayString)")
                    DispatchQueue.main.async {
                        self.onLongPress?()
                    }
                }
            }
        } else if !isKeyPressed && keyIsDown {
            // Key released
            keyIsDown = false
            let pressDuration = ProcessInfo.processInfo.systemUptime - keyPressTime

            longPressTimer?.invalidate()
            longPressTimer = nil

            if pressDuration >= currentConfig.interval && isEnabled {
                NSLog("[HotkeyManager] 长按结束 (持续 \(String(format: "%.2f", pressDuration))s)")
                DispatchQueue.main.async { [weak self] in
                    self?.onLongPressEnd?()
                }
            }
        }
    }

    private func handleDoubleTapTrigger(event: NSEvent) {
        let keyCode = event.keyCode
        let targetKeyCode = currentConfig.keyCode

        // Check for the specific modifier key
        // Left/Right variants: Ctrl (59/62), Option (58/61), Shift (56/60), Cmd (55/54)
        let isTargetKey = isMatchingModifierKey(keyCode: keyCode, targetKeyCode: targetKeyCode)
        guard isTargetKey else { return }

        let isKeyPressed = isModifierKeyPressed(event: event, keyCode: targetKeyCode)

        if isKeyPressed && !keyIsDown {
            // Key pressed
            keyIsDown = true
            let now = ProcessInfo.processInfo.systemUptime

            // Check for double tap
            if now - lastTapTime < currentConfig.interval {
                tapCount += 1
            } else {
                tapCount = 1
            }
            lastTapTime = now
            keyPressTime = now

            if tapCount >= 2 {
                // Double tap detected - start long press timer
                NSLog("[HotkeyManager] 双击检测到: \(currentConfig.displayString)")
                longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
                    guard let self = self, self.keyIsDown else { return }
                    if self.isEnabled {
                        NSLog("[HotkeyManager] 双击长按触发")
                        DispatchQueue.main.async {
                            self.onLongPress?()
                        }
                    }
                }
            }
        } else if !isKeyPressed && keyIsDown {
            // Key released
            keyIsDown = false
            longPressTimer?.invalidate()
            longPressTimer = nil

            if tapCount >= 2 {
                let pressDuration = ProcessInfo.processInfo.systemUptime - keyPressTime
                if pressDuration >= 0.1 && isEnabled {
                    NSLog("[HotkeyManager] 双击长按结束 (持续 \(String(format: "%.2f", pressDuration))s)")
                    DispatchQueue.main.async { [weak self] in
                        self?.onLongPressEnd?()
                    }
                }
                tapCount = 0
            }
        }
    }

    private func handleCombinationTrigger(event: NSEvent) {
        // For combination triggers, check if all required modifiers are pressed
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let requiredModifiers = currentConfig.modifiers

        // Check if it's a modifier-only combination (no regular key)
        let isModifierOnlyCombo = currentConfig.keyCode == 0 || isModifierKeyCode(currentConfig.keyCode)

        if isModifierOnlyCombo {
            // Modifier-only combination (e.g., just hold Cmd+Option)
            if modifiers.contains(requiredModifiers) && !keyIsDown {
                keyIsDown = true
                keyPressTime = ProcessInfo.processInfo.systemUptime

                longPressTimer = Timer.scheduledTimer(withTimeInterval: currentConfig.interval, repeats: false) { [weak self] _ in
                    guard let self = self, self.keyIsDown else { return }
                    if self.isEnabled {
                        NSLog("[HotkeyManager] 组合键长按触发: \(self.currentConfig.displayString)")
                        DispatchQueue.main.async {
                            self.onLongPress?()
                        }
                    }
                }
            } else if !modifiers.contains(requiredModifiers) && keyIsDown {
                keyIsDown = false
                longPressTimer?.invalidate()
                longPressTimer = nil

                let pressDuration = ProcessInfo.processInfo.systemUptime - keyPressTime
                if pressDuration >= currentConfig.interval && isEnabled {
                    NSLog("[HotkeyManager] 组合键长按结束")
                    DispatchQueue.main.async { [weak self] in
                        self?.onLongPressEnd?()
                    }
                }
            }
        } else {
            // Combination with regular key - release detection
            if keyIsDown && !modifiers.contains(requiredModifiers) {
                keyIsDown = false
                let pressDuration = ProcessInfo.processInfo.systemUptime - keyPressTime
                NSLog("[HotkeyManager] 组合键释放 (持续 \(String(format: "%.2f", pressDuration))s)")
                DispatchQueue.main.async { [weak self] in
                    self?.onLongPressEnd?()
                }
            }
        }
    }

    private func isMatchingModifierKey(keyCode: UInt16, targetKeyCode: UInt16) -> Bool {
        // Map target key code to both left and right variants
        switch targetKeyCode {
        case 59, 62: // Control
            return keyCode == 59 || keyCode == 62
        case 58, 61: // Option
            return keyCode == 58 || keyCode == 61
        case 56, 60: // Shift
            return keyCode == 56 || keyCode == 60
        case 55, 54: // Command
            return keyCode == 55 || keyCode == 54
        default:
            return keyCode == targetKeyCode
        }
    }

    private func isModifierKeyPressed(event: NSEvent, keyCode: UInt16) -> Bool {
        let flags = event.modifierFlags
        switch keyCode {
        case 59, 62: // Control
            return flags.contains(.control)
        case 58, 61: // Option
            return flags.contains(.option)
        case 56, 60: // Shift
            return flags.contains(.shift)
        case 55, 54: // Command
            return flags.contains(.command)
        default:
            return false
        }
    }

    private func isModifierKeyCode(_ keyCode: UInt16) -> Bool {
        // Check if keyCode is a modifier key
        return [54, 55, 56, 58, 59, 60, 61, 62].contains(keyCode)
    }

    deinit {
        longPressTimer?.invalidate()
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        if let keyDownMonitor = keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
        }
        NotificationCenter.default.removeObserver(self)
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
