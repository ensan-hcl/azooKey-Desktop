import Cocoa
import InputMethodKit

extension azooKeyMacInputController {
    // MARK: - Settings and Menu Items

    func setupMenu() {
        self.zenzaiToggleMenuItem = NSMenuItem(title: "ZenzaiをOFF", action: #selector(self.toggleZenzai(_:)), keyEquivalent: "")
        self.liveConversionToggleMenuItem = NSMenuItem(title: "ライブ変換をOFF", action: #selector(self.toggleLiveConversion(_:)), keyEquivalent: "")
        self.englishConversionToggleMenuItem = NSMenuItem(title: "英単語変換をON", action: #selector(self.toggleEnglishConversion(_:)), keyEquivalent: "")
        self.appMenu.addItem(self.zenzaiToggleMenuItem)
        self.appMenu.addItem(self.liveConversionToggleMenuItem)
        self.appMenu.addItem(self.englishConversionToggleMenuItem)
        self.appMenu.addItem(NSMenuItem(title: "詳細設定を開く", action: #selector(self.openConfigWindow(_:)), keyEquivalent: ""))
        self.appMenu.addItem(NSMenuItem(title: "View on GitHub", action: #selector(self.openGitHubRepository(_:)), keyEquivalent: ""))
    }

    @objc private func toggleZenzai(_ sender: Any) {
        self.segmentsManager.appendDebugMessage("\(#line): toggleZenzai")
        let config = Config.ZenzaiIntegration()
        config.value = !self.zenzaiEnabled
        self.updateZenzaiToggleMenuItem(newValue: config.value)
    }

    func updateZenzaiToggleMenuItem(newValue: Bool) {
        self.zenzaiToggleMenuItem.title = if newValue {
            "ZenzaiをOFF"
        } else {
            "ZenzaiをON"
        }
    }

    @objc func toggleLiveConversion(_ sender: Any) {
        self.segmentsManager.appendDebugMessage("\(#line): toggleLiveConversion")
        let config = Config.LiveConversion()
        config.value = !self.liveConversionEnabled
        self.updateLiveConversionToggleMenuItem(newValue: config.value)
    }

    func updateLiveConversionToggleMenuItem(newValue: Bool) {
        self.liveConversionToggleMenuItem.title = newValue ? "ライブ変換をOFF" : "ライブ変換をON"
    }

    @objc func toggleEnglishConversion(_ sender: Any) {
        self.segmentsManager.appendDebugMessage("\(#line): toggleEnglishConversion")
        let config = Config.EnglishConversion()
        config.value = !self.englishConversionEnabled
        self.updateEnglishConversionToggleMenuItem(newValue: config.value)
    }

    func updateEnglishConversionToggleMenuItem(newValue: Bool) {
        self.englishConversionToggleMenuItem.title = newValue ? "英単語変換をOFF" : "英単語変換をON"
    }

    @objc func openGitHubRepository(_ sender: Any) {
        guard let url = URL(string: "https://github.com/ensan-hcl/azooKey-Desktop") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc func openConfigWindow(_ sender: Any) {
        (NSApplication.shared.delegate as? AppDelegate)!.openConfigWindow()
    }

    // MARK: - Application Support Directory
    func prepareApplicationSupportDirectory() {
        do {
            self.segmentsManager.appendDebugMessage("\(#line): Applicatiion Support Directory Path: \(self.segmentsManager.azooKeyMemoryDir)")
            try FileManager.default.createDirectory(at: self.segmentsManager.azooKeyMemoryDir, withIntermediateDirectories: true)
        } catch {
            self.segmentsManager.appendDebugMessage("\(#line): \(error.localizedDescription)")
        }
    }
}
