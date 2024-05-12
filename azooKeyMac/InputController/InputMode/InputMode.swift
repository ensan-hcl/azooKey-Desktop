//
//  InputMode.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/05/12.
//

import Foundation
import AppKit

protocol InputMode {
    func handle(_ event: NSEvent!) -> Bool
}
