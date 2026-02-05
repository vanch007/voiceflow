import AppKit
import SwiftUI

/// Window controller for dictionary and terminology learning UI
final class DictionaryWindow {
    private var window: NSWindow?
    private let dictionaryManager: DictionaryManager
    private let termLearner: TermLearner

    init(dictionaryManager: DictionaryManager, termLearner: TermLearner) {
        self.dictionaryManager = dictionaryManager
        self.termLearner = termLearner
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
        let windowWidth: CGFloat = 600
        let windowHeight: CGFloat = 500

        let contentRect = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)

        let w = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        w.title = "Dictionary & Suggestions"
        w.center()
        w.isReleasedWhenClosed = false
        w.setFrameAutosaveName("DictionaryWindow")

        // Create SwiftUI content view
        let contentView = DictionaryContentView(
            dictionaryManager: dictionaryManager,
            termLearner: termLearner
        )

        w.contentView = NSHostingView(rootView: contentView)

        self.window = w
    }
}

// MARK: - SwiftUI Content View

private struct DictionaryContentView: View {
    let dictionaryManager: DictionaryManager
    let termLearner: TermLearner

    @State private var selectedTab = 0
    @State private var dictionaryWords: [String] = []
    @State private var suggestions: [LearnedTerm] = []
    @State private var newWord: String = ""

    var body: some View {
        TabView(selection: $selectedTab) {
            // Dictionary Tab
            DictionaryTabView(
                dictionaryWords: $dictionaryWords,
                newWord: $newWord,
                dictionaryManager: dictionaryManager
            )
            .tabItem {
                Label("Dictionary", systemImage: "book.closed")
            }
            .tag(0)

            // Suggestions Tab
            SuggestionsTabView(
                suggestions: $suggestions,
                dictionaryManager: dictionaryManager,
                termLearner: termLearner
            )
            .tabItem {
                Label("Suggestions", systemImage: "lightbulb")
            }
            .tag(1)
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            loadData()
            setupCallbacks()
        }
    }

    private func loadData() {
        dictionaryWords = dictionaryManager.getWords()
        suggestions = termLearner.suggestions
    }

    private func setupCallbacks() {
        dictionaryManager.onDictionaryChanged = { [weak dictionaryManager] words in
            DispatchQueue.main.async {
                self.dictionaryWords = dictionaryManager?.getWords() ?? []
            }
        }

        termLearner.onSuggestionsChanged = { [weak termLearner] in
            DispatchQueue.main.async {
                self.suggestions = termLearner?.suggestions ?? []
            }
        }
    }
}

// MARK: - Dictionary Tab View

private struct DictionaryTabView: View {
    @Binding var dictionaryWords: [String]
    @Binding var newWord: String
    let dictionaryManager: DictionaryManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Dictionary")
                .font(.headline)

            // Add new word section
            HStack {
                TextField("Add new word", text: $newWord)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addWord()
                    }

                Button("Add") {
                    addWord()
                }
                .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Divider()

            // Word list
            if dictionaryWords.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No custom words yet")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(dictionaryWords, id: \.self) { word in
                            HStack {
                                Text(word)
                                    .font(.body)

                                Spacer()

                                Button(action: {
                                    dictionaryManager.removeWord(word)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                        }
                    }
                }
            }
        }
    }

    private func addWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        dictionaryManager.addWord(trimmed)
        newWord = ""
    }
}

// MARK: - Suggestions Tab View

private struct SuggestionsTabView: View {
    @Binding var suggestions: [LearnedTerm]
    let dictionaryManager: DictionaryManager
    let termLearner: TermLearner

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Term Suggestions")
                .font(.headline)

            Text("These terms were frequently used in your transcriptions")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            // Suggestions list
            if suggestions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No suggestions available")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Text("Suggestions appear when terms are used frequently in transcriptions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(suggestions) { suggestion in
                            SuggestionRow(
                                suggestion: suggestion,
                                onApprove: {
                                    approveSuggestion(suggestion)
                                },
                                onReject: {
                                    rejectSuggestion(suggestion)
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    private func approveSuggestion(_ suggestion: LearnedTerm) {
        // Add to dictionary with metadata
        dictionaryManager.addWord(suggestion.term, metadata: suggestion)

        // Mark as approved in term learner
        termLearner.approveSuggestion(id: suggestion.id)

        NSLog("[DictionaryWindow] Approved suggestion: \(suggestion.term)")
    }

    private func rejectSuggestion(_ suggestion: LearnedTerm) {
        termLearner.rejectSuggestion(id: suggestion.id)
        NSLog("[DictionaryWindow] Rejected suggestion: \(suggestion.term)")
    }
}

// MARK: - Suggestion Row View

private struct SuggestionRow: View {
    let suggestion: LearnedTerm
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.term)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Used \(suggestion.frequency) times")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onReject) {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Reject this suggestion")

                Button(action: onApprove) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .help("Add to dictionary")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}
