//
//  SuggestCandidatesViewController.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/11/17.
//

import Cocoa
import KanaKanjiConverterModule

protocol SuggestCandidatesViewControllerDelegate: AnyObject {
    func suggestCandidateSelectionChanged(_ row: Int)
}

class SuggestCandidatesViewController: BaseCandidateViewController {
    weak var delegate: (any SuggestCandidatesViewControllerDelegate)?

    override func handleSelectionChange(_ row: Int) {
        delegate?.suggestCandidateSelectionChanged(row)
    }

    override func resizeWindowToFitContent(cursorLocation: CGPoint) {
        guard let window = self.view.window,
              let screen = window.screen else { return }

        let numberOfRows = self.tableView.numberOfRows
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

        let windowWidth = maxWidth + 30  // Slightly different padding from base class
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
}
