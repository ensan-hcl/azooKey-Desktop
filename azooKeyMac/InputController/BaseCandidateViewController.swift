//
//  BaseCandidateViewController.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/11/17.
//

import Cocoa
import KanaKanjiConverterModule

class NonClickableTableView: NSTableView {
    override func rightMouseDown(with event: NSEvent) {}
    override func mouseDown(with event: NSEvent) {}
    override func otherMouseDown(with event: NSEvent) {}
}

class CandidateTableCellView: NSTableCellView {
    let candidateTextField: NSTextField

    override init(frame frameRect: NSRect) {
        self.candidateTextField = NSTextField(labelWithString: "")
        self.candidateTextField.font = NSFont.systemFont(ofSize: 16)
        super.init(frame: frameRect)
        self.addSubview(self.candidateTextField)

        self.candidateTextField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.candidateTextField.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.candidateTextField.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.candidateTextField.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        ])

        // 基本設定
        self.candidateTextField.isEditable = false
        self.candidateTextField.isBordered = false
        self.candidateTextField.drawsBackground = false
        self.candidateTextField.backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            candidateTextField.textColor = backgroundStyle == .emphasized ? .white : .textColor
        }
    }
}

class BaseCandidateViewController: NSViewController {
    internal var candidates: [Candidate] = []
    internal var tableView: NSTableView!
    internal var currentSelectedRow: Int = -1

    override func loadView() {
        let scrollView = NSScrollView()
        self.tableView = NonClickableTableView()
        self.tableView.style = .plain
        scrollView.documentView = self.tableView
        scrollView.hasVerticalScroller = true

        self.tableView.gridStyleMask = .solidHorizontalGridLineMask
        self.view = scrollView

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CandidatesColumn"))
        self.tableView.headerView = nil
        self.tableView.addTableColumn(column)
        self.tableView.delegate = self
        self.tableView.dataSource = self

        // 選択スタイルの設定
        self.tableView.selectionHighlightStyle = .regular
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureWindowForRoundedCorners()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        configureWindowForRoundedCorners()
    }

    internal func configureWindowForRoundedCorners() {
        guard let window = self.view.window else { return }

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

    func updateCandidates(_ candidates: [Candidate], selectionIndex: Int?, cursorLocation: CGPoint) {
        self.candidates = candidates
        self.currentSelectedRow = selectionIndex ?? -1
        self.tableView.reloadData()
        self.resizeWindowToFitContent(cursorLocation: cursorLocation)
        self.updateSelection(to: selectionIndex ?? -1)
    }

    internal func updateSelection(to row: Int) {
        if row == -1 { return }
        self.tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        self.tableView.scrollRowToVisible(row)
        self.updateSelectionCallback(row)
        self.currentSelectedRow = row
        self.updateVisibleRows()
    }

    internal func updateSelectionCallback(_ row: Int) {}

    internal func updateVisibleRows() {
        let visibleRows = self.tableView.rows(in: self.tableView.visibleRect)
        for row in visibleRows.lowerBound..<visibleRows.upperBound {
            if let cellView = self.tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? CandidateTableCellView {
                self.configureCellView(cellView, forRow: row)
            }
        }
    }

    internal func resizeWindowToFitContent(cursorLocation: CGPoint) {
        guard let window = self.view.window, let screen = window.screen else { return }

        let numberOfRows = self.tableView.numberOfRows
        if numberOfRows == 0 { return }

        let rowHeight = self.tableView.rowHeight
        let tableViewHeight = CGFloat(numberOfRows) * rowHeight

        let maxWidth = candidates.reduce(0) { maxWidth, candidate in
            let attributedString = NSAttributedString(
                string: candidate.text,
                attributes: [.font: NSFont.systemFont(ofSize: 16)]
            )
            return max(maxWidth, attributedString.size().width)
        }

        let windowWidth = maxWidth + 20
        var newWindowFrame = window.frame
        newWindowFrame.size.width = windowWidth
        newWindowFrame.size.height = tableViewHeight

        let screenRect = screen.visibleFrame
        let cursorY = cursorLocation.y
        let cursorHeight: CGFloat = 16

        if cursorY - tableViewHeight < screenRect.origin.y {
            newWindowFrame.origin = CGPoint(x: cursorLocation.x, y: cursorLocation.y + cursorHeight)
        } else {
            newWindowFrame.origin = CGPoint(x: cursorLocation.x, y: cursorLocation.y - tableViewHeight - cursorHeight)
        }

        if newWindowFrame.maxX > screenRect.maxX {
            newWindowFrame.origin.x = screenRect.maxX - newWindowFrame.width
        }

        if newWindowFrame != window.frame {
            window.setFrame(newWindowFrame, display: true, animate: false)
        }
    }

    func getSelectedCandidate() -> Candidate? {
        guard currentSelectedRow >= 0 && currentSelectedRow < candidates.count else { return nil }
        return candidates[currentSelectedRow]
    }

    func selectNextCandidate() {
        guard !candidates.isEmpty else { return }
        let nextRow = (currentSelectedRow + 1) % candidates.count
        updateSelection(to: nextRow)
    }

    func selectPrevCandidate() {
        guard !candidates.isEmpty else { return }
        let prevRow = (currentSelectedRow - 1 + candidates.count) % candidates.count
        updateSelection(to: prevRow)
    }

    internal func configureCellView(_ cell: CandidateTableCellView, forRow row: Int) {
        cell.candidateTextField.stringValue = candidates[row].text
    }
}

extension BaseCandidateViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        candidates.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier("CandidateCell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? CandidateTableCellView

        if cell == nil {
            cell = CandidateTableCellView()
            cell?.identifier = cellIdentifier
        }

        if let cell = cell {
            configureCellView(cell, forRow: row)
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let identifier = NSUserInterfaceItemIdentifier("CandidateRowView")
        var rowView = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableRowView

        if rowView == nil {
            rowView = NSTableRowView()
            rowView?.identifier = identifier
        }

        return rowView
    }
}
