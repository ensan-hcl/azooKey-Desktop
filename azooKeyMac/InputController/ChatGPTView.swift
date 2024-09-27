//
//  ChatGPTView.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/09/21.
//

import Cocoa

class ChatGPTView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    private let tableView: NSTableView
    private let scrollView: NSScrollView
    private var candidates: [String] = [] // 候補のリスト

    override init(frame frameRect: NSRect) {
        self.tableView = NSTableView()
        self.scrollView = NSScrollView()
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.setupView()
    }

    required init?(coder decoder: NSCoder) {
        self.tableView = NSTableView()
        self.scrollView = NSScrollView()
        super.init(coder: decoder)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.setupView()
    }

    private func setupView() {
        // TableViewのセットアップ
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "CandidateColumn"))
        column.title = "Candidates"
        self.tableView.addTableColumn(column)
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.headerView = nil // ヘッダーを非表示

        // ScrollViewのセットアップ
        self.scrollView.documentView = self.tableView
        self.scrollView.hasVerticalScroller = true
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(self.scrollView)

        // ScrollViewのレイアウト
        NSLayoutConstraint.activate([
            self.scrollView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 10),
            self.scrollView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -10),
            self.scrollView.topAnchor.constraint(equalTo: self.topAnchor, constant: 10),
            self.scrollView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -10)
        ])
    }

    // 候補を表示し、最初のセルを選択状態にする
    func displayCandidates(_ candidates: [String]) {
        self.candidates = candidates
        self.tableView.reloadData()
        if !candidates.isEmpty {
            self.tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            self.tableView.scrollRowToVisible(0)
        }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        candidates.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "CandidateCell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView

        if cell == nil {
            cell = NSTableCellView()
            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(textField)
            cell?.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 5),
                textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -5),
                textField.topAnchor.constraint(equalTo: cell!.topAnchor, constant: 5),
                textField.bottomAnchor.constraint(equalTo: cell!.bottomAnchor, constant: -5)
            ])

            cell?.identifier = cellIdentifier
        }

        cell?.textField?.stringValue = candidates[row]
        return cell
    }

    // MARK: - NSTableViewDelegate

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 {
            print("Selected candidate: \(candidates[selectedRow])")
        }
    }
}

class ChatGPTViewController: NSViewController {
    override func loadView() {
        self.view = ChatGPTView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureWindowForAppearance()
        // サンプルのデータを設定
        if let chatGPTView = self.view as? ChatGPTView {
            chatGPTView.displayCandidates(["Option 1", "Option 2", "Option 3"])
        }
    }

    private func configureWindowForAppearance() {
        guard let window = self.view.window else {
            return
        }
        window.styleMask = [.borderless, .resizable]
        window.isOpaque = false
        window.backgroundColor = .clear
    }

    func displayCandidates(_ candidates: [String], cursorPosition: NSPoint) {
        (self.view as? ChatGPTView)?.displayCandidates(candidates)
        self.positionWindowAtCursor(cursorPosition: cursorPosition)
    }

    private func positionWindowAtCursor(cursorPosition: NSPoint) {
        guard let window = self.view.window else {
            return
        }
        let windowSize = self.view.frame.size
        let screenFrame = NSScreen.main?.frame ?? .zero
        let position = NSPoint(x: min(cursorPosition.x, screenFrame.width - windowSize.width),
                               y: max(cursorPosition.y - windowSize.height, 0))
        window.setFrameOrigin(position)
    }
}
