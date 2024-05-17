import Foundation

protocol IntConfigItem: ConfigItem<Int> {
    static var `default`: Int { get }
}

extension IntConfigItem {
    var value: Int {
        get {
            if let value = UserDefaults.standard.value(forKey: Self.key) {
                value as? Int ?? Self.default
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
    struct ZenzaiInferenceLimit: IntConfigItem {
        static let `default` = 1
        static let key = "dev.ensan.inputmethod.azooKeyMac.preference.zenzaiInferenceLimit"
    }
}
