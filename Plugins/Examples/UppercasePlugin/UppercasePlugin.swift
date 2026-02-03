import Foundation

/// Example VoiceFlow plugin that transforms transcribed text to uppercase.
///
/// This plugin demonstrates the basic plugin architecture:
/// - Implementing the VoiceFlowPlugin protocol
/// - Handling the plugin lifecycle (onLoad, onTranscription, onUnload)
/// - Processing transcribed text in real-time
///
/// Usage:
/// 1. Copy this plugin directory to ~/Library/Application Support/VoiceFlow/Plugins/
/// 2. Restart VoiceFlow
/// 3. Enable the plugin from the Plugins menu
/// 4. All transcribed text will be converted to uppercase
final class UppercasePlugin: VoiceFlowPlugin {

    // MARK: - VoiceFlowPlugin Protocol

    var pluginID: String {
        return manifest.id
    }

    var manifest: PluginManifest {
        // Load manifest from the plugin's directory
        // In production, this would be loaded by the plugin manager
        // For this example, we define it inline
        return PluginManifest(
            id: "dev.voiceflow.examples.uppercase",
            name: "Uppercase Transform",
            version: "1.0.0",
            author: "VoiceFlow Team",
            description: "Example plugin that transforms all transcribed text to uppercase for emphasis and demonstration purposes",
            entrypoint: "UppercasePlugin.swift",
            permissions: ["text.read", "text.modify"],
            platform: .swift
        )
    }

    // MARK: - Lifecycle Hooks

    func onLoad() {
        // Called when the plugin is loaded
        // Use this for initialization, setup, loading configuration, etc.
        NSLog("[UppercasePlugin] Plugin loaded successfully")
    }

    func onTranscription(_ text: String) -> String {
        // Called whenever new transcribed text is available
        // Transform the text to uppercase
        let transformedText = text.uppercased()

        NSLog("[UppercasePlugin] Transformed: '\(text)' -> '\(transformedText)'")

        return transformedText
    }

    func onUnload() {
        // Called when the plugin is unloaded or disabled
        // Use this for cleanup, saving state, releasing resources, etc.
        NSLog("[UppercasePlugin] Plugin unloaded")
    }
}
