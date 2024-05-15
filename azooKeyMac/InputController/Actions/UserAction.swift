//
//  UserAction.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/05/15.
//

enum UserAction {
    case input(String)
    case delete
    case enter
    case space
    case unknown
    case 英数
    case かな
    case navigation(NavigationDirection)

    enum NavigationDirection {
        case up, down, right, left
    }
}
