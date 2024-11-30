//
//  ReplaceSuggestionsViewController.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/11/17.
//

import Cocoa
import KanaKanjiConverterModule

@MainActor protocol ReplaceSuggestionsViewControllerDelegate: AnyObject {
    func replaceSuggestionSelectionChanged(_ row: Int)
    func replaceSuggestionSubmitted()
}

class ReplaceSuggestionsViewController: BaseCandidateViewController {
    weak var delegate: (any ReplaceSuggestionsViewControllerDelegate)?

    override internal func updateSelectionCallback(_ row: Int) {
        delegate?.replaceSuggestionSelectionChanged(row)
    }

    func submitSelectedCandidate() {
        delegate?.replaceSuggestionSubmitted()
    }

    // overrideキーワードを削除し、NSTableViewDelegateのメソッドとして実装
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        updateSelection(to: row)
        return true
    }

    override func resizeWindowToFitContent(cursorLocation: CGPoint) {
        guard let window = self.view.window, let screen = window.screen else {
            return
        }

        let numberOfRows = self.tableView.numberOfRows
        if numberOfRows == 0 {
            return
        }

        let rowHeight = self.tableView.rowHeight
        let tableViewHeight = CGFloat(numberOfRows) * rowHeight

        let maxWidth = candidates.reduce(0) { maxWidth, candidate in
            let attributedString = NSAttributedString(
                string: candidate.text,
                attributes: [.font: NSFont.systemFont(ofSize: 16)]
            )
            return max(maxWidth, attributedString.size().width)
        }

        // サジェストビュー用に横幅を広めに設定
        let windowWidth = maxWidth + 40

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
