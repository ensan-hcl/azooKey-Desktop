//
//  CandidateSupport.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/11/22.

import Cocoa

class NonClickableTableView: NSTableView {
    override func rightMouseDown(with event: NSEvent) {
        // Ignore right click events
    }

    override func mouseDown(with event: NSEvent) {
        // Ignore left click events
    }

    override func otherMouseDown(with event: NSEvent) {
        // Ignore other mouse button events
    }
}

class CandidateTableCellView: NSTableCellView {
    let candidateTextField: NSTextField

    override init(frame frameRect: NSRect) {
        self.candidateTextField = NSTextField(labelWithString: "")
        self.candidateTextField.font = NSFont.systemFont(ofSize: 16)
        super.init(frame: frameRect)
        self.addSubview(self.candidateTextField)

        self.candidateTextField.translatesAutoresizingMaskIntoConstraints = false
        self.candidateTextField.backgroundColor = .clear
        NSLayoutConstraint.activate([
            self.candidateTextField.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.candidateTextField.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.candidateTextField.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class CandidateTableRowView: NSTableRowView {
    override var isSelected: Bool {
        didSet {
            needsDisplay = true
        }
    }

    override func drawSelection(in dirtyRect: NSRect) {
        if self.selectionHighlightStyle != .none {
            NSColor.selectedContentBackgroundColor.setFill()
            dirtyRect.fill()
        }
    }
}
