import AppKit

private var dialogKey: UInt8 = 0

private class DialogContext {
    let dialog: NSPanel
    let rule: ReplacementRule?
    let triggerField: NSTextField
    let textView: NSTextView
    let enabledCheckbox: NSButton

    init(dialog: NSPanel, rule: ReplacementRule?, triggerField: NSTextField, textView: NSTextView, enabledCheckbox: NSButton) {
        self.dialog = dialog
        self.rule = rule
        self.triggerField = triggerField
        self.textView = textView
        self.enabledCheckbox = enabledCheckbox
    }
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private var tableView: NSTableView!
    private var storage: ReplacementStorage
    private var rules: [ReplacementRule] = []
    private var dialogContexts: [NSPanel: DialogContext] = [:]

    init(storage: ReplacementStorage) {
        self.storage = storage

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "텍스트 교체 설정"
        window.center()

        super.init(window: window)

        window.delegate = self
        setupUI()
        loadRules()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        // Create scroll view for table
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 60, width: 660, height: 380))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder

        // Create table view
        tableView = NSTableView(frame: scrollView.bounds)
        tableView.autoresizingMask = [.width, .height]
        tableView.delegate = self
        tableView.dataSource = self
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.allowsMultipleSelection = false
        tableView.usesAlternatingRowBackgroundColors = true

        // Add columns
        let enabledColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("enabled"))
        enabledColumn.title = "활성화"
        enabledColumn.width = 60
        enabledColumn.minWidth = 60
        enabledColumn.maxWidth = 60
        tableView.addTableColumn(enabledColumn)

        let triggerColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("trigger"))
        triggerColumn.title = "트리거 단어"
        triggerColumn.width = 200
        triggerColumn.minWidth = 100
        tableView.addTableColumn(triggerColumn)

        let replacementColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("replacement"))
        replacementColumn.title = "교체 텍스트"
        replacementColumn.width = 380
        replacementColumn.minWidth = 150
        tableView.addTableColumn(replacementColumn)

        scrollView.documentView = tableView
        contentView.addSubview(scrollView)

        // Create button toolbar
        let buttonY: CGFloat = 20
        let buttonHeight: CGFloat = 28

        let addButton = NSButton(frame: NSRect(x: 20, y: buttonY, width: 80, height: buttonHeight))
        addButton.title = "추가"
        addButton.bezelStyle = .rounded
        addButton.target = self
        addButton.action = #selector(addRule)
        contentView.addSubview(addButton)

        let editButton = NSButton(frame: NSRect(x: 110, y: buttonY, width: 80, height: buttonHeight))
        editButton.title = "편집"
        editButton.bezelStyle = .rounded
        editButton.target = self
        editButton.action = #selector(editRule)
        contentView.addSubview(editButton)

        let deleteButton = NSButton(frame: NSRect(x: 200, y: buttonY, width: 80, height: buttonHeight))
        deleteButton.title = "삭제"
        deleteButton.bezelStyle = .rounded
        deleteButton.target = self
        deleteButton.action = #selector(deleteRule)
        contentView.addSubview(deleteButton)

        window.contentView = contentView
    }

    private func loadRules() {
        rules = storage.getAll()
        tableView?.reloadData()
    }

    @objc private func addRule() {
        showEditDialog(rule: nil)
    }

    @objc private func editRule() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < rules.count else {
            showAlert(title: "선택 오류", message: "편집할 규칙을 선택하세요.")
            return
        }
        showEditDialog(rule: rules[selectedRow])
    }

    @objc private func deleteRule() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < rules.count else {
            showAlert(title: "선택 오류", message: "삭제할 규칙을 선택하세요.")
            return
        }

        let rule = rules[selectedRow]
        let alert = NSAlert()
        alert.messageText = "규칙 삭제"
        alert.informativeText = "'\(rule.trigger)' 규칙을 삭제하시겠습니까?"
        alert.addButton(withTitle: "삭제")
        alert.addButton(withTitle: "취소")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            storage.delete(id: rule.id)
            loadRules()
        }
    }

    private func showEditDialog(rule: ReplacementRule?) {
        let dialog = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        dialog.title = rule == nil ? "새 규칙 추가" : "규칙 편집"
        dialog.center()

        let contentView = NSView(frame: dialog.contentView!.bounds)

        // Trigger label and field
        let triggerLabel = NSTextField(labelWithString: "트리거 단어:")
        triggerLabel.frame = NSRect(x: 20, y: 250, width: 100, height: 20)
        contentView.addSubview(triggerLabel)

        let triggerField = NSTextField(frame: NSRect(x: 130, y: 248, width: 300, height: 24))
        triggerField.stringValue = rule?.trigger ?? ""
        triggerField.placeholderString = "예: 내 이메일"
        contentView.addSubview(triggerField)

        // Replacement label and text view
        let replacementLabel = NSTextField(labelWithString: "교체 텍스트:")
        replacementLabel.frame = NSRect(x: 20, y: 220, width: 100, height: 20)
        contentView.addSubview(replacementLabel)

        let scrollView = NSScrollView(frame: NSRect(x: 130, y: 80, width: 300, height: 150))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView(frame: scrollView.bounds)
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.string = rule?.replacement ?? ""
        textView.autoresizingMask = [.width, .height]
        scrollView.documentView = textView
        contentView.addSubview(scrollView)

        // Enabled checkbox
        let enabledCheckbox = NSButton(checkboxWithTitle: "활성화", target: nil, action: nil)
        enabledCheckbox.frame = NSRect(x: 130, y: 50, width: 100, height: 20)
        enabledCheckbox.state = (rule?.isEnabled ?? true) ? NSControl.StateValue.on : NSControl.StateValue.off
        contentView.addSubview(enabledCheckbox)

        // Buttons
        let saveButton = NSButton(frame: NSRect(x: 350, y: 15, width: 80, height: 28))
        saveButton.title = "저장"
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        contentView.addSubview(saveButton)

        let cancelButton = NSButton(frame: NSRect(x: 260, y: 15, width: 80, height: 28))
        cancelButton.title = "취소"
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)

        dialog.contentView = contentView

        // Store context
        let context = DialogContext(dialog: dialog, rule: rule, triggerField: triggerField, textView: textView, enabledCheckbox: enabledCheckbox)
        dialogContexts[dialog] = context

        // Set up button actions using associated objects
        saveButton.target = self
        saveButton.action = #selector(saveFromDialog(_:))
        objc_setAssociatedObject(saveButton, &dialogKey, dialog, .OBJC_ASSOCIATION_RETAIN)

        cancelButton.target = self
        cancelButton.action = #selector(cancelDialog(_:))
        objc_setAssociatedObject(cancelButton, &dialogKey, dialog, .OBJC_ASSOCIATION_RETAIN)

        dialog.makeKeyAndOrderFront(nil)
    }

    @objc private func saveFromDialog(_ sender: NSButton) {
        guard let dialog = objc_getAssociatedObject(sender, &dialogKey) as? NSPanel,
              let context = dialogContexts[dialog] else {
            return
        }

        let trigger = context.triggerField.stringValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let replacement = context.textView.string

        guard !trigger.isEmpty else {
            showAlert(title: "입력 오류", message: "트리거 단어를 입력하세요.")
            return
        }

        let isEnabled = context.enabledCheckbox.state == NSControl.StateValue.on

        if let existingRule = context.rule {
            // Update existing rule
            var updatedRule = existingRule
            updatedRule.trigger = trigger
            updatedRule.replacement = replacement
            updatedRule.isEnabled = isEnabled
            storage.update(updatedRule)
        } else {
            // Add new rule
            let newRule = ReplacementRule(trigger: trigger, replacement: replacement, isEnabled: isEnabled)
            storage.add(newRule)
        }

        loadRules()
        dialogContexts.removeValue(forKey: dialog)
        dialog.close()
    }

    @objc private func cancelDialog(_ sender: NSButton) {
        if let dialog = objc_getAssociatedObject(sender, &dialogKey) as? NSPanel {
            dialogContexts.removeValue(forKey: dialog)
            dialog.close()
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }
}

// MARK: - NSTableViewDataSource
extension SettingsWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return rules.count
    }
}

// MARK: - NSTableViewDelegate
extension SettingsWindowController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < rules.count else { return nil }
        let rule = rules[row]

        let identifier = tableColumn?.identifier.rawValue ?? ""

        if identifier == "enabled" {
            let cellView = NSTableCellView()
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleEnabled(_:)))
            checkbox.state = rule.isEnabled ? NSControl.StateValue.on : NSControl.StateValue.off
            checkbox.tag = row
            checkbox.frame = NSRect(x: 20, y: 2, width: 20, height: 18)
            cellView.addSubview(checkbox)
            return cellView
        } else if identifier == "trigger" {
            let cellView = NSTableCellView()
            let textField = NSTextField(labelWithString: rule.trigger)
            textField.frame = cellView.bounds
            textField.autoresizingMask = [.width, .height]
            cellView.addSubview(textField)
            return cellView
        } else if identifier == "replacement" {
            let cellView = NSTableCellView()
            let preview = rule.replacement.replacingOccurrences(of: "\n", with: " ")
            let displayText = preview.count > 80 ? String(preview.prefix(77)) + "..." : preview
            let textField = NSTextField(labelWithString: displayText)
            textField.frame = cellView.bounds
            textField.autoresizingMask = [.width, .height]
            textField.lineBreakMode = .byTruncatingTail
            cellView.addSubview(textField)
            return cellView
        }

        return nil
    }

    @objc private func toggleEnabled(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < rules.count else { return }

        var rule = rules[row]
        rule.isEnabled = sender.state == NSControl.StateValue.on
        storage.update(rule)
        loadRules()
    }
}
