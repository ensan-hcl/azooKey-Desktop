//
//  SuggestCandidatesViewController.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/11/17.
//

import Cocoa
import KanaKanjiConverterModule

class SuggestCandidatesViewController: NSViewController {
    private var candidates: [Candidate] = []
    private var tableView: NSTableView!
    weak var delegate: (any SuggestCandidatesViewControllerDelegate)?
    private var currentSelectedRow: Int = -1

    override func loadView() {
        let scrollView = NSScrollView()
        self.tableView = NonClickableTableView()
        self.tableView.style = .plain
        scrollView.documentView = self.tableView
        scrollView.hasVerticalScroller = true

        // グリッドスタイルを設定
        self.tableView.gridStyleMask = .solidHorizontalGridLineMask
        self.view = scrollView

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SuggestCandidatesColumn"))
        self.tableView.headerView = nil
        self.tableView.addTableColumn(column)
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureWindowForRoundedCorners()
    }

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

    private func updateSelection(to row: Int) {
        if row == -1 {
            return
        }
        self.tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        self.tableView.scrollRowToVisible(row)
        self.delegate?.suggestCandidateSelectionChanged(row)
        self.currentSelectedRow = row
    }

    private func resizeWindowToFitContent(cursorLocation: CGPoint) {
        guard let window = self.view.window, let screen = window.screen else {
            return
        }

        let numberOfRows = self.tableView.numberOfRows
        if numberOfRows == 0 {
            return
        }
        let rowHeight = self.tableView.rowHeight
        let tableViewHeight = CGFloat(numberOfRows) * rowHeight

        // 候補の最大幅を計算
        let maxWidth = candidates.reduce(0) { maxWidth, candidate in
            let attributedString = NSAttributedString(string: candidate.text, attributes: [.font: NSFont.systemFont(ofSize: 16)])
            let width = attributedString.size().width
            return max(maxWidth, width)
        }

        // ウィンドウの幅を設定
        let windowWidth = maxWidth + 20

        var newWindowFrame = window.frame
        newWindowFrame.size.width = windowWidth
        newWindowFrame.size.height = tableViewHeight

        // 画面のサイズを取得
        let screenRect = screen.visibleFrame
        let cursorY = cursorLocation.y
        let cursorHeight: CGFloat = 16

        // ウィンドウをカーソルの下に表示
        if cursorY - tableViewHeight < screenRect.origin.y {
            newWindowFrame.origin = CGPoint(x: cursorLocation.x, y: cursorLocation.y + cursorHeight)
        } else {
            newWindowFrame.origin = CGPoint(x: cursorLocation.x, y: cursorLocation.y - tableViewHeight - cursorHeight)
        }

        // 右端でウィンドウが画面外に出る場合は左にシフト
        if newWindowFrame.maxX > screenRect.maxX {
            newWindowFrame.origin.x = screenRect.maxX - newWindowFrame.width
        }
        if newWindowFrame != window.frame {
            window.setFrame(newWindowFrame, display: true, animate: false)
        }
    }

    func selectNextCandidate() {
        if self.candidates.isEmpty {
            return
        }
        let nextRow = (self.currentSelectedRow + 1) % self.candidates.count
        self.updateSelection(to: nextRow)
    }

    func getSelectedCandidate() -> Candidate? {
        if self.currentSelectedRow >= 0 && self.currentSelectedRow < candidates.count {
            return candidates[self.currentSelectedRow]
        }
        return nil
    }
}

extension SuggestCandidatesViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        candidates.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier("SuggestCandidateCell")
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? CandidateTableCellView
        if cell == nil {
            cell = CandidateTableCellView()
            cell?.identifier = cellIdentifier
        }

        if let cell = cell {
            cell.candidateTextField.stringValue = candidates[row].text
        }

        return cell
    }
}

protocol SuggestCandidatesViewControllerDelegate: AnyObject {
    func suggestCandidateSelectionChanged(_ row: Int)
}
