//
//  ClientAction.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/05/12.
//

import Foundation
import InputMethodKit

indirect enum ClientAction {
    case `consume`
    case `fallthrough`
    case showCandidateWindow
    case hideCandidateWindow
    case appendToMarkedText(String)
    case removeLastMarkedText
    case moveCursorToStart
    case moveCursor(Int)
    case commitMarkedText
    case submitSelectedCandidate
    case forwardToCandidateWindow(NSEvent)
    case selectInputMode(InputMode)
    case sequence([ClientAction])

    enum InputMode {
        case roman
        case japanese
    }
}
