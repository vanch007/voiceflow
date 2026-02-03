import AppKit
import SwiftUI

final class DictionaryWindow {
    private var window: NSWindow?
    private let dictionaryManager: DictionaryManager

    init(dictionaryManager: DictionaryManager) {
        self.dictionaryManager = dictionaryManager
    }

    func show() {
        if window == nil {
            createWindow()
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func createWindow() {
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 400

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - windowWidth / 2
        let y = screenFrame.midY - windowHeight / 2

        let frame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)

        let w = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        w.title = "Custom Dictionary"
        w.level = .normal
        w.isReleasedWhenClosed = false
        w.center()

        let contentView = DictionaryContentView(dictionaryManager: dictionaryManager)
        w.contentView = NSHostingView(rootView: contentView)

        window = w
    }
}

private struct DictionaryContentView: View {
    @ObservedObject private var viewModel: DictionaryViewModel

    init(dictionaryManager: DictionaryManager) {
        self.viewModel = DictionaryViewModel(dictionaryManager: dictionaryManager)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Custom Dictionary")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("\(viewModel.words.count) words")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            // Word List
            if viewModel.words.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No custom words yet")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text("Add technical terms, names, or domain-specific words to improve recognition accuracy")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.words, id: \.self) { word in
                            HStack {
                                Text(word)
                                    .font(.system(size: 13))
                                Spacer()
                                Button(action: {
                                    viewModel.removeWord(word)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.selectedWord == word ? Color.accentColor.opacity(0.1) : Color.clear
                            )
                            .onTapGesture {
                                viewModel.selectedWord = word
                            }

                            if word != viewModel.words.last {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .controlBackgroundColor))
            }

            Divider()

            // Add Word Section
            HStack(spacing: 8) {
                TextField("Enter a word...", text: $viewModel.newWord, onCommit: {
                    viewModel.addWord()
                })
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

                Button(action: {
                    viewModel.addWord()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()

            Divider()

            // Action Buttons
            HStack {
                Button(action: {
                    viewModel.importDictionary()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 11))
                        Text("Import")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.plain)

                Button(action: {
                    viewModel.exportDictionary()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11))
                        Text("Export")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.words.isEmpty)

                Spacer()

                Button(action: {
                    viewModel.clearDictionary()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text("Clear All")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .disabled(viewModel.words.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

private class DictionaryViewModel: ObservableObject {
    @Published var words: [String] = []
    @Published var newWord: String = ""
    @Published var selectedWord: String?

    private let dictionaryManager: DictionaryManager

    init(dictionaryManager: DictionaryManager) {
        self.dictionaryManager = dictionaryManager
        self.words = dictionaryManager.getWords()

        // Listen for dictionary changes
        dictionaryManager.onDictionaryChanged = { [weak self] updatedWords in
            DispatchQueue.main.async {
                self?.words = updatedWords
            }
        }
    }

    func addWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        dictionaryManager.addWord(trimmed)
        newWord = ""
    }

    func removeWord(_ word: String) {
        dictionaryManager.removeWord(word)
    }

    func clearDictionary() {
        let alert = NSAlert()
        alert.messageText = "Clear All Words?"
        alert.informativeText = "This will remove all custom words from your dictionary. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            dictionaryManager.clearDictionary()
        }
    }

    func importDictionary() {
        let panel = NSOpenPanel()
        panel.title = "Import Dictionary"
        panel.message = "Select a JSON file containing custom words"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            let success = dictionaryManager.importFromFile(path: url.path)
            if !success {
                showErrorAlert(message: "Failed to import dictionary. Please ensure the file is a valid JSON array of strings.")
            }
        }
    }

    func exportDictionary() {
        let panel = NSSavePanel()
        panel.title = "Export Dictionary"
        panel.message = "Save custom dictionary as JSON file"
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "custom_dictionary.json"

        if panel.runModal() == .OK, let url = panel.url {
            let success = dictionaryManager.exportToFile(path: url.path)
            if !success {
                showErrorAlert(message: "Failed to export dictionary. Please try again.")
            }
        }
    }

    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
