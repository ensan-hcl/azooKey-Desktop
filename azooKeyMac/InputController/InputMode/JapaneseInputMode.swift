//
//   JapaneseInputMode.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/05/12.
//
import AppKit
import InputMethodKit
import AppKit
import InputMethodKit

class JapaneseInputMode: InputMode {
    func handle(_ event: NSEvent!) -> Bool {
        // keyDown以外は無視
        if event.type != .keyDown {
            return false
        }
        
        guard let inputController = NSApp.delegate as? azooKeyMacInputController else {
            return false
        }
        
        // https://developer.mozilla.org/ja/docs/Web/API/UI_Events/Keyboard_event_code_values#mac_%E3%81%A7%E3%81%AE%E3%82%B3%E3%83%BC%E3%83%89%E5%80%A4
        let clientAction =
            switch event.keyCode {
            case 36:  // Enter
                inputController.inputState.event(event, userAction: UserAction.enter)
            case 48:  // Tab
                inputController.inputState.event(event, userAction: UserAction.unknown)
            case 49:  // Space
                inputController.inputState.event(event, userAction: UserAction.space)
            case 51:  // Delete
                inputController.inputState.event(event, userAction: UserAction.delete)
            case 53:  // Escape
                inputController.inputState.event(event, userAction: UserAction.unknown)
            case 102:  // Lang2/kVK_JIS_Eisu
                inputController.inputState.event(event, userAction: UserAction.英数)
            case 104:  // Lang1/kVK_JIS_Kana
                inputController.inputState.event(event, userAction: UserAction.かな)
            case 123:  // Left
                // uF702
                inputController.inputState.event(event, userAction: UserAction.navigation(.left))
            case 124:  // Right
                // uF703
                inputController.inputState.event(event, userAction: UserAction.navigation(.right))
            case 125:  // Down
                // uF701
                inputController.inputState.event(event, userAction: UserAction.navigation(.down))
            case 126:  // Up
                // uF700
                inputController.inputState.event(event, userAction: UserAction.navigation(.up))
            default:
                if let text = event.characters, inputController.isPrintable(text) {
                    inputController.inputState.event(event, userAction: UserAction.input(KeyMap.h2zMap(text)))
                } else {
                    inputController.inputState.event(event, userAction: UserAction.unknown)
                }
            }
        
        return inputController.handleClientAction(clientAction, client: inputController.client())
    }
}
