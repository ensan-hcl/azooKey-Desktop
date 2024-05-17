//
//  BoolConfigItem.swift
//  azooKeyMac
//
//  Created by miwa on 2024/04/27.
//

import Foundation

protocol BoolConfigItem: ConfigItem<Bool> {
    static var `default`: Bool { get }
}

extension BoolConfigItem {
    var value: Bool {
        get {
            if let value = UserDefaults.standard.value(forKey: Self.key) {
                value as? Bool ?? Self.default
            } else {
                Self.default
            }
        }
        nonmutating set {
            UserDefaults.standard.set(newValue, forKey: Self.key)
        }
    }
}

extension Config {
    /// ライブ変換を有効化する設定
    struct LiveConversion: BoolConfigItem {
        static let `default` = true
        static var key: String = "dev.ensan.inputmethod.azooKeyMac.preference.enableLiveConversion"
    }
    /// 英語変換を有効化する設定
    struct EnglishConversion: BoolConfigItem {
        static let `default` = false
        static var key: String = "dev.ensan.inputmethod.azooKeyMac.preference.enableEnglishConversion"
    }
    /// 円マークの代わりにバックスラッシュを入力する設定
    struct TypeBackSlash: BoolConfigItem {
        static let `default` = false
        static var key: String = "dev.ensan.inputmethod.azooKeyMac.preference.typeBackSlash"
    }
    /// Zenzaiを利用する設定
    /// - warning: この設定がオンになっているとき、現在は学習をオフにしている
    struct ZenzaiIntegration: BoolConfigItem {
        static let `default` = true
        static var key: String = "dev.ensan.inputmethod.azooKeyMac.preference.enableZenzai"
    }
}
