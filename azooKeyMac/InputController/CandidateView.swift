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

    override func loadView() {
        let scrollView = NSScrollView()
        self.tableView = NSTableView()
        scrollView.documentView = self.tableView
        scrollView.hasVerticalScroller = true

        // Set up the composing text field
        self.composingTextField = NSTextField(labelWithString: "")
        self.composingTextField.font = NSFont.systemFont(ofSize: 14)

        let stackView = NSStackView(views: [self.composingTextField, scrollView])
        stackView.orientation = .vertical
        stackView.spacing = 10
        self.view = stackView

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CandidatesColumn"))
        column.title = "Candidates"
        self.tableView.addTableColumn(column)
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }

    func updateCandidates(_ candidates: [String]) {
        self.candidates = candidates
        self.tableView.reloadData()
    }

    func updateComposingText(_ text: String) {
        self.composingTextField.stringValue = text
    }

    override func interpretKeyEvents(_ events: [NSEvent]) {
        // Implement key event handling to navigate and select candidates
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

        // Configure the text field layout if necessary
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

