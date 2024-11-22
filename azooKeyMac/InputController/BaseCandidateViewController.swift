//
//  BaseCandidateViewController.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/11/22.

import Cocoa
import KanaKanjiConverterModule

class BaseCandidateViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    var candidates: [Candidate] = []
    var tableView: NSTableView!
    var currentSelectedRow: Int = -1

    override func loadView() {
        let scrollView = NSScrollView()
        self.tableView = NonClickableTableView()
        self.tableView.style = .plain
        self.tableView.selectionHighlightStyle = .regular
        scrollView.documentView = self.tableView
        scrollView.hasVerticalScroller = true

        self.tableView.gridStyleMask = .solidHorizontalGridLineMask
        self.view = scrollView

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CandidatesColumn"))
        self.tableView.headerView = nil
        self.tableView.addTableColumn(column)
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureWindowForRoundedCorners()
    }

    func configureWindowForRoundedCorners() {
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

    override func viewDidAppear() {
        super.viewDidAppear()
        configureWindowForRoundedCorners()
    }

    func updateCandidates(_ candidates: [Candidate], selectionIndex: Int?, cursorLocation: CGPoint) {
        self.candidates = candidates
        self.currentSelectedRow = selectionIndex ?? -1
        self.tableView.reloadData()
        self.resizeWindowToFitContent(cursorLocation: cursorLocation)
        self.updateSelection(to: selectionIndex ?? -1)
    }

    func updateSelection(to row: Int) {
        if row == -1 { return }

        self.tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        self.tableView.scrollRowToVisible(row)
        self.handleSelectionChange(row)
        self.currentSelectedRow = row
    }

    // Override point for subclasses
    @objc func handleSelectionChange(_ row: Int) {
        // To be implemented by subclasses
    }

    func resizeWindowToFitContent(cursorLocation: CGPoint) {
        guard let window = self.view.window,
              let screen = window.screen else { return }

        let numberOfRows = self.getNumberOfVisibleRows()
        if numberOfRows == 0 { return }

        let rowHeight = self.tableView.rowHeight
        let tableViewHeight = CGFloat(numberOfRows) * rowHeight

        // Calculate maximum width of candidates
        let maxWidth = candidates.reduce(0) { maxWidth, candidate in
            let attributedString = NSAttributedString(
                string: candidate.text,
                attributes: [.font: NSFont.systemFont(ofSize: 16)]
            )
            return max(maxWidth, attributedString.size().width)
        }

        let windowWidth = getWindowWidth(for: maxWidth)
        var newWindowFrame = window.frame
        newWindowFrame.size.width = windowWidth
        newWindowFrame.size.height = tableViewHeight

        // Position window relative to cursor
        let screenRect = screen.visibleFrame
        let cursorY = cursorLocation.y
        let cursorHeight: CGFloat = 16

        if cursorY - tableViewHeight < screenRect.origin.y {
            newWindowFrame.origin = CGPoint(x: cursorLocation.x, y: cursorLocation.y + cursorHeight)
        } else {
            newWindowFrame.origin = CGPoint(x: cursorLocation.x, y: cursorLocation.y - tableViewHeight - cursorHeight)
        }

        // Adjust if window would go off screen
        if newWindowFrame.maxX > screenRect.maxX {
            newWindowFrame.origin.x = screenRect.maxX - newWindowFrame.width
        }

        if newWindowFrame != window.frame {
            window.setFrame(newWindowFrame, display: true, animate: false)
        }
    }

    // Override points for subclasses
    func getWindowWidth(for contentWidth: CGFloat) -> CGFloat {
        return contentWidth + 30
    }

    func getNumberOfVisibleRows() -> Int {
        return candidates.count
    }

    func getSelectedCandidate() -> Candidate? {
        if currentSelectedRow >= 0 && currentSelectedRow < candidates.count {
            return candidates[currentSelectedRow]
        }
        return nil
    }

    // MARK: - TableView Delegate & DataSource Methods

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
        return CandidateTableRowView()
    }

    // Override point for subclasses
    @objc func configureCellView(_ cell: CandidateTableCellView, forRow row: Int) {
        cell.candidateTextField.stringValue = candidates[row].text
        if currentSelectedRow == row {
            cell.candidateTextField.textColor = .white
        } else {
            cell.candidateTextField.textColor = .textColor
        }
    }
}
