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
    private var composingTextField: NSTextField!
    weak var delegate: (any CandidatesViewControllerDelegate)?

    override func loadView() {
        let scrollView = NSScrollView()
        self.tableView = NSTableView()
        scrollView.documentView = self.tableView
        scrollView.hasVerticalScroller = true

        self.composingTextField = NSTextField(labelWithString: "")
        self.composingTextField.font = NSFont.systemFont(ofSize: 16)

        let stackView = NSStackView(views: [self.composingTextField, scrollView])
        stackView.orientation = .vertical
        stackView.spacing = 10
        self.view = stackView

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CandidatesColumn"))
        self.tableView.headerView = nil
        self.tableView.addTableColumn(column)
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }

    func updateCandidates(_ candidates: [String], cursorLocation: CGPoint) {
        self.candidates = candidates
        self.tableView.reloadData()
        self.resizeWindowToFitContent(cursorLocation: cursorLocation)
    }

    func clearCandidates() {
        self.candidates = []
        self.tableView.reloadData()
    }

    func updateComposingText(_ text: String) {
        self.composingTextField.stringValue = text
    }

    private func resizeWindowToFitContent(cursorLocation: CGPoint) {
        guard let window = self.view.window else { return }

        let numberOfRows = min(10, self.tableView.numberOfRows)
        let rowHeight = self.tableView.rowHeight
        let intercellSpacing = self.tableView.intercellSpacing.height
        let tableViewHeight = CGFloat(numberOfRows) * (rowHeight + intercellSpacing)

        let composingTextFieldHeight = self.composingTextField.intrinsicContentSize.height
        let stackViewSpacing = (self.view as! NSStackView).spacing
        let totalHeight = composingTextFieldHeight + stackViewSpacing + tableViewHeight

        var newWindowFrame = window.frame
        newWindowFrame.origin = cursorLocation
        if numberOfRows != 0 {
            newWindowFrame.size.width = min(newWindowFrame.size.width, 400)
        }
        let contentRect = window.contentRect(forFrameRect: newWindowFrame)
        let heightAdjustment = totalHeight - contentRect.height
        newWindowFrame.size.height += heightAdjustment
        newWindowFrame.origin.y -= newWindowFrame.size.height

        window.setFrame(newWindowFrame, display: true, animate: false)
    }

    func selectCandidate(offset: Int) {
        let selectedRow = self.tableView.selectedRow
        if selectedRow + offset < 0 {
            return
        }
        let nextRow = (selectedRow + offset) % self.candidates.count
        self.tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
        self.tableView.scrollRowToVisible(nextRow)
        let selectedCandidate = self.candidates[nextRow]
        self.delegate?.candidateSelectionChanged(selectedCandidate)
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
        cell?.candidateTextField.stringValue = candidates[row]
        return cell
    }
}

class CandidateTableCellView: NSTableCellView {
    let candidateTextField: NSTextField

    override init(frame frameRect: NSRect) {
        self.candidateTextField = NSTextField(labelWithString: "")
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
