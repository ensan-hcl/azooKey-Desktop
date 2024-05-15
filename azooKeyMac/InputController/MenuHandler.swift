//
//  MenuHandler.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/05/15.
//

import Cocoa

class MenuHandler {
    private let appMenu: NSMenu
    private let liveConversionToggleMenuItem: NSMenuItem
    private let englishConversionToggleMenuItem: NSMenuItem
    
    init() {
        self.appMenu = NSMenu(title: "azooKey")
        self.liveConversionToggleMenuItem = NSMenuItem(title: "ライブ変換をOFF", action: #selector(self.toggleLiveConversion(_:)), keyEquivalent: "")
        self.englishConversionToggleMenuItem = NSMenuItem(title: "英単語変換をON", action: #selector(self.toggleEnglishConversion(_:)), keyEquivalent: "")
        self.appMenu.addItem(self.liveConversionToggleMenuItem)
        self.appMenu.addItem(self.englishConversionToggleMenuItem)
        self.appMenu.addItem(NSMenuItem(title: "詳細設定を開く", action: #selector(self.openConfigWindow(_:)), keyEquivalent: ""))
        self.appMenu.addItem(NSMenuItem(title: "View on GitHub", action: #selector(self.openGitHubRepository(_:)), keyEquivalent: ""))
    }
    
    var menu: NSMenu {
        return appMenu
    }

    func updateLiveConversionToggleMenuItem(newValue: Bool) {
        self.liveConversionToggleMenuItem.title = newValue ? "ライブ変換をOFF" : "ライブ変換をON"
    }

    func updateEnglishConversionToggleMenuItem(newValue: Bool) {
        self.englishConversionToggleMenuItem.title = newValue ? "英単語変換をOFF" : "英単語変換をON"
    }

    @objc private func toggleLiveConversion(_ sender: Any) {
        let config = Config.LiveConversion()
        config.value.toggle()
        updateLiveConversionToggleMenuItem(newValue: config.value)
    }

    @objc private func toggleEnglishConversion(_ sender: Any) {
        let config = Config.EnglishConversion()
        config.value.toggle()
        updateEnglishConversionToggleMenuItem(newValue: config.value)
    }

    @objc private func openConfigWindow(_ sender: Any) {
        (NSApplication.shared.delegate as? AppDelegate)?.openConfigWindow()
    }

    @objc private func openGitHubRepository(_ sender: Any) {
        guard let url = URL(string: "https://github.com/ensan-hcl/azooKey-Desktop") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
