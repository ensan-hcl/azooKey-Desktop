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

    override func getNumberOfVisibleRows() -> Int {
        return min(9, self.tableView.numberOfRows)
    }

    override func getWindowWidth(for contentWidth: CGFloat) -> CGFloat {
        return contentWidth + (showCandidateIndex ? 48 : 20)
    }

    override func updateCandidates(_ candidates: [Candidate], selectionIndex: Int?, cursorLocation: CGPoint) {
        self.showedRows = selectionIndex == nil ? 0...8 : self.showedRows
        super.updateCandidates(candidates, selectionIndex: selectionIndex, cursorLocation: cursorLocation)
    }

    override func configureCellView(_ cell: CandidateTableCellView, forRow row: Int) {
        let isWithinShowedRows = self.showedRows.contains(row)
        let displayIndex = row - self.showedRows.lowerBound + 1
        let displayText: String

        if isWithinShowedRows && self.showCandidateIndex {
            displayText = displayIndex > 9 ?
                " " + candidates[row].text :
                "\(displayIndex). " + candidates[row].text
        } else {
            displayText = candidates[row].text
        }

        let attributedString = NSMutableAttributedString(string: displayText)
        let numberRange = (displayText as NSString).range(of: "\(displayIndex).")

        if numberRange.location != NSNotFound {
            attributedString.addAttributes([
                .font: NSFont.monospacedSystemFont(ofSize: 8, weight: .regular),
                .foregroundColor: currentSelectedRow == row ? NSColor.white : NSColor.gray,
                .baselineOffset: 2
            ], range: numberRange)
        }

        if currentSelectedRow == row {
            cell.candidateTextField.textColor = .white
        } else {
            cell.candidateTextField.textColor = .textColor
        }

        cell.candidateTextField.attributedStringValue = attributedString
    }

    override func handleSelectionChange(_ row: Int) {
        delegate?.candidateSelectionChanged(row)

        if !self.showedRows.contains(row) {
            if row < self.showedRows.lowerBound {
                self.showedRows = row...(row + 8)
            } else {
                self.showedRows = (row - 8)...row
            }
        }

        self.tableView.reloadData()
    }

    func selectNumberCandidate(num: Int) {
        let nextRow = self.showedRows.lowerBound + num - 1
        self.updateSelection(to: nextRow)
    }

    func hide() {
        self.currentSelectedRow = -1
        self.showedRows = 0...8
    }
}
