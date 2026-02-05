import Foundation

// MARK: - Plugin Metadata

struct PluginManifest: Codable {
    let id: String
    let name: String
    let version: String
    let author: String
    let description: String
    let entrypoint: String
    let permissions: [String]
    let platform: PluginPlatform
    /// 插件目录名（可选，用于路径查找；如未指定则使用 name）
    var directory: String?
}

enum PluginPlatform: String, Codable {
    case swift
    case python
    case both
}

// MARK: - Plugin Protocol

protocol VoiceFlowPlugin: AnyObject {
    /// Unique identifier for the plugin
    var pluginID: String { get }

    /// Plugin metadata
    var manifest: PluginManifest { get }

    /// Called when the plugin is loaded
    func onLoad()

    /// Called when transcription text is available for processing
    /// - Parameter text: The transcribed text
    /// - Returns: The processed text (can be the same as input if no transformation needed)
    func onTranscription(_ text: String) -> String

    /// Called when the plugin is unloaded
    func onUnload()
}

// MARK: - Plugin Error

enum PluginError: Error {
    case loadFailed(String)
    case manifestInvalid(String)
    case permissionDenied(String)
    case executionFailed(String)
}

// MARK: - Plugin State

enum PluginState {
    case loaded
    case enabled
    case disabled
    case failed(Error)
}

// MARK: - Plugin Info

final class PluginInfo {
    let manifest: PluginManifest
    var state: PluginState
    var plugin: VoiceFlowPlugin?

    var isEnabled: Bool {
        if case .enabled = state {
            return true
        }
        return false
    }

    init(manifest: PluginManifest, state: PluginState = .loaded) {
        self.manifest = manifest
        self.state = state
    }
}
