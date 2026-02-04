import AppKit

struct HotkeyConfig: Codable {
    enum TriggerType: String, Codable {
        case doubleTap
        case combination
        case longPress  // 长按单个修饰键
    }

    let triggerType: TriggerType
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags
    let interval: TimeInterval

    static let `default` = HotkeyConfig(
        triggerType: .longPress,
        keyCode: 58, // Left Option
        modifiers: [],
        interval: 0.3  // 长按阈值 0.3 秒
    )

    var displayString: String {
        switch triggerType {
        case .doubleTap:
            return "\(keyName(for: keyCode)) 双击"
        case .longPress:
            return "\(keyName(for: keyCode)) 长按"
        case .combination:
            var parts: [String] = []
            if modifiers.contains(.command) { parts.append("⌘") }
            if modifiers.contains(.option) { parts.append("⌥") }
            if modifiers.contains(.control) { parts.append("⌃") }
            if modifiers.contains(.shift) { parts.append("⇧") }
            parts.append(keyName(for: keyCode))
            return parts.joined(separator: " + ")
        }
    }

    private func keyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 49: return "Space"
        case 53: return "Esc"
        case 59: return "Left Ctrl"
        case 62: return "Right Ctrl"
        case 55: return "Cmd"
        case 58: return "Option"
        case 56: return "Shift"
        default: return "Key \(keyCode)"
        }
    }

    // Custom Codable implementation to handle NSEvent.ModifierFlags
    enum CodingKeys: String, CodingKey {
        case triggerType, keyCode, modifiers, interval
    }

    init(triggerType: TriggerType, keyCode: UInt16, modifiers: NSEvent.ModifierFlags, interval: TimeInterval) {
        self.triggerType = triggerType
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.interval = interval
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        triggerType = try container.decode(TriggerType.self, forKey: .triggerType)
        keyCode = try container.decode(UInt16.self, forKey: .keyCode)
        let rawModifiers = try container.decode(UInt.self, forKey: .modifiers)
        modifiers = NSEvent.ModifierFlags(rawValue: rawModifiers)
        interval = try container.decode(TimeInterval.self, forKey: .interval)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(triggerType, forKey: .triggerType)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifiers.rawValue, forKey: .modifiers)
        try container.encode(interval, forKey: .interval)
    }
}
