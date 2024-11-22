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

    override internal func updateSelectionCallback(_ row: Int) {
        delegate?.suggestCandidateSelectionChanged(row)
    }

    override internal func configureCellView(_ cell: CandidateTableCellView, forRow row: Int) {
        super.configureCellView(cell, forRow: row)
    }
}
