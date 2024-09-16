//
//  ConfigItem.swift
//  azooKeyMac
//
//  Created by miwa on 2024/04/27.
//

import Foundation
import SwiftUI

/// namespace for `Config`
enum Config {}

protocol ConfigItem<Value>: Sendable {
    static var key: String { get }
    associatedtype Value: Codable, Sendable
    var value: Value { get nonmutating set }
}

/// Wrapper of `State` for SwiftUI. By using this wrapper, you can update config and immediately get the view update.
@propertyWrapper
struct ConfigState<Item: ConfigItem>: DynamicProperty {
    @State private var underlyingState: Item.Value

    init(wrappedValue: Item) {
        self._underlyingState = .init(initialValue: wrappedValue.value)
        self.wrappedValue = wrappedValue
    }

    var wrappedValue: Item
    var projectedValue: Binding<Item.Value> {
        Binding(
            get: {
                self.underlyingState
            },
            set: {
                self.underlyingState = $0
                self.wrappedValue.value = $0
            }
        )
    }
}
