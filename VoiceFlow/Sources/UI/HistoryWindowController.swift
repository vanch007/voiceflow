import AppKit

final class HistoryWindowController: NSWindowController {
    private var recordingHistory: RecordingHistory
    private var tableView: NSTableView!
    private var searchField: NSSearchField!
    private var filteredEntries: [RecordingEntry] = []
    private var currentSearchQuery: String = ""

    init(recordingHistory: RecordingHistory) {
        self.recordingHistory = recordingHistory
        self.filteredEntries = recordingHistory.entries

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "녹음 기록"
        window.center()
        window.setFrameAutosaveName("HistoryWindow")
        window.minSize = NSSize(width: 600, height: 400)

        super.init(window: window)

        setupUI()
        setupCallbacks()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow() {
        refreshData()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        // Search field at top
        searchField = NSSearchField(frame: NSRect(x: 20, y: window.frame.height - 60, width: 300, height: 24))
        searchField.autoresizingMask = [.maxXMargin, .minYMargin]
        searchField.placeholderString = "검색..."
        searchField.target = self
        searchField.action = #selector(searchFieldChanged)
        contentView.addSubview(searchField)

        // Clear all button
        let clearButton = NSButton(frame: NSRect(x: window.frame.width - 120, y: window.frame.height - 60, width: 100, height: 24))
        clearButton.autoresizingMask = [.minXMargin, .minYMargin]
        clearButton.title = "전체 삭제"
        clearButton.bezelStyle = .rounded
        clearButton.target = self
        clearButton.action = #selector(clearAllAction)
        contentView.addSubview(clearButton)

        // Scroll view and table view
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 20, width: window.frame.width - 40, height: window.frame.height - 100))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder

        tableView = NSTableView(frame: scrollView.bounds)
        tableView.autoresizingMask = [.width, .height]
        tableView.headerView = NSTableHeaderView()
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle

        // Create columns
        let timestampColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("timestamp"))
        timestampColumn.title = "시간"
        timestampColumn.width = 150
        timestampColumn.minWidth = 100
        tableView.addTableColumn(timestampColumn)

        let textColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text"))
        textColumn.title = "내용"
        textColumn.width = 500
        textColumn.minWidth = 200
        tableView.addTableColumn(textColumn)

        let durationColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("duration"))
        durationColumn.title = "길이"
        durationColumn.width = 80
        durationColumn.minWidth = 60
        tableView.addTableColumn(durationColumn)

        tableView.delegate = self
        tableView.dataSource = self

        scrollView.documentView = tableView
        contentView.addSubview(scrollView)

        window.contentView = contentView

        // Setup context menu
        let menu = NSMenu()
        let copyItem = NSMenuItem(title: "텍스트 복사", action: #selector(copyTextAction), keyEquivalent: "")
        copyItem.target = self
        menu.addItem(copyItem)

        let deleteItem = NSMenuItem(title: "삭제", action: #selector(deleteEntryAction), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(deleteItem)

        tableView.menu = menu
    }

    private func setupCallbacks() {
        recordingHistory.onEntriesChanged = { [weak self] in
            self?.refreshData()
        }
    }

    private func refreshData() {
        filteredEntries = recordingHistory.searchEntries(query: currentSearchQuery)
        tableView?.reloadData()
    }

    @objc private func searchFieldChanged() {
        currentSearchQuery = searchField.stringValue
        refreshData()
    }

    @objc private func copyTextAction() {
        let row = tableView.clickedRow
        guard row >= 0 && row < filteredEntries.count else { return }

        let entry = filteredEntries[row]
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)

        NSLog("[HistoryWindowController] Copied text: \(entry.text.prefix(50))...")
    }

    @objc private func deleteEntryAction() {
        let row = tableView.clickedRow
        guard row >= 0 && row < filteredEntries.count else { return }

        let entry = filteredEntries[row]
        let alert = NSAlert()
        alert.messageText = "삭제 확인"
        alert.informativeText = "이 녹음 기록을 삭제하시겠습니까?"
        alert.addButton(withTitle: "삭제")
        alert.addButton(withTitle: "취소")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            recordingHistory.deleteEntry(id: entry.id)
        }
    }

    @objc private func clearAllAction() {
        guard !recordingHistory.entries.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "기록 없음"
            alert.informativeText = "삭제할 녹음 기록이 없습니다."
            alert.addButton(withTitle: "확인")
            alert.alertStyle = .informational
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = "전체 삭제 확인"
        alert.informativeText = "모든 녹음 기록을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다."
        alert.addButton(withTitle: "전체 삭제")
        alert.addButton(withTitle: "취소")
        alert.alertStyle = .critical

        if alert.runModal() == .alertFirstButtonReturn {
            recordingHistory.clearAll()
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        if seconds < 60 {
            return "\(seconds)초"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return "\(minutes)분 \(remainingSeconds)초"
        }
    }
}

// MARK: - NSTableViewDataSource

extension HistoryWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredEntries.count
    }
}

// MARK: - NSTableViewDelegate

extension HistoryWindowController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredEntries.count else { return nil }

        let entry = filteredEntries[row]
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")

        let cellView = NSTextField(frame: .zero)
        cellView.isBordered = false
        cellView.backgroundColor = .clear
        cellView.isEditable = false
        cellView.isSelectable = false

        switch identifier.rawValue {
        case "timestamp":
            cellView.stringValue = formatTimestamp(entry.timestamp)
            cellView.font = NSFont.systemFont(ofSize: 12)
        case "text":
            cellView.stringValue = entry.text
            cellView.font = NSFont.systemFont(ofSize: 13)
            cellView.lineBreakMode = .byTruncatingTail
        case "duration":
            cellView.stringValue = formatDuration(entry.duration)
            cellView.font = NSFont.systemFont(ofSize: 12)
            cellView.alignment = .right
        default:
            break
        }

        return cellView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 24
    }
}
