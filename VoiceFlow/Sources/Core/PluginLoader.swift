import Foundation
import os

private let logger = Logger(subsystem: "com.voiceflow.app", category: "PluginLoader")

final class PluginLoader {
    typealias LoadSuccessCallback = (VoiceFlowPlugin) -> Void
    typealias LoadFailureCallback = (PluginError) -> Void

    private let fileManager = FileManager.default

    // MARK: - Public API

    /// Load a Swift plugin from the specified directory
    /// - Parameters:
    ///   - pluginURL: URL to the plugin directory containing the bundle
    ///   - manifest: The plugin manifest with metadata
    ///   - onSuccess: Callback invoked when plugin loads successfully
    ///   - onFailure: Callback invoked when plugin fails to load
    func loadPlugin(
        at pluginURL: URL,
        manifest: PluginManifest,
        onSuccess: LoadSuccessCallback?,
        onFailure: LoadFailureCallback?
    ) {
        NSLog("[PluginLoader] Attempting to load plugin: \(manifest.name)")

        // Construct the bundle path from the entrypoint
        let bundlePath = pluginURL.appendingPathComponent(manifest.entrypoint)

        // Verify the bundle exists
        guard fileManager.fileExists(atPath: bundlePath.path) else {
            let error = PluginError.loadFailed("Bundle not found at path: \(bundlePath.path)")
            NSLog("[PluginLoader] Failed to load plugin '\(manifest.name)': \(error)")
            onFailure?(error)
            return
        }

        // Load the bundle
        guard let bundle = Bundle(url: bundlePath) else {
            let error = PluginError.loadFailed("Failed to create bundle from path: \(bundlePath.path)")
            NSLog("[PluginLoader] Failed to load plugin '\(manifest.name)': \(error)")
            onFailure?(error)
            return
        }

        // Load the bundle into memory
        guard bundle.load() else {
            let error = PluginError.loadFailed("Bundle.load() failed for: \(bundlePath.path)")
            NSLog("[PluginLoader] Failed to load plugin '\(manifest.name)': \(error)")
            onFailure?(error)
            return
        }

        // Get the principal class
        guard let principalClass = bundle.principalClass as? NSObject.Type else {
            let error = PluginError.loadFailed("No principal class found in bundle")
            NSLog("[PluginLoader] Failed to load plugin '\(manifest.name)': \(error)")
            onFailure?(error)
            return
        }

        // Instantiate the principal class
        let pluginInstance = principalClass.init()

        // Verify it conforms to VoiceFlowPlugin protocol
        guard let plugin = pluginInstance as? VoiceFlowPlugin else {
            let error = PluginError.loadFailed("Principal class does not conform to VoiceFlowPlugin protocol")
            NSLog("[PluginLoader] Failed to load plugin '\(manifest.name)': \(error)")
            onFailure?(error)
            return
        }

        NSLog("[PluginLoader] Successfully loaded plugin: \(manifest.name) v\(manifest.version)")
        onSuccess?(plugin)
    }

    /// Load a Swift plugin synchronously (for testing or simple cases)
    /// - Parameters:
    ///   - pluginURL: URL to the plugin directory containing the bundle
    ///   - manifest: The plugin manifest with metadata
    /// - Returns: The loaded plugin instance
    /// - Throws: PluginError if loading fails
    func loadPluginSync(at pluginURL: URL, manifest: PluginManifest) throws -> VoiceFlowPlugin {
        NSLog("[PluginLoader] Synchronously loading plugin: \(manifest.name)")

        let bundlePath = pluginURL.appendingPathComponent(manifest.entrypoint)

        guard fileManager.fileExists(atPath: bundlePath.path) else {
            throw PluginError.loadFailed("Bundle not found at path: \(bundlePath.path)")
        }

        guard let bundle = Bundle(url: bundlePath) else {
            throw PluginError.loadFailed("Failed to create bundle from path: \(bundlePath.path)")
        }

        guard bundle.load() else {
            throw PluginError.loadFailed("Bundle.load() failed for: \(bundlePath.path)")
        }

        guard let principalClass = bundle.principalClass as? NSObject.Type else {
            throw PluginError.loadFailed("No principal class found in bundle")
        }

        let pluginInstance = principalClass.init()

        guard let plugin = pluginInstance as? VoiceFlowPlugin else {
            throw PluginError.loadFailed("Principal class does not conform to VoiceFlowPlugin protocol")
        }

        NSLog("[PluginLoader] Successfully loaded plugin: \(manifest.name) v\(manifest.version)")
        return plugin
    }

    /// Unload a plugin bundle (note: Swift bundles cannot be truly unloaded from memory)
    /// - Parameter plugin: The plugin instance to unload
    func unloadPlugin(_ plugin: VoiceFlowPlugin) {
        NSLog("[PluginLoader] Unloading plugin: \(plugin.pluginID)")
        plugin.onUnload()
        // Note: Swift bundles cannot be unloaded from memory once loaded
        // The plugin's onUnload() method should clean up any resources
    }

    // MARK: - Validation

    /// Validate that a plugin bundle is properly structured
    /// - Parameters:
    ///   - pluginURL: URL to the plugin directory
    ///   - manifest: The plugin manifest
    /// - Returns: True if the bundle is valid, false otherwise
    func validatePluginBundle(at pluginURL: URL, manifest: PluginManifest) -> Bool {
        let bundlePath = pluginURL.appendingPathComponent(manifest.entrypoint)

        guard fileManager.fileExists(atPath: bundlePath.path) else {
            NSLog("[PluginLoader] Validation failed: Bundle not found at \(bundlePath.path)")
            return false
        }

        guard let bundle = Bundle(url: bundlePath) else {
            NSLog("[PluginLoader] Validation failed: Cannot create bundle from \(bundlePath.path)")
            return false
        }

        guard bundle.principalClass != nil else {
            NSLog("[PluginLoader] Validation failed: No principal class in bundle")
            return false
        }

        NSLog("[PluginLoader] Validation successful for plugin: \(manifest.name)")
        return true
    }
}
