//
//  DirectInputMode.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/05/12.
//

import AppKit
import Foundation
import InputMethodKit

class DirectInputMode: InputMode {
    func handle(_ event: NSEvent!) -> Bool {
        // keyDown以外は無視
        if event.type != .keyDown {
            return false
        }
        
        // 入力モードの切り替え以外は無視
        if event.keyCode != 104 && event.keyCode != 102 {
            return false
        }
        
        guard let inputController = NSApp.delegate as? azooKeyMacInputController else {
            return false
        }
        
        let clientAction =
            switch event.keyCode {
            case 102:  // Lang2/kVK_JIS_Eisu
                inputController.inputState.event(event, userAction: UserAction.英数)
            case 104:  // Lang1/kVK_JIS_Kana
                inputController.inputState.event(event, userAction: UserAction.かな)
            default:
                inputController.inputState.event(event, userAction: UserAction.unknown)
            }
        
        return inputController.handleClientAction(clientAction, client: inputController.client())
    }
}
