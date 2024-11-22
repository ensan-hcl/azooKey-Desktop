//
//  SuggestCandidatesViewController.swift
//  azooKeyMac
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

    override func getWindowWidth(for contentWidth: CGFloat) -> CGFloat {
        return contentWidth + 30  // Slightly different padding from CandidatesViewController
    }

    func selectNextCandidate() {
        if candidates.isEmpty { return }
        let nextRow = (currentSelectedRow + 1) % candidates.count
        updateSelection(to: nextRow)
    }

    func selectPrevCandidate() {
        if candidates.isEmpty { return }
        let prevRow = (currentSelectedRow - 1 + candidates.count) % candidates.count
        updateSelection(to: prevRow)
    }

    override func configureCellView(_ cell: CandidateTableCellView, forRow row: Int) {
        super.configureCellView(cell, forRow: row)

        // Set text color based on selection state
        if currentSelectedRow == row {
            cell.candidateTextField.textColor = .white
        } else {
            cell.candidateTextField.textColor = .textColor
        }
    }
}
