import Foundation

/// Template plugin for VoiceFlow
/// Replace this comment with a description of what your plugin does
class PluginTemplate: VoiceFlowPlugin {
    var pluginID: String { "com.example.template" }
    var manifest: PluginManifest

    // Configuration properties
    private var exampleSetting: String?
    private var enabled: Bool = true

    init(manifest: PluginManifest) {
        self.manifest = manifest
    }

    func onLoad() {
        // Extract configuration from manifest
        if let config = manifest.configuration {
            exampleSetting = config["exampleSetting"] as? String
            if let enabledValue = config["enabled"] as? Bool {
                enabled = enabledValue
            }
        }

        NSLog("[PluginTemplate] Loaded with exampleSetting: \(exampleSetting ?? "none"), enabled: \(enabled)")
    }

    func onTranscription(_ text: String) -> String {
        // Return early if plugin is disabled
        guard enabled else {
            return text
        }

        // TODO: Implement your plugin logic here
        // This template simply returns the text unchanged
        // Example modifications you could make:
        // - Transform the text (uppercase, lowercase, etc.)
        // - Add prefixes or suffixes
        // - Filter or replace certain words
        // - Send data to external services
        // - Store data locally

        NSLog("[PluginTemplate] Processing transcription: \(text.prefix(50))\(text.count > 50 ? "..." : "")")

        // Return the original text (replace this with your logic)
        return text
    }

    func onUnload() {
        // Clean up any resources here
        // Examples:
        // - Close network connections
        // - Save state to disk
        // - Cancel pending operations
        // - Release allocated resources

        NSLog("[PluginTemplate] Unloaded and cleaned up")
    }
}
