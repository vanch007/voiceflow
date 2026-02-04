import Foundation
import os
import Darwin

private let logger = Logger(subsystem: "com.voiceflow.app", category: "PluginManager")

final class PluginManager {
    static let shared = PluginManager()

    private var plugins: [String: PluginInfo] = [:]
    private let pluginsDirectory: URL
    private let fileManager = FileManager.default
    private let pluginLoader = PluginLoader()
    private let queue = DispatchQueue(label: "com.voiceflow.pluginmanager")

    private var dirFD: CInt = -1
    private var dirSource: DispatchSourceFileSystemObject?
    private var debounceWorkItem: DispatchWorkItem?

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
        startWatchingPluginsDirectory()
    }

    deinit {
        stopWatchingPluginsDirectory()
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

        NSLog("[PluginManager] Discovery complete. Found \(self.getAllPlugins().count) plugin(s)")
    }

    /// Enable a plugin by ID
    func enablePlugin(_ pluginID: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard let info = self.plugins[pluginID] else {
                NSLog("[PluginManager] Cannot enable plugin '\(pluginID)': not found")
                return
            }

            guard case .disabled = info.state else {
                NSLog("[PluginManager] Plugin '\(pluginID)' is not in disabled state")
                return
            }

            if info.plugin == nil {
                let pluginURL = self.pluginsDirectory.appendingPathComponent(info.manifest.id)
                self.pluginLoader.loadPlugin(
                    at: pluginURL,
                    manifest: info.manifest,
                    onSuccess: { [weak self] plugin in
                        self?.queue.async {
                            guard let self = self else { return }
                            info.plugin = plugin
                            plugin.onLoad()
                            info.state = .enabled
                            NSLog("[PluginManager] Enabled plugin: \(info.manifest.name)")
                            DispatchQueue.main.async { self.onPluginStateChanged?(info) }
                        }
                    },
                    onFailure: { [weak self] error in
                        self?.queue.async {
                            guard let self = self else { return }
                            info.state = .failed(error)
                            NSLog("[PluginManager] Failed to load plugin '\(pluginID)': \(error)")
                            DispatchQueue.main.async { self.onPluginStateChanged?(info) }
                        }
                    }
                )
            } else {
                info.plugin?.onLoad()
                info.state = .enabled
                NSLog("[PluginManager] Enabled plugin: \(info.manifest.name)")
                DispatchQueue.main.async { self.onPluginStateChanged?(info) }
            }
        }
    }

    /// Disable a plugin by ID
    func disablePlugin(_ pluginID: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard let info = self.plugins[pluginID] else {
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
            DispatchQueue.main.async { self.onPluginStateChanged?(info) }
        }
    }

    /// Process text through all enabled plugins
    func processText(_ text: String) -> String {
        var processedText = text

        // Snapshot enabled plugins to avoid holding the queue while running plugin code
        let enabledPlugins: [PluginInfo] = queue.sync {
            return self.plugins.values.filter { $0.isEnabled && $0.plugin != nil }
        }

        for info in enabledPlugins {
            guard let plugin = info.plugin else { continue }
            do {
                processedText = plugin.onTranscription(processedText)
                NSLog("[PluginManager] Plugin '\(info.manifest.name)' processed text")
            } catch {
                NSLog("[PluginManager] Plugin '\(info.manifest.name)' failed to process text: \(error)")
                queue.async { [weak self] in
                    guard let self = self else { return }
                    info.state = .failed(error)
                    DispatchQueue.main.async { self.onPluginStateChanged?(info) }
                }
            }
        }

        return processedText
    }

    /// Get all discovered plugins
    func getAllPlugins() -> [PluginInfo] {
        return queue.sync { Array(plugins.values) }
    }

    /// Get a specific plugin by ID
    func getPlugin(_ pluginID: String) -> PluginInfo? {
        return queue.sync { plugins[pluginID] }
    }

    /// Unload all plugins
    func unloadAll() {
        NSLog("[PluginManager] Unloading all plugins...")

        // Take a snapshot of current plugins
        let snapshot: [(String, PluginInfo)] = queue.sync { Array(self.plugins) }

        for (pluginID, info) in snapshot {
            if info.isEnabled {
                info.plugin?.onUnload()
            }
            DispatchQueue.main.async { self.onPluginUnloaded?(pluginID) }
        }

        queue.async { [weak self] in
            self?.plugins.removeAll()
        }

        NSLog("[PluginManager] All plugins unloaded")
    }

    // MARK: - Private Methods

    private func startWatchingPluginsDirectory() {
        stopWatchingPluginsDirectory()

        let fd = open(pluginsDirectory.path, O_EVTONLY)
        guard fd >= 0 else {
            NSLog("[PluginManager] Failed to open plugins directory for watching")
            return
        }
        dirFD = fd

        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: queue)
        dirSource = source

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            // Debounce rapid events
            self.debounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                NSLog("[PluginManager] Directory change detected, rediscovering plugins...")
                self.discoverPlugins()
            }
            self.debounceWorkItem = work
            self.queue.asyncAfter(deadline: .now() + 0.5, execute: work)
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.dirFD, fd >= 0 {
                close(fd)
            }
        }

        source.resume()
        NSLog("[PluginManager] Watching plugins directory: \(pluginsDirectory.path)")
    }

    private func stopWatchingPluginsDirectory() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        dirSource?.cancel()
        dirSource = nil
        if dirFD >= 0 {
            close(dirFD)
            dirFD = -1
        }
    }

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
            queue.async { [weak self] in
                guard let self = self else { return }
                self.plugins[manifest.id] = info
                NSLog("[PluginManager] Loaded manifest for plugin: \(manifest.name) v\(manifest.version)")
                DispatchQueue.main.async { self.onPluginLoaded?(info) }
            }

        } catch {
            NSLog("[PluginManager] Failed to load manifest from \(pluginURL.lastPathComponent): \(error)")
        }
    }
}

