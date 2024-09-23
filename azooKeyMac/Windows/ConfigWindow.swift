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
    @ConfigState private var typeCommaAndPeriod = Config.TypeCommaAndPeriod()
    @ConfigState private var zenzai = Config.ZenzaiIntegration()
    @ConfigState private var zenzaiProfile = Config.ZenzaiProfile()
    @ConfigState private var learning = Config.Learning()
    @ConfigState private var inferenceLimit = Config.ZenzaiInferenceLimit()
    @ConfigState private var richCandidates = Config.ZenzaiRichCandidatesMode()
    @ConfigState private var debugWindow = Config.DebugWindow()
    @ConfigState private var userDictionary = Config.UserDictionary()

    @State private var zenzaiHelpPopover = false
    @State private var zenzaiRichCandidatesPopover = false
    @State private var zenzaiProfileHelpPopover = false
    @State private var zenzaiInferenceLimitHelpPopover = false

    @ViewBuilder
    private func helpButton(helpContent: LocalizedStringKey, isPresented: Binding<Bool>) -> some View {
        if #available(macOS 14, *) {
            Button("ヘルプ", systemImage: "questionmark") {
                isPresented.wrappedValue = true
            }
            .labelStyle(.iconOnly)
            .buttonBorderShape(.circle)
            .popover(isPresented: isPresented) {
                Text(helpContent).padding()
            }
        }
    }

    var body: some View {
        VStack {
            Text("azooKey on macOS")
                .bold()
                .font(.title)
            Spacer()
            HStack {
                Spacer()
                ScrollView {
                    Form {

                        Picker("学習", selection: $learning) {
                            Text("学習する").tag(Config.Learning.Value.inputAndOutput)
                            Text("学習を停止").tag(Config.Learning.Value.onlyOutput)
                            Text("学習を無視").tag(Config.Learning.Value.nothing)
                        }
                        Divider()
                        HStack {
                            Toggle("Zenzaiを有効化", isOn: $zenzai)
                            helpButton(helpContent: "Zenzaiはニューラル言語モデルを利用した最新のかな漢字変換システムです。\nMacのGPUを利用して高精度な変換を行います。\n変換エンジンはローカルで動作するため、外部との通信は不要です。", isPresented: $zenzaiHelpPopover)
                        }
                        HStack {
                            Toggle("より多様な候補を提案", isOn: $richCandidates)
                            helpButton(helpContent: "Zenzaiの利用時、複数の多様な候補を提案します。\n候補リストを表示する際に遅延が発生する可能性があります。", isPresented: $zenzaiRichCandidatesPopover)
                        }
                        HStack {
                            TextField("変換プロフィール", text: $zenzaiProfile, prompt: Text("例：田中太郎/高校生"))
                                .disabled(!zenzai.value)
                            helpButton(
                                helpContent: """
                            Zenzaiはあなたのプロフィールを考慮した変換を行うことができます。
                            名前や仕事、趣味などを入力すると、それに合わせた変換が自動で推薦されます。
                            （実験的な機能のため、精度が不十分な場合があります）
                            """,
                                isPresented: $zenzaiProfileHelpPopover
                            )
                        }
                        HStack {
                            TextField(
                                "Zenzaiの推論上限",
                                text: Binding(
                                    get: {
                                        String(self.$inferenceLimit.wrappedValue)
                                    },
                                    set: {
                                        if let value = Int($0), (1 ... 50).contains(value) {
                                            self.$inferenceLimit.wrappedValue = value
                                        }
                                    }
                                )
                            )
                            .disabled(!zenzai.value)
                            Stepper("", value: $inferenceLimit, in: 1 ... 50)
                                .labelsHidden()
                                .disabled(!zenzai.value)
                            helpButton(helpContent: "推論上限を小さくすると、入力中のもたつきが改善されることがあります。", isPresented: $zenzaiInferenceLimitHelpPopover)
                        }
                        Divider()
                        Toggle("ライブ変換を有効化", isOn: $liveConversion)
                        Toggle("英単語変換を有効化", isOn: $englishConversion)
                        Toggle("円記号の代わりにバックスラッシュを入力", isOn: $typeBackSlash)
                        Toggle("「、」「。」の代わりに「，」「．」を入力", isOn: $typeCommaAndPeriod)
                        Divider()
                        Button("ユーザ辞書を編集する") {
                            (NSApplication.shared.delegate as? AppDelegate)!.openUserDictionaryEditorWindow()
                        }
                        Divider()
                        Toggle("（開発者用）デバッグウィンドウを有効化", isOn: $debugWindow)
                    }
                }
                Spacer()
            }
            Spacer()
        }
        .frame(minHeight: 300, maxHeight: 600)
        .frame(minWidth: 400, maxWidth: 600)
    }
}

#Preview {
    ConfigWindow()
}
