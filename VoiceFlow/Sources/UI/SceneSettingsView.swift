import SwiftUI
import AppKit

struct SceneSettingsView: View {
    @State private var selectedScene: SceneType = .general
    @State private var showExportSuccess = false
    @State private var showExportError = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var currentProfile: SceneProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("场景设置")
                .font(.title2)
                .fontWeight(.bold)

            // Scene selector
            VStack(alignment: .leading, spacing: 12) {
                Text("选择场景")
                    .font(.headline)

                Picker("场景", selection: $selectedScene) {
                    ForEach(SceneType.allCases) { scene in
                        HStack {
                            Image(systemName: scene.icon)
                            Text(scene.displayName)
                        }
                        .tag(scene)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedScene) { newScene in
                    loadProfile(for: newScene)
                }

                Text(selectedScene.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Scene details
            VStack(alignment: .leading, spacing: 12) {
                Text("场景详情")
                    .font(.headline)

                if let profile = currentProfile {
                    HStack {
                        Image(systemName: selectedScene.icon)
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedScene.displayName)
                                .font(.body)
                                .fontWeight(.semibold)

                            Text("术语条目: \(profile.glossary.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(profile.enablePolish ? "启用润色 (\(profile.polishStyle.rawValue))" : "不润色")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    Text("正在加载...")
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Import/Export buttons
            VStack(alignment: .leading, spacing: 12) {
                Text("场景管理")
                    .font(.headline)

                HStack(spacing: 12) {
                    Button(action: exportScene) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("导出场景")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: importScene) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("导入场景")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            loadProfile(for: selectedScene)
        }
        .alert("导出成功", isPresented: $showExportSuccess) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("场景配置已成功导出")
        }
        .alert("导出失败", isPresented: $showExportError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("无法导出场景配置，请检查文件路径权限")
        }
        .alert("导入失败", isPresented: $showImportError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(importErrorMessage)
        }
    }

    private func loadProfile(for scene: SceneType) {
        currentProfile = SceneProfile.defaultProfile(for: scene)
    }

    private func exportScene() {
        let savePanel = NSSavePanel()
        savePanel.title = "导出场景配置"
        savePanel.message = "选择保存位置"
        savePanel.nameFieldStringValue = "\(selectedScene.rawValue).vfscene"
        savePanel.allowedContentTypes = [.init(filenameExtension: "vfscene")!]
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else {
                return
            }

            let success = SceneManager.shared.exportScene(
                sceneType: selectedScene,
                toPath: url.path
            )

            if success {
                showExportSuccess = true
            } else {
                showExportError = true
            }
        }
    }

    private func importScene() {
        let openPanel = NSOpenPanel()
        openPanel.title = "导入场景配置"
        openPanel.message = "选择要导入的场景文件"
        openPanel.allowedContentTypes = [.init(filenameExtension: "vfscene")!]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false

        openPanel.begin { response in
            guard response == .OK, let url = openPanel.url else {
                return
            }

            let result = SceneManager.shared.importScene(fromPath: url.path)

            switch result {
            case .success(let profile):
                // Update the current view with imported profile
                currentProfile = profile
                selectedScene = profile.sceneType
                NSLog("[SceneSettingsView] Successfully imported scene: \(profile.sceneType.rawValue)")

            case .failure(let error):
                importErrorMessage = error.localizedDescription
                showImportError = true
            }
        }
    }
}

#Preview {
    SceneSettingsView()
}
