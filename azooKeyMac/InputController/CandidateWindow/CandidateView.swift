//
//  CandidateView.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/08/03.
//

import Cocoa
import KanaKanjiConverterModule

protocol CandidatesViewControllerDelegate: AnyObject {
    func candidateSubmitted()
    func candidateSelectionChanged(_ row: Int)
}

class CandidatesViewController: BaseCandidateViewController {
    weak var delegate: (any CandidatesViewControllerDelegate)?
    private var showedRows: ClosedRange = 0...8
    var showCandidateIndex = false

    override func updateCandidates(_ candidates: [Candidate], selectionIndex: Int?, cursorLocation: CGPoint) {
        self.showedRows = selectionIndex == nil ? 0...8 : self.showedRows
        super.updateCandidates(candidates, selectionIndex: selectionIndex, cursorLocation: cursorLocation)
    }

    override internal func updateSelectionCallback(_ row: Int) {
        delegate?.candidateSelectionChanged(row)

        if !self.showedRows.contains(row) {
            if row < self.showedRows.lowerBound {
                self.showedRows = row...(row + 8)
            } else {
                self.showedRows = (row - 8)...row
            }
        }
    }

    override internal func configureCellView(_ cell: CandidateTableCellView, forRow row: Int) {
        let isWithinShowedRows = self.showedRows.contains(row)
        let displayIndex = row - self.showedRows.lowerBound + 1 // showedRowsの下限からの相対的な位置
        let displayText: String

        if isWithinShowedRows && self.showCandidateIndex {
            if displayIndex > 9 {
                displayText = " " + self.candidates[row].text // 行番号が10以上の場合、インデントを調整
            } else {
                displayText = "\(displayIndex). " + self.candidates[row].text
            }
        } else {
            displayText = self.candidates[row].text // showedRowsの範囲外では番号を付けない
        }

        // 数字部分と候補部分を別々に設定
        let attributedString = NSMutableAttributedString(string: displayText)
        let numberRange = (displayText as NSString).range(of: "\(displayIndex).")

        if numberRange.location != NSNotFound {
            attributedString.addAttributes([
                .font: NSFont.monospacedSystemFont(ofSize: 8, weight: .regular),
                .foregroundColor: currentSelectedRow == row ? NSColor.white : NSColor.gray,
                .baselineOffset: 2
            ], range: numberRange)
        }

        cell.candidateTextField.attributedStringValue = attributedString
    }

    func selectNumberCandidate(num: Int) {
        let nextRow = self.showedRows.lowerBound + num - 1
        self.updateSelection(to: nextRow)
    }

    func hide() {
        self.currentSelectedRow = -1
        self.showedRows = 0...8
    }

    override func resizeWindowToFitContent(cursorLocation: CGPoint) {
        guard let window = self.view.window, let screen = window.screen else {
            return
        }

        let numberOfRows = min(9, self.tableView.numberOfRows)
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

        // ウィンドウの幅を設定（番号とパディングのための追加幅を考慮）
        // 20 = corner radius * 2
        let windowWidth = if self.showCandidateIndex {
            maxWidth + 48
        } else {
            maxWidth + 20
        }

        var newWindowFrame = window.frame
        newWindowFrame.size.width = windowWidth
        newWindowFrame.size.height = tableViewHeight

        // 画面のサイズを取得
        let screenRect = screen.visibleFrame
        let cursorY = cursorLocation.y

        // カーソルの高さを考慮してウィンドウ位置を調整
        let cursorHeight: CGFloat = 16 // カーソルの高さを16ピクセルと仮定

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
}
