//
//  azooKeyMacInputControllerHelper.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/05/16.
//

import Cocoa
import InputMethodKit

extension azooKeyMacInputController {
    // MARK: - Settings and Menu Items

    @objc func toggleLiveConversion(_ sender: Any) {
        applicationLogger.info("\(#line): toggleLiveConversion")
        let config = Config.LiveConversion()
        config.value = !self.liveConversionEnabled
        self.updateLiveConversionToggleMenuItem(newValue: config.value)
    }

    func updateLiveConversionToggleMenuItem(newValue: Bool) {
        self.liveConversionToggleMenuItem.title = newValue ? "ライブ変換をOFF" : "ライブ変換をON"
    }

    @objc func toggleEnglishConversion(_ sender: Any) {
        applicationLogger.info("\(#line): toggleEnglishConversion")
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

    var azooKeyMemoryDir: URL {
        if #available(macOS 13, *) {
            URL.applicationSupportDirectory
                .appending(path: "azooKey", directoryHint: .isDirectory)
                .appending(path: "memory", directoryHint: .isDirectory)
        } else {
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("azooKey", isDirectory: true)
                .appendingPathComponent("memory", isDirectory: true)
        }
    }

    func prepareApplicationSupportDirectory() {
        do {
            applicationLogger.info("\(#line, privacy: .public): Applicatiion Support Directory Path: \(self.azooKeyMemoryDir, privacy: .public)")
            try FileManager.default.createDirectory(at: self.azooKeyMemoryDir, withIntermediateDirectories: true)
        } catch {
            applicationLogger.error("\(#line, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
