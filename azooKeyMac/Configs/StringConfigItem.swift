//
//  StringConfigItem.swift
//  azooKeyMac
//
//  Created by miwa on 2024/04/27.
//

import Foundation

protocol StringConfigItem: ConfigItem<String> {}

extension StringConfigItem {
    var value: String {
        get {
            UserDefaults.standard.string(forKey: Self.key) ?? ""
        }
        nonmutating set {
            UserDefaults.standard.set(newValue, forKey: Self.key)
        }
    }
}

extension Config {
    struct OpenAiApiKey: StringConfigItem {
        static var key: String = "dev.ensan.inputmethod.azooKeyMac.preference.OpenAiApiKey"
    }
}

extension Config {
    struct ZenzaiProfile: StringConfigItem {
        static var key: String = "dev.ensan.inputmethod.azooKeyMac.preference.ZenzaiProfile"
    }
}
