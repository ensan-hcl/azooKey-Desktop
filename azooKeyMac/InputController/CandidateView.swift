//
//  CandidateView.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/08/03.
//

import Cocoa

class CandidatesViewController: NSViewController {
    private var candidates: [String] = []
    private var tableView: NSTableView!
    weak var delegate: (any CandidatesViewControllerDelegate)?
    private var currentSelectedRow: Int = -1

    override func loadView() {
        let scrollView = NSScrollView()
        self.tableView = NonClickableTableView()
        scrollView.documentView = self.tableView
        scrollView.hasVerticalScroller = true

        // グリッドスタイルを設定してセル間に水平線を表示
        self.tableView.gridStyleMask = .solidHorizontalGridLineMask

        let stackView = NSStackView(views: [scrollView])
        stackView.orientation = .vertical
        stackView.spacing = 10
        self.view = stackView

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CandidatesColumn"))
        self.tableView.headerView = nil
        self.tableView.addTableColumn(column)
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // 角丸のためのウィンドウ設定
        configureWindowForRoundedCorners()
    }

    private func configureWindowForRoundedCorners() {
        guard let window = self.view.window else { return }

        // ウィンドウとそのコンテンツビューがレイヤーバックされるように設定
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.masksToBounds = true

        // ウィンドウをボーダーレスに設定
        window.styleMask = [.borderless, .resizable]
        window.isMovable = true
        window.hasShadow = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

        // 角丸を適用
        window.contentView?.layer?.cornerRadius = 10
        window.backgroundColor = .clear

        // 重要：黒い背景が角に見えないようにする
        window.isOpaque = false
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        configureWindowForRoundedCorners()
    }

    func updateCandidates(_ candidates: [String], cursorLocation: CGPoint) {
        self.candidates = candidates
        self.currentSelectedRow = -1  // 選択をリセット
        self.tableView.reloadData()
        self.resizeWindowToFitContent(cursorLocation: cursorLocation)
        self.selectFirstCandidate()  // 最初の候補を選択
    }

    private func updateVisibleRows() {
        let visibleRows = self.tableView.rows(in: self.tableView.visibleRect)
        for row in visibleRows.lowerBound..<visibleRows.upperBound {
            if let cellView = self.tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? CandidateTableCellView {
                self.updateCellView(cellView, forRow: row)
            }
        }
    }

    private func updateCellView(_ cellView: CandidateTableCellView, forRow row: Int) {
        let adjustedIndex = (row - self.currentSelectedRow + self.candidates.count) % self.candidates.count
        var displayText = ""
        if adjustedIndex == 0 {
            displayText = "1. \(self.candidates[row])"
        } else if adjustedIndex + 1 > 9 {
            displayText = "    \(self.candidates[row])"
        } else {
            displayText = "\(adjustedIndex + 1). \(self.candidates[row])"
        }
        cellView.candidateTextField.stringValue = displayText
    }

    func clearCandidates() {
        self.candidates = []
        self.tableView.reloadData()
    }

    func updateComposingText(_ text: String) {
        // pass
    }

    private func resizeWindowToFitContent(cursorLocation: CGPoint) {
        guard let window = self.view.window, let screen = window.screen else { return }

        let numberOfRows = min(9, self.tableView.numberOfRows)
        let rowHeight = self.tableView.rowHeight
        let tableViewHeight = CGFloat(numberOfRows) * rowHeight
        let stackViewSpacing = (self.view as! NSStackView).spacing
        let totalHeight = stackViewSpacing + tableViewHeight

        // 候補の最大幅を計算
        let maxWidth = candidates.reduce(0) { maxWidth, candidate in
            let attributedString = NSAttributedString(string: candidate, attributes: [.font: NSFont.systemFont(ofSize: 16)])
            let width = attributedString.size().width
            return max(maxWidth, width)
        }

        // ウィンドウの幅を設定（番号とパディングのための追加幅を考慮）
        let windowWidth = min(max(maxWidth + 50, 50), 400) // 最小200px、最大400px

        var newWindowFrame = window.frame
        newWindowFrame.size.width = windowWidth
        newWindowFrame.size.height = totalHeight

        // 画面のサイズを取得
        let screenRect = screen.visibleFrame
        let cursorY = cursorLocation.y

        // カーソルの高さを考慮してウィンドウ位置を調整
        let cursorHeight: CGFloat = 16 // カーソルの高さを16ピクセルと仮定

        // ウィンドウをカーソルの下に表示
        if cursorY - totalHeight < screenRect.origin.y {
            newWindowFrame.origin = CGPoint(x: cursorLocation.x, y: cursorLocation.y + cursorHeight)
        } else {
            newWindowFrame.origin = CGPoint(x: cursorLocation.x, y: cursorLocation.y - totalHeight - cursorHeight)
        }

        // 右端でウィンドウが画面外に出る場合は左にシフト
        if newWindowFrame.maxX > screenRect.maxX {
            newWindowFrame.origin.x = screenRect.maxX - newWindowFrame.width
        }

        window.setFrame(newWindowFrame, display: true, animate: false)
    }

    func selectCandidate(offset: Int) {
        let selectedRow = self.tableView.selectedRow
        if selectedRow + offset < 0 {
            return
        }
        let nextRow = (selectedRow + offset + self.candidates.count) % self.candidates.count
        self.tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)

        // 表示範囲
        if offset > 0 {
            self.tableView.scrollRowToVisible((selectedRow + offset + 8 + self.candidates.count) % self.candidates.count)
        } else {
            self.tableView.scrollRowToVisible((selectedRow + offset + self.candidates.count) % self.candidates.count)
        }
        let selectedCandidate = self.candidates[nextRow]
        self.delegate?.candidateSelectionChanged(selectedCandidate)

        // 新しい選択行を設定
        self.currentSelectedRow = nextRow

        // 表示を更新
        self.updateVisibleRows()
    }

    func selectFirstCandidate() {
        guard !self.candidates.isEmpty else {
            return
        }
        let nextRow = 0
        self.tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
        self.tableView.scrollRowToVisible(nextRow)
        let selectedCandidate = self.candidates[nextRow]
        self.delegate?.candidateSelectionChanged(selectedCandidate)

        // 新しい選択行を設定
        self.currentSelectedRow = nextRow

        // 表示を更新
        self.updateVisibleRows()
    }

    func confirmCandidateSelection() {
        let selectedRow = self.tableView.selectedRow
        if selectedRow >= 0 && selectedRow < self.candidates.count {
            let selectedCandidate = self.candidates[selectedRow]
            delegate?.candidateSelected(selectedCandidate)
        }
    }
}

extension CandidatesViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return candidates.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier("CandidateCell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? CandidateTableCellView
        if cell == nil {
            cell = CandidateTableCellView()
            cell?.identifier = cellIdentifier
        }

        if let cell = cell {
            self.updateCellView(cell, forRow: row)
        }

        return cell
    }
}

class NonClickableTableView: NSTableView {
    override func rightMouseDown(with event: NSEvent) {
        // 右クリックイベントを無視
    }

    override func mouseDown(with event: NSEvent) {
        // 左クリックイベントも無視する場合はこのメソッド内を空に
    }

    override func otherMouseDown(with event: NSEvent) {
        // 中クリックなどその他のマウスボタンのクリックも無視
    }
}

class CandidateTableCellView: NSTableCellView {
    let candidateTextField: NSTextField

    override init(frame frameRect: NSRect) {
        self.candidateTextField = NSTextField(labelWithString: "")
        // font size
        self.candidateTextField.font = NSFont.systemFont(ofSize: 16)
        super.init(frame: frameRect)
        self.addSubview(self.candidateTextField)

        self.candidateTextField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.candidateTextField.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.candidateTextField.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.candidateTextField.topAnchor.constraint(equalTo: self.topAnchor),
            self.candidateTextField.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

protocol CandidatesViewControllerDelegate: AnyObject {
    func candidateSelected(_ candidate: String)
    func candidateSelectionChanged(_ candidateString: String)
}
