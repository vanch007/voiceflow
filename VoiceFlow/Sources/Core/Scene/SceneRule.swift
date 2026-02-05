import Foundation

/// 应用到场景的映射规则
struct SceneRule: Codable, Equatable, Identifiable {
    var id: String { bundleID }
    var bundleID: String
    var appName: String
    var sceneType: SceneType
    var isBuiltin: Bool

    /// 内置规则
    static let builtinRules: [SceneRule] = [
        // 社交聊天应用
        SceneRule(bundleID: "com.tencent.xinWeChat", appName: "微信", sceneType: .social, isBuiltin: true),
        SceneRule(bundleID: "com.apple.MobileSMS", appName: "信息", sceneType: .social, isBuiltin: true),
        SceneRule(bundleID: "com.slack.Slack", appName: "Slack", sceneType: .social, isBuiltin: true),
        SceneRule(bundleID: "com.hnc.Discord", appName: "Discord", sceneType: .social, isBuiltin: true),
        SceneRule(bundleID: "ru.keepcoder.Telegram", appName: "Telegram", sceneType: .social, isBuiltin: true),
        SceneRule(bundleID: "com.facebook.archon", appName: "Messenger", sceneType: .social, isBuiltin: true),
        SceneRule(bundleID: "com.skype.skype", appName: "Skype", sceneType: .social, isBuiltin: true),
        SceneRule(bundleID: "com.microsoft.teams", appName: "Teams", sceneType: .social, isBuiltin: true),
        SceneRule(bundleID: "us.zoom.xos", appName: "Zoom", sceneType: .social, isBuiltin: true),
        SceneRule(bundleID: "com.lark.Lark", appName: "飞书", sceneType: .social, isBuiltin: true),
        SceneRule(bundleID: "com.alibaba.DingTalkMac", appName: "钉钉", sceneType: .social, isBuiltin: true),

        // IDE / 编程工具
        SceneRule(bundleID: "com.apple.dt.Xcode", appName: "Xcode", sceneType: .coding, isBuiltin: true),
        SceneRule(bundleID: "com.microsoft.VSCode", appName: "VS Code", sceneType: .coding, isBuiltin: true),
        SceneRule(bundleID: "com.todesktop.230313mzl4w4u92", appName: "Cursor", sceneType: .coding, isBuiltin: true),
        SceneRule(bundleID: "com.jetbrains.intellij", appName: "IntelliJ IDEA", sceneType: .coding, isBuiltin: true),
        SceneRule(bundleID: "com.jetbrains.pycharm", appName: "PyCharm", sceneType: .coding, isBuiltin: true),
        SceneRule(bundleID: "com.jetbrains.WebStorm", appName: "WebStorm", sceneType: .coding, isBuiltin: true),
        SceneRule(bundleID: "com.jetbrains.goland", appName: "GoLand", sceneType: .coding, isBuiltin: true),
        SceneRule(bundleID: "com.sublimetext.4", appName: "Sublime Text", sceneType: .coding, isBuiltin: true),
        SceneRule(bundleID: "com.github.atom", appName: "Atom", sceneType: .coding, isBuiltin: true),
        SceneRule(bundleID: "com.googlecode.iterm2", appName: "iTerm2", sceneType: .coding, isBuiltin: true),
        SceneRule(bundleID: "com.apple.Terminal", appName: "终端", sceneType: .coding, isBuiltin: true),
        SceneRule(bundleID: "dev.warp.Warp-Stable", appName: "Warp", sceneType: .coding, isBuiltin: true),
        SceneRule(bundleID: "com.google.antigravity", appName: "Antigravity", sceneType: .coding, isBuiltin: true),

        // 写作应用
        SceneRule(bundleID: "md.obsidian", appName: "Obsidian", sceneType: .writing, isBuiltin: true),
        SceneRule(bundleID: "notion.id", appName: "Notion", sceneType: .writing, isBuiltin: true),
        SceneRule(bundleID: "com.microsoft.Word", appName: "Word", sceneType: .writing, isBuiltin: true),
        SceneRule(bundleID: "com.apple.iWork.Pages", appName: "Pages", sceneType: .writing, isBuiltin: true),
        SceneRule(bundleID: "com.google.Chrome", appName: "Google Docs", sceneType: .writing, isBuiltin: true),
        SceneRule(bundleID: "abnerworks.Typora", appName: "Typora", sceneType: .writing, isBuiltin: true),
        SceneRule(bundleID: "com.ulyssesapp.mac", appName: "Ulysses", sceneType: .writing, isBuiltin: true),
        SceneRule(bundleID: "pro.writer.mac", appName: "iA Writer", sceneType: .writing, isBuiltin: true),
        SceneRule(bundleID: "com.evernote.Evernote", appName: "Evernote", sceneType: .writing, isBuiltin: true),
        SceneRule(bundleID: "com.bear-writer.bear", appName: "Bear", sceneType: .writing, isBuiltin: true),
        SceneRule(bundleID: "com.craft.craft", appName: "Craft", sceneType: .writing, isBuiltin: true),
    ]
}
