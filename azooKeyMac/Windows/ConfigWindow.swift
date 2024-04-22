//
//  ConfigWindow.swift
//  azooKeyMac
//
//  Created by miwa on 2024/04/23.
//

import SwiftUI

struct ConfigWindow: View {
    @State private var toggleBool = false
    @State private var textFieldValue = ""
    @State private var pickerValue = ""
    var body: some View {
        VStack {
            Text("Configs")
                .font(.title)
            Toggle("特に意味のないトグル", isOn: $toggleBool)
            TextField("何かを入力するフィールド", text: $textFieldValue)
            Picker("謎のピッカー", selection: $pickerValue) {
                Text("選択肢1").tag("選択肢1")
                Text("選択肢2").tag("選択肢3")
                Text("選択肢2").tag("選択肢3")
            }
        }
            .frame(width: 400, height: 300)
    }
}
