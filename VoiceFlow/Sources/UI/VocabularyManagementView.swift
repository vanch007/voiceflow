import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Vocabulary management view with master-detail layout
struct VocabularyManagementView: View {
    @ObservedObject private var storage = VocabularyStorage()
    @State private var selectedVocabulary: Vocabulary?
    @State private var showingAddVocabularySheet = false
    @State private var showingAddEntrySheet = false
    @State private var editingVocabulary: Vocabulary?
    @State private var editingEntry: VocabularyEntry?
    @State private var isImportingJSON = false
    @State private var isImportingCSV = false
    @State private var isExportingJSON = false
    @State private var isExportingCSV = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var showExportSuccess = false
    @State private var csvImportName = ""
    @State private var showCSVNamePrompt = false
    @State private var pendingCSVData: Data?

    var body: some View {
        HSplitView {
            // Left: Vocabulary list
            VStack(alignment: .leading, spacing: 0) {
                // Header with statistics
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("词汇表")
                            .font(.headline)
                        let stats = storage.statistics
                        Text("\(stats.vocabularyCount) 个词汇表 · \(stats.totalEntries) 个词条")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: {
                        editingVocabulary = nil
                        showingAddVocabularySheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .help("添加词汇表")
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Vocabulary list
                if storage.getAll().isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("暂无词汇表")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("点击 + 创建第一个词汇表")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedVocabulary) {
                        ForEach(storage.getAll()) { vocabulary in
                            VocabularyRow(vocabulary: vocabulary)
                                .tag(vocabulary)
                                .contextMenu {
                                    Button("编辑") {
                                        editingVocabulary = vocabulary
                                        showingAddVocabularySheet = true
                                    }

                                    Button("导出为 JSON") {
                                        selectedVocabulary = vocabulary
                                        isExportingJSON = true
                                    }

                                    Button("导出为 CSV") {
                                        selectedVocabulary = vocabulary
                                        isExportingCSV = true
                                    }

                                    Divider()

                                    Button("删除", role: .destructive) {
                                        storage.delete(id: vocabulary.id)
                                        if selectedVocabulary?.id == vocabulary.id {
                                            selectedVocabulary = nil
                                        }
                                    }
                                }
                        }
                    }
                }
            }
            .frame(minWidth: 250)

            // Right: Entry editor
            if let vocabulary = selectedVocabulary {
                VocabularyEditorView(
                    vocabulary: vocabulary,
                    storage: storage,
                    editingVocabulary: $editingVocabulary,
                    editingEntry: $editingEntry,
                    showingAddVocabularySheet: $showingAddVocabularySheet,
                    showingAddEntrySheet: $showingAddEntrySheet
                )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("选择词汇表")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("从左侧列表选择一个词汇表以查看和编辑词条")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button(action: { isImportingJSON = true }) {
                        Label("导入 JSON", systemImage: "doc.badge.arrow.up")
                    }

                    Button(action: { isImportingCSV = true }) {
                        Label("导入 CSV", systemImage: "tablecells.badge.arrow.up")
                    }
                } label: {
                    Label("导入", systemImage: "square.and.arrow.down")
                }
            }
        }
        .sheet(isPresented: $showingAddVocabularySheet, onDismiss: {
            editingVocabulary = nil
        }) {
            AddVocabularySheet(
                storage: storage,
                editingVocabulary: editingVocabulary,
                isPresented: $showingAddVocabularySheet,
                selectedVocabulary: $selectedVocabulary
            )
        }
        .sheet(isPresented: $showingAddEntrySheet, onDismiss: {
            editingEntry = nil
        }) {
            if let vocabulary = selectedVocabulary {
                AddEntrySheet(
                    storage: storage,
                    vocabulary: vocabulary,
                    editingEntry: editingEntry,
                    isPresented: $showingAddEntrySheet,
                    selectedVocabulary: $selectedVocabulary
                )
            }
        }
        .sheet(isPresented: $showCSVNamePrompt) {
            CSVImportNamePrompt(
                csvImportName: $csvImportName,
                isPresented: $showCSVNamePrompt,
                onConfirm: {
                    if let data = pendingCSVData, !csvImportName.isEmpty {
                        importCSV(data: data, name: csvImportName)
                        pendingCSVData = nil
                        csvImportName = ""
                    }
                }
            )
        }
        .fileImporter(
            isPresented: $isImportingJSON,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleJSONImport(result: result)
        }
        .fileImporter(
            isPresented: $isImportingCSV,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleCSVImport(result: result)
        }
        .fileExporter(
            isPresented: $isExportingJSON,
            document: VocabularyJSONDocument(vocabulary: selectedVocabulary),
            contentType: .json,
            defaultFilename: "\(selectedVocabulary?.name ?? "vocabulary").json"
        ) { result in
            handleExportResult(result: result, format: "JSON")
        }
        .fileExporter(
            isPresented: $isExportingCSV,
            document: VocabularyCSVDocument(vocabulary: selectedVocabulary, storage: storage),
            contentType: .commaSeparatedText,
            defaultFilename: "\(selectedVocabulary?.name ?? "vocabulary").csv"
        ) { result in
            handleExportResult(result: result, format: "CSV")
        }
        .alert("导入失败", isPresented: $showImportError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(importErrorMessage)
        }
        .alert("导出成功", isPresented: $showExportSuccess) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("词汇表已成功导出")
        }
    }

    // MARK: - Import/Export Handlers

    private func handleJSONImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let data = try Data(contentsOf: url)
                if let count = storage.importFromJSON(data: data) {
                    NSLog("[VocabularyManagementView] Imported \(count) vocabularies from JSON")
                } else {
                    importErrorMessage = "无法解析 JSON 文件，请检查格式是否正确"
                    showImportError = true
                }
            } catch {
                importErrorMessage = "无法读取文件: \(error.localizedDescription)"
                showImportError = true
            }

        case .failure(let error):
            importErrorMessage = "导入失败: \(error.localizedDescription)"
            showImportError = true
        }
    }

    private func handleCSVImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let data = try Data(contentsOf: url)
                pendingCSVData = data
                csvImportName = url.deletingPathExtension().lastPathComponent
                showCSVNamePrompt = true
            } catch {
                importErrorMessage = "无法读取文件: \(error.localizedDescription)"
                showImportError = true
            }

        case .failure(let error):
            importErrorMessage = "导入失败: \(error.localizedDescription)"
            showImportError = true
        }
    }

    private func importCSV(data: Data, name: String) {
        if let vocabulary = storage.importFromCSV(data: data, vocabularyName: name) {
            storage.add(vocabulary)
            selectedVocabulary = vocabulary
            NSLog("[VocabularyManagementView] Imported vocabulary '\(name)' from CSV with \(vocabulary.entryCount) entries")
        } else {
            importErrorMessage = "无法解析 CSV 文件。请确保格式为: term,pronunciation,mapping,category"
            showImportError = true
        }
    }

    private func handleExportResult(result: Result<URL, Error>, format: String) {
        switch result {
        case .success:
            showExportSuccess = true
        case .failure(let error):
            importErrorMessage = "导出失败: \(error.localizedDescription)"
            showImportError = true
        }
    }
}

// MARK: - Vocabulary Row

private struct VocabularyRow: View {
    let vocabulary: Vocabulary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "book.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(vocabulary.name)
                    .font(.headline)

                if !vocabulary.description.isEmpty {
                    Text(vocabulary.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Text("\(vocabulary.entryCount) 个词条")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Vocabulary Editor View

private struct VocabularyEditorView: View {
    let vocabulary: Vocabulary
    @ObservedObject var storage: VocabularyStorage
    @Binding var editingVocabulary: Vocabulary?
    @Binding var editingEntry: VocabularyEntry?
    @Binding var showingAddVocabularySheet: Bool
    @Binding var showingAddEntrySheet: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "book.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(vocabulary.name)
                            .font(.title2)
                            .fontWeight(.semibold)

                        if !vocabulary.description.isEmpty {
                            Text(vocabulary.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Button(action: {
                        editingVocabulary = vocabulary
                        showingAddVocabularySheet = true
                    }) {
                        Image(systemName: "pencil")
                    }
                    .help("编辑词汇表信息")
                }

                Divider()

                // Entries section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("词条列表")
                            .fontWeight(.medium)

                        Spacer()

                        Button(action: {
                            editingEntry = nil
                            showingAddEntrySheet = true
                        }) {
                            Image(systemName: "plus")
                        }
                        .help("添加词条")
                    }

                    if vocabulary.entries.isEmpty {
                        VStack(spacing: 8) {
                            Text("暂无词条")
                                .foregroundColor(.secondary)

                            Text("点击 + 添加词条到此词汇表")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        LazyVStack(spacing: 4) {
                            ForEach(vocabulary.entries) { entry in
                                EntryRow(
                                    entry: entry,
                                    onEdit: {
                                        editingEntry = entry
                                        showingAddEntrySheet = true
                                    },
                                    onDelete: {
                                        storage.deleteEntry(id: entry.id, from: vocabulary.id)
                                    }
                                )
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Entry Row

private struct EntryRow: View {
    let entry: VocabularyEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // Term
                Text(entry.term)
                    .font(.headline)

                // Pronunciation
                if let pronunciation = entry.pronunciation, !pronunciation.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.1")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(pronunciation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Mapping
                if let mapping = entry.mapping, !mapping.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(mapping)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Category
                if let category = entry.category, !category.isEmpty {
                    Text(category)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("编辑")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("删除")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

// MARK: - Add/Edit Vocabulary Sheet

private struct AddVocabularySheet: View {
    @ObservedObject var storage: VocabularyStorage
    let editingVocabulary: Vocabulary?
    @Binding var isPresented: Bool
    @Binding var selectedVocabulary: Vocabulary?

    @State private var name: String = ""
    @State private var description: String = ""

    private var isEditing: Bool { editingVocabulary != nil }

    var body: some View {
        VStack(spacing: 20) {
            Text(isEditing ? "编辑词汇表" : "新建词汇表")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("名称")
                        .fontWeight(.medium)
                    TextField("如：编程术语、医学词汇", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("描述（可选）")
                        .fontWeight(.medium)
                    TextField("简要描述此词汇表的用途", text: $description)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Spacer()

            HStack {
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isEditing ? "保存" : "创建") {
                    saveVocabulary()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400, height: 220)
        .onAppear {
            if let vocab = editingVocabulary {
                name = vocab.name
                description = vocab.description
            }
        }
    }

    private func saveVocabulary() {
        if let existing = editingVocabulary {
            var updated = existing
            updated.name = name
            updated.description = description
            storage.update(updated)
            selectedVocabulary = updated
        } else {
            let newVocabulary = Vocabulary(
                name: name,
                description: description
            )
            storage.add(newVocabulary)
            selectedVocabulary = newVocabulary
        }
        isPresented = false
    }
}

// MARK: - Add/Edit Entry Sheet

private struct AddEntrySheet: View {
    @ObservedObject var storage: VocabularyStorage
    let vocabulary: Vocabulary
    let editingEntry: VocabularyEntry?
    @Binding var isPresented: Bool
    @Binding var selectedVocabulary: Vocabulary?

    @State private var term: String = ""
    @State private var pronunciation: String = ""
    @State private var mapping: String = ""
    @State private var category: String = ""

    private var isEditing: Bool { editingEntry != nil }

    var body: some View {
        VStack(spacing: 20) {
            Text(isEditing ? "编辑词条" : "添加词条")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("词条")
                        .fontWeight(.medium)
                    TextField("如：React、Kubernetes", text: $term)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("发音（可选）")
                        .fontWeight(.medium)
                    TextField("如：ri ˈækt、lǐ míng", text: $pronunciation)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("映射（可选）")
                        .fontWeight(.medium)
                    TextField("如：React框架", text: $mapping)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("分类（可选）")
                        .fontWeight(.medium)
                    TextField("如：programming、medical", text: $category)
                        .textFieldStyle(.roundedBorder)
                }

                Text("词条将用于 ASR 热词识别，提高转录准确率")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack {
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isEditing ? "保存" : "添加") {
                    saveEntry()
                }
                .buttonStyle(.borderedProminent)
                .disabled(term.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400, height: 400)
        .onAppear {
            if let entry = editingEntry {
                term = entry.term
                pronunciation = entry.pronunciation ?? ""
                mapping = entry.mapping ?? ""
                category = entry.category ?? ""
            }
        }
    }

    private func saveEntry() {
        let entry = VocabularyEntry(
            id: editingEntry?.id ?? UUID(),
            term: term,
            pronunciation: pronunciation.isEmpty ? nil : pronunciation,
            mapping: mapping.isEmpty ? nil : mapping,
            category: category.isEmpty ? nil : category
        )

        if editingEntry != nil {
            storage.updateEntry(entry, in: vocabulary.id)
        } else {
            storage.addEntry(entry, to: vocabulary.id)
        }

        // Refresh selected vocabulary
        selectedVocabulary = storage.get(id: vocabulary.id)
        isPresented = false
    }
}

// MARK: - CSV Import Name Prompt

private struct CSVImportNamePrompt: View {
    @Binding var csvImportName: String
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("导入 CSV")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Text("词汇表名称")
                    .fontWeight(.medium)
                TextField("为导入的词汇表命名", text: $csvImportName)
                    .textFieldStyle(.roundedBorder)
            }

            Text("CSV 格式：term,pronunciation,mapping,category")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            HStack {
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("导入") {
                    onConfirm()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(csvImportName.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 350, height: 200)
    }
}

// MARK: - File Documents

private struct VocabularyJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let vocabulary: Vocabulary?

    init(vocabulary: Vocabulary?) {
        self.vocabulary = vocabulary
    }

    init(configuration: ReadConfiguration) throws {
        self.vocabulary = nil
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let vocabulary = vocabulary else {
            throw CocoaError(.fileWriteUnknown)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode([vocabulary])
        return FileWrapper(regularFileWithContents: data)
    }
}

private struct VocabularyCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    let vocabulary: Vocabulary?
    let storage: VocabularyStorage

    init(vocabulary: Vocabulary?, storage: VocabularyStorage) {
        self.vocabulary = vocabulary
        self.storage = storage
    }

    init(configuration: ReadConfiguration) throws {
        self.vocabulary = nil
        self.storage = VocabularyStorage()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let vocabulary = vocabulary,
              let data = storage.exportToCSV(vocabularyID: vocabulary.id) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Preview

#Preview("Vocabulary Management") {
    VocabularyManagementView()
        .frame(width: 800, height: 600)
}
