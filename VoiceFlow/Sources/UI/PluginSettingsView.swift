import AppKit
import SwiftUI

final class PluginSettingsView {
    private var panel: NSPanel?
    private var pluginID: String?

    init() {}

    func show(for pluginInfo: PluginInfo) {
        pluginID = pluginInfo.manifest.id

        if panel == nil {
            createPanel()
        }

        updateContent(with: pluginInfo)
        panel?.orderFront(nil)
        panel?.makeKey()
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
        pluginID = nil
    }

    private func createPanel() {
        let panelWidth: CGFloat = 400
        let panelHeight: CGFloat = 500

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - panelWidth / 2
        let y = screenFrame.midY - panelHeight / 2

        let frame = NSRect(x: x, y: y, width: panelWidth, height: panelHeight)

        let p = NSPanel(
            contentRect: frame,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.title = "插件设置"
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .windowBackgroundColor
        p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = true
        p.hidesOnDeactivate = false

        panel = p
    }

    private func updateContent(with pluginInfo: PluginInfo) {
        guard let panel else { return }

        let view = NSHostingView(rootView: PluginSettingsContentView(
            pluginInfo: pluginInfo,
            onToggle: { [weak self] in
                self?.handleToggle()
            },
            onClose: { [weak self] in
                self?.hide()
            }
        ))

        panel.contentView = view
    }

    private func handleToggle() {
        guard let pluginID = pluginID else { return }

        if let plugin = PluginManager.shared.getPlugin(pluginID) {
            if plugin.isEnabled {
                PluginManager.shared.disablePlugin(pluginID)
            } else {
                PluginManager.shared.enablePlugin(pluginID)
            }

            // Refresh the view with updated state
            if let updatedPlugin = PluginManager.shared.getPlugin(pluginID) {
                updateContent(with: updatedPlugin)
            }
        }
    }
}

private struct PluginSettingsContentView: View {
    let pluginInfo: PluginInfo
    let onToggle: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: platformIcon)
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(pluginInfo.manifest.name)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("v\(pluginInfo.manifest.version)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status
                    HStack {
                        Text("状态:")
                            .fontWeight(.medium)

                        Spacer()

                        HStack(spacing: 4) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)

                            Text(statusText)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Author
                    VStack(alignment: .leading, spacing: 4) {
                        Text("开发者:")
                            .fontWeight(.medium)

                        Text(pluginInfo.manifest.author)
                            .foregroundColor(.secondary)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("描述:")
                            .fontWeight(.medium)

                        Text(pluginInfo.manifest.description)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Platform
                    VStack(alignment: .leading, spacing: 4) {
                        Text("平台:")
                            .fontWeight(.medium)

                        HStack(spacing: 4) {
                            Image(systemName: platformIcon)
                                .foregroundColor(.accentColor)

                            Text(platformText)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Permissions
                    if !pluginInfo.manifest.permissions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("权限:")
                                .fontWeight(.medium)

                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(pluginInfo.manifest.permissions, id: \.self) { permission in
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.shield.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)

                                        Text(permission)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.leading, 8)
                        }
                    }

                    // Plugin ID
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ID:")
                            .fontWeight(.medium)

                        Text(pluginInfo.manifest.id)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    // Entrypoint
                    VStack(alignment: .leading, spacing: 4) {
                        Text("진입점:")
                            .fontWeight(.medium)

                        Text(pluginInfo.manifest.entrypoint)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }

            Divider()

            // Footer with actions
            HStack {
                Toggle(isOn: Binding(
                    get: { pluginInfo.isEnabled },
                    set: { _ in onToggle() }
                )) {
                    Text("활성화")
                        .fontWeight(.medium)
                }
                .toggleStyle(.switch)

                Spacer()

                Button("닫기") {
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var platformIcon: String {
        switch pluginInfo.manifest.platform {
        case .swift:
            return "swift"
        case .python:
            return "chevron.left.forwardslash.chevron.right"
        case .both:
            return "doc.on.doc"
        }
    }

    private var platformText: String {
        switch pluginInfo.manifest.platform {
        case .swift:
            return "Swift"
        case .python:
            return "Python"
        case .both:
            return "Swift + Python"
        }
    }

    private var statusColor: Color {
        switch pluginInfo.state {
        case .enabled:
            return .green
        case .disabled, .loaded:
            return .gray
        case .failed:
            return .red
        }
    }

    private var statusText: String {
        switch pluginInfo.state {
        case .enabled:
            return "활성화됨"
        case .disabled:
            return "비활성화됨"
        case .loaded:
            return "로드됨"
        case .failed(let error):
            return "실패: \(error.localizedDescription)"
        }
    }
}
