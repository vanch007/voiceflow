import Foundation
import os

private let logger = Logger(subsystem: "com.voiceflow.app", category: "PluginManager")

final class PluginManager {
    static let shared = PluginManager()

    private var plugins: [String: PluginInfo] = [:]
    private let pluginsDirectory: URL
    private let fileManager = FileManager.default

    var onPluginLoaded: ((PluginInfo) -> Void)?
    var onPluginUnloaded: ((String) -> Void)?
    var onPluginStateChanged: ((PluginInfo) -> Void)?

    private init() {
        // Set up plugins directory: ~/Library/Application Support/VoiceFlow/Plugins/
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        pluginsDirectory = appSupport.appendingPathComponent("VoiceFlow/Plugins")

        // Create plugins directory if it doesn't exist
        try? fileManager.createDirectory(at: pluginsDirectory, withIntermediateDirectories: true)

        NSLog("[PluginManager] Initialized with plugins directory: \(pluginsDirectory.path)")
    }

    // MARK: - Public API

    /// Discover and load all plugins from the plugins directory
    func discoverPlugins() {
        NSLog("[PluginManager] Starting plugin discovery...")

        guard let contents = try? fileManager.contentsOfDirectory(
            at: pluginsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            NSLog("[PluginManager] Failed to read plugins directory")
            return
        }

        for pluginURL in contents {
            guard (try? pluginURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                continue
            }

            loadPluginManifest(at: pluginURL)
        }

        NSLog("[PluginManager] Discovery complete. Found \(plugins.count) plugin(s)")
    }

    /// Enable a plugin by ID
    func enablePlugin(_ pluginID: String) {
        guard let info = plugins[pluginID] else {
            NSLog("[PluginManager] Cannot enable plugin '\(pluginID)': not found")
            return
        }

        guard case .disabled = info.state else {
            NSLog("[PluginManager] Plugin '\(pluginID)' is not in disabled state")
            return
        }

        info.state = .enabled
        info.plugin?.onLoad()

        NSLog("[PluginManager] Enabled plugin: \(info.manifest.name)")
        onPluginStateChanged?(info)
    }

    /// Disable a plugin by ID
    func disablePlugin(_ pluginID: String) {
        guard let info = plugins[pluginID] else {
            NSLog("[PluginManager] Cannot disable plugin '\(pluginID)': not found")
            return
        }

        guard case .enabled = info.state else {
            NSLog("[PluginManager] Plugin '\(pluginID)' is not in enabled state")
            return
        }

        info.plugin?.onUnload()
        info.state = .disabled

        NSLog("[PluginManager] Disabled plugin: \(info.manifest.name)")
        onPluginStateChanged?(info)
    }

    /// Process text through all enabled plugins
    func processText(_ text: String) -> String {
        var processedText = text

        for (_, info) in plugins where info.isEnabled {
            guard let plugin = info.plugin else { continue }

            do {
                processedText = plugin.onTranscription(processedText)
                NSLog("[PluginManager] Plugin '\(info.manifest.name)' processed text")
            } catch {
                NSLog("[PluginManager] Plugin '\(info.manifest.name)' failed to process text: \(error)")
                info.state = .failed(error)
                onPluginStateChanged?(info)
            }
        }

        return processedText
    }

    /// Get all discovered plugins
    func getAllPlugins() -> [PluginInfo] {
        return Array(plugins.values)
    }

    /// Get a specific plugin by ID
    func getPlugin(_ pluginID: String) -> PluginInfo? {
        return plugins[pluginID]
    }

    /// Unload all plugins
    func unloadAll() {
        NSLog("[PluginManager] Unloading all plugins...")

        for (pluginID, info) in plugins {
            if info.isEnabled {
                info.plugin?.onUnload()
            }
            onPluginUnloaded?(pluginID)
        }

        plugins.removeAll()
        NSLog("[PluginManager] All plugins unloaded")
    }

    // MARK: - Private Methods

    private func loadPluginManifest(at pluginURL: URL) {
        let manifestURL = pluginURL.appendingPathComponent("manifest.json")

        guard fileManager.fileExists(atPath: manifestURL.path) else {
            NSLog("[PluginManager] No manifest.json found in \(pluginURL.lastPathComponent)")
            return
        }

        do {
            let data = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)

            // Validate platform compatibility
            guard manifest.platform == .swift || manifest.platform == .both else {
                NSLog("[PluginManager] Skipping non-Swift plugin: \(manifest.name)")
                return
            }

            let info = PluginInfo(manifest: manifest, state: .disabled)
            plugins[manifest.id] = info

            NSLog("[PluginManager] Loaded manifest for plugin: \(manifest.name) v\(manifest.version)")
            onPluginLoaded?(info)

        } catch {
            NSLog("[PluginManager] Failed to load manifest from \(pluginURL.lastPathComponent): \(error)")
        }
    }
}
