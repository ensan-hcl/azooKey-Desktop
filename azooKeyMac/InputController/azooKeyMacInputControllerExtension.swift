//
//  azooKeyMacInputControllerExtension.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/05/12.
//

import Foundation
import InputMethodKit

extension azooKeyMacInputController {
    func isPrintable(_ text: String) -> Bool {
        let printable: CharacterSet = [.alphanumerics, .symbols, .punctuationCharacters]
            .reduce(into: CharacterSet()) {
                $0.formUnion($1)
            }
        return CharacterSet(text.unicodeScalars).isSubset(of: printable)
    }
}
