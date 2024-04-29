//
//  LearningConfig.swift
//  azooKeyMac
//
//  Created by miwa on 2024/04/27.
//

import Foundation
import enum KanaKanjiConverterModuleWithDefaultDictionary.LearningType

protocol CustomCodableConfigItem: ConfigItem {
    static var `default`: Value { get }
}

extension CustomCodableConfigItem {
    var value: Value {
        get {
            do {
                let decoded = try JSONDecoder().decode(Value.self, from: UserDefaults.standard.data(forKey: Self.key) ?? Data())
                return decoded
            } catch {
                print(#file, #line, error)
                return Self.default
            }
        }
        nonmutating set {
            do {
                let encoded = try JSONEncoder().encode(newValue)
                UserDefaults.standard.set(encoded, forKey: Self.key)
            } catch {
                print(#file, #line, error)
            }
        }
    }
}

extension Config {
    /// ライブ変換を有効化する設定
    struct Learning: CustomCodableConfigItem {
        enum Value: String, Codable, Equatable, Hashable {
            case inputAndOutput
            case onlyOutput
            case nothing

            var learningType: LearningType {
                switch self {
                case .inputAndOutput:
                    .inputAndOutput
                case .onlyOutput:
                    .onlyOutput
                case .nothing:
                    .nothing
                }
            }
        }
        static var `default`: Value = .inputAndOutput
        static var key: String = "dev.ensan.inputmethod.azooKeyMac.preference.learning"
    }
}
