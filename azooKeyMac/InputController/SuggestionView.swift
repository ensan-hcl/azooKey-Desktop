//
//  Suggestion.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/09/21.
//

import Cocoa

class Suggestion: NSView, NSTableViewDataSource, NSTableViewDelegate {
    private let tableView: NSTableView
    private let scrollView: NSScrollView
    private var candidates: [String] = [] // 候補のリスト
    private var currentSelectedRow: Int = -1
    private let maxVisibleRows = 8 // 最大表示行数

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
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CandidateColumn"))
        column.resizingMask = .autoresizingMask
        self.tableView.addTableColumn(column)
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.headerView = nil // ヘッダーを非表示
        self.tableView.style = .plain
        self.tableView.gridStyleMask = .solidHorizontalGridLineMask // グリッド線を表示
        self.tableView.allowsEmptySelection = false // 必ず1つは選択されているようにする
        self.tableView.allowsMultipleSelection = false // 複数選択を無効化
        self.tableView.rowHeight = 22 // 行の高さを設定

        // ScrollViewのセットアップ
        self.scrollView.documentView = self.tableView
        self.scrollView.hasVerticalScroller = false // スクロールバーを非表示
        self.scrollView.hasHorizontalScroller = false
        self.scrollView.verticalScrollElasticity = .none
        self.scrollView.horizontalScrollElasticity = .none
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(self.scrollView)

        // ScrollViewのレイアウト
        NSLayoutConstraint.activate([
            self.scrollView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.scrollView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.scrollView.topAnchor.constraint(equalTo: self.topAnchor)
        ])
    }

    // 候補を表示し、最初のセルを選択状態にする
    func displayCandidates(_ candidates: [String]) {
        self.candidates = candidates
        self.currentSelectedRow = candidates.isEmpty ? -1 : 0
        self.tableView.reloadData()
        self.updateSelection(to: currentSelectedRow)
        self.updateTableSize() // 表示行数に応じて高さを調整
    }

    // テーブルの高さを候補数に合わせて更新
    private func updateTableSize() {
        // 表示する行数を決定（最大行数を超えないように）
        let numberOfRowsToShow = min(candidates.count, maxVisibleRows)
        let tableHeight = CGFloat(numberOfRowsToShow) * self.tableView.rowHeight

        // 最長の候補文字列の幅を計算
        let maxContentWidth = candidates.map { candidate in
            NSString(string: candidate).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13)]).width
        }.max() ?? 100 // 幅の最低値

        // 必要に応じてパディングを加えて幅を調整
        let adjustedWidth = maxContentWidth + 60

        // ScrollViewの高さと幅を更新
        if let scrollHeightConstraint = self.scrollView.constraints.first(where: { $0.firstAttribute == .height }) {
            scrollHeightConstraint.constant = tableHeight
        } else {
            let heightConstraint = self.scrollView.heightAnchor.constraint(equalToConstant: tableHeight)
            heightConstraint.isActive = true
        }

        if let scrollWidthConstraint = self.scrollView.constraints.first(where: { $0.firstAttribute == .width }) {
            scrollWidthConstraint.constant = adjustedWidth
        } else {
            let widthConstraint = self.scrollView.widthAnchor.constraint(equalToConstant: adjustedWidth)
            widthConstraint.isActive = true
        }

        // ウィンドウのサイズも調整
        if let window = self.window {
            var windowFrame = window.frame
            windowFrame.size = CGSize(width: adjustedWidth, height: tableHeight)
            window.setFrame(windowFrame, display: true, animate: true)
        }

        self.needsLayout = true
        self.layoutSubtreeIfNeeded()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        candidates.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier("CandidateCell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView

        if cell == nil {
            cell = CandidateTableCellView() // カスタムセルビューを使用
            cell?.identifier = cellIdentifier
        }

        if let cellView = cell as? CandidateTableCellView {
            updateCellView(cellView, forRow: row)
        }

        return cell
    }

    // MARK: - NSTableViewDelegate

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 {
            self.currentSelectedRow = selectedRow
            print("Selected candidate: \(candidates[selectedRow])")
        }
    }

    // セルの内容を更新
    private func updateCellView(_ cellView: CandidateTableCellView, forRow row: Int) {
        let displayText = "\(candidates[row])"

        let attributedString = NSMutableAttributedString(string: displayText)
        cellView.candidateTextField.attributedStringValue = attributedString
    }

    // 選択行の移動
    private func updateSelection(to row: Int) {
        guard row >= 0 else {
            return
        }
        self.tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        self.tableView.scrollRowToVisible(row)
        self.currentSelectedRow = row
        self.updateVisibleRows()
    }

    // 表示行の更新
    private func updateVisibleRows() {
        let visibleRows = self.tableView.rows(in: self.tableView.visibleRect)
        for row in visibleRows.lowerBound..<visibleRows.upperBound {
            if let cellView = self.tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? CandidateTableCellView {
                self.updateCellView(cellView, forRow: row)
            }
        }
    }

    // 選択された候補を取得するメソッドを追加
    func getSelectedCandidate() -> String? {
        guard currentSelectedRow >= 0 && currentSelectedRow < candidates.count else {
            return nil
        }
        return candidates[currentSelectedRow]
    }

    // 選択行を一つ下に移動
    private func moveSelectionDown() {
        let newRow = min(currentSelectedRow + 1, candidates.count - 1)
        updateSelection(to: newRow)
    }

    // 選択行を一つ上に移動
    private func moveSelectionUp() {
        let newRow = max(currentSelectedRow - 1, 0)
        updateSelection(to: newRow)
    }
}

class SuggestionController: NSViewController {
    override func loadView() {
        self.view = Suggestion()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureWindowForRoundedCorners()
        // サンプルのデータを設定
        if let suggestion = self.view as? Suggestion {
            suggestion.displayCandidates(["Option 1", "Option 2", "Option 3"])
        }
    }

    // ウィンドウの角丸設定
    private func configureWindowForRoundedCorners() {
        guard let window = self.view.window else {
            return
        }
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.masksToBounds = true
        window.styleMask = [.borderless, .resizable]
        window.isMovable = true
        window.hasShadow = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.contentView?.layer?.cornerRadius = 10
        window.backgroundColor = .clear
        window.isOpaque = false
    }

    func displayCandidates(_ candidates: [String], cursorPosition: NSPoint) {
        (self.view as? Suggestion)?.displayCandidates(candidates)
        self.positionWindowAtCursor(cursorPosition: cursorPosition)
    }

    private func positionWindowAtCursor(cursorPosition: NSPoint) {
        guard let window = self.view.window else {
            return
        }
        let windowSize = self.view.frame.size
        let screenFrame = NSScreen.main?.frame ?? .zero
        let position = NSPoint(x: min(cursorPosition.x, screenFrame.width - windowSize.width),
                               y: max(cursorPosition.y - windowSize.height + 22
                                      , 0))
        window.setFrameOrigin(position)
    }

    // 選択された候補を取得するメソッドを追加
    func getSelectedCandidate() -> String? {
        (self.view as? Suggestion)?.getSelectedCandidate()
    }
}
