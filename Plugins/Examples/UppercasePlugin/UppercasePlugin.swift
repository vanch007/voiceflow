import Foundation

/// UppercasePlugin - Transforms transcribed text to uppercase
///
/// This is a simple example plugin that demonstrates the VoiceFlow plugin API.
/// It transforms all incoming text to uppercase letters.
///
/// Permissions required:
/// - text.read: Read transcribed text
/// - text.modify: Modify text before final output
class UppercasePlugin: VoiceFlowPlugin {
    var pluginID: String { "dev.voiceflow.examples.uppercase" }
    var manifest: PluginManifest

    init(manifest: PluginManifest) {
        self.manifest = manifest
    }

    /// Called when the plugin is loaded
    func onLoad() {
        print("[UppercasePlugin] Plugin loaded successfully")
    }

    /// Called for each transcription result
    /// - Parameter text: The original transcribed text
    /// - Returns: The uppercase-transformed text
    func onTranscription(_ text: String) -> String {
        let transformed = text.uppercased()
        print("[UppercasePlugin] Transformed: '\(text)' -> '\(transformed)'")
        return transformed
    }

    /// Called when the plugin is unloaded
    func onUnload() {
        print("[UppercasePlugin] Plugin unloaded")
    }
}
