//
//  ConfigWindow.swift
//  azooKeyMac
//
//  Created by miwa on 2024/04/23.
//

import SwiftUI

struct ConfigWindow: View {
    @ConfigState private var liveConversion = Config.LiveConversion()
    @ConfigState private var englishConversion = Config.EnglishConversion()
    @ConfigState private var typeBackSlash = Config.TypeBackSlash()
    @ConfigState private var openAiApiKey = Config.OpenAiApiKey()
    @ConfigState private var learning = Config.Learning()

    var body: some View {
        VStack {
            Text("設定")
                .font(.title)
            Toggle("ライブ変換を有効化", isOn: $liveConversion)
            Toggle("英単語変換を有効化", isOn: $englishConversion)
            Toggle("円記号の代わりにバックスラッシュを入力", isOn: $typeBackSlash)
            TextField("OpenAI API Key", text: $openAiApiKey)
            Picker("学習", selection: $learning) {
                Text("学習する").tag(Config.Learning.Value.inputAndOutput)
                Text("学習を停止").tag(Config.Learning.Value.onlyOutput)
                Text("学習を無視").tag(Config.Learning.Value.nothing)
            }
        }
            .frame(width: 400, height: 300)
    }
}
