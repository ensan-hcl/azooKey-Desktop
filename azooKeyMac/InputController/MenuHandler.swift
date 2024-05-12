//
//  MenuHandler.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/05/12.
//
import Foundation
import Cocoa
import OSLog

let applicationLogger: Logger = Logger(
    subsystem: "dev.ensan.inputmethod.azooKeyMac", category: "main")

class MenuHandler {
    private let appMenu: NSMenu
    private let liveConversionToggleMenuItem: NSMenuItem
    private let englishConversionToggleMenuItem: NSMenuItem

    init(inputController: azooKeyMacInputController) {
        self.appMenu = NSMenu(title: "azooKey")
        self.liveConversionToggleMenuItem = NSMenuItem(
            title: "ライブ変換をOFF", action: #selector(self.toggleLiveConversion(_:)), keyEquivalent: "")
        self.englishConversionToggleMenuItem = NSMenuItem(
            title: "英単語変換をON", action: #selector(self.toggleEnglishConversion(_:)),
            keyEquivalent: "")
        self.appMenu.addItem(self.liveConversionToggleMenuItem)
        self.appMenu.addItem(self.englishConversionToggleMenuItem)
        self.appMenu.addItem(
            NSMenuItem(
                title: "詳細設定を開く", action: #selector(self.openConfigWindow(_:)), keyEquivalent: ""))
        self.appMenu.addItem(
            NSMenuItem(
                title: "View on GitHub", action: #selector(self.openGitHubRepository(_:)),
                keyEquivalent: ""))
        
        self.updateLiveConversionToggleMenuItem(inputController: inputController)
        self.updateEnglishConversionToggleMenuItem(inputController: inputController)
    }

    var menu: NSMenu {
        return self.appMenu
    }

    @objc private func toggleLiveConversion(_ sender: Any) {
        applicationLogger.info("\(#line): toggleLiveConversion")
        guard let inputController = NSApp.delegate as? azooKeyMacInputController else {
            return
        }
        UserDefaults.standard.set(
            !inputController.liveConversionEnabled,
            forKey: "dev.ensan.inputmethod.azooKeyMac.preference.enableLiveConversion")
        self.updateLiveConversionToggleMenuItem(inputController: inputController)
    }

    func updateLiveConversionToggleMenuItem(inputController: azooKeyMacInputController) {
        self.liveConversionToggleMenuItem.title =
            inputController.liveConversionEnabled ? "ライブ変換をOFF" : "ライブ変換をON"
    }

    @objc private func toggleEnglishConversion(_ sender: Any) {
        applicationLogger.info("\(#line): toggleEnglishConversion")
        guard let inputController = NSApp.delegate as? azooKeyMacInputController else {
            return
        }
        UserDefaults.standard.set(
            !inputController.englishConversionEnabled,
            forKey: "dev.ensan.inputmethod.azooKeyMac.preference.enableEnglishConversion")
        self.updateEnglishConversionToggleMenuItem(inputController: inputController)
    }

    func updateEnglishConversionToggleMenuItem(inputController: azooKeyMacInputController) {
        self.englishConversionToggleMenuItem.title =
            inputController.englishConversionEnabled ? "英単語変換をOFF" : "英単語変換をON"
    }

    @objc private func openGitHubRepository(_ sender: Any) {
        guard let url = URL(string: "https://github.com/ensan-hcl/azooKey-Desktop") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func openConfigWindow(_ sender: Any) {
        guard let appDelegate = NSApp.delegate as? AppDelegate else {
            return
        }
        appDelegate.openConfigWindow()
    }
}
