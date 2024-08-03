# azooKey on Desktop

iOSのキーボードアプリ「[azooKey](https://github.com/ensan-hcl/azooKey)」のデスクトップ版です。

**現在アルファ版のため、動作は一切保証できません**。

## 動作環境

macOS 14.3で動作確認しています。古いOSでの動作は検証していません。

## リリース版インストール

[Releases](https://github.com/ensan-hcl/azooKey-Desktop/releases)から`.pkg`ファイルをダウンロードして、インストールしてください。

その後、以下の手順で利用できます。

- macOSからログアウトし、再ログイン
- 「設定」>「キーボード」>「入力ソース」を編集>「+」ボタン>「日本語」>azooKeyを追加>完了
- メニューバーアイコンからazooKeyを選択

## コミュニティ

azooKey on macOSの開発に参加したい方、使い方に質問がある方、要望や不具合報告がある方は、ぜひ[azooKeyのDiscordサーバ](https://discord.gg/dY9gHuyZN5)にご参加ください。

## 機能

* ニューラルかな漢字変換システム「Zenzai」による高精度な変換のサポート
* iOSのキーボードアプリazooKeyと同レベルの日本語入力のサポート
* 英字入力のサポート
* 部分変換のサポート
* ライブ変換のサポート
  * 設定メニューでのライブ変換の切り替え
* 英単語変換のサポート
  * 設定メニューで切り替え
* 学習機能
* インストーラのサポート

## 開発ガイド

コントリビュート歓迎です！！

### 開発版のビルド・デバッグ

cloneする際には`--recursive`をつけてサブモジュールまでローカルに落としてください。

```bash
git clone https://github.com/ensan-hcl/azooKey-Desktop --recursive
```

以下のスクリプトを用いて最新のコードをビルドしてください。`.pkg`によるインストールと同等になります。その後、上記の手順を行ってください。

```bash
./install.sh
```

開発中はazooKeyのプロセスをkillすることで最新版を反映することが出来ます。また、必要に応じて入力ソースからazooKeyを削除して再度追加する、macOSからログアウトして再ログインするなど、リセットが必要になる場合があります。

### トラブルシューティング

`install.sh`でビルドが成功しない場合、以下をご確認ください。

* XcodeのGUI上で「Team ID」を変更する必要がある場合があります
* 「Packages are not supported when using legacy build locations, but the current project has them enabled.」と表示される場合は[https://qiita.com/glassmonkey/items/3e8203900b516878ff2c](https://qiita.com/glassmonkey/items/3e8203900b516878ff2c)を参考に、Xcodeの設定をご確認ください

### pkgファイルの作成
`pkgbuild.sh`によって配布用のdmgファイルを作成できます。`build/azooKeyMac.app` としてDeveloper IDで署名済みの.appを配置してください。

### TODO

* 入力中に自動で変換候補ウィンドウを表示する
* 予測変換を表示する
* CIを増やす
  * アルファ版を自動リリースする
* 機能の拡充
  * ユーザ辞書をサポートする

### Future Direction

* WindowsとLinuxもサポートする
  * @7ka-Hiira さんによる[fcitx5-hazkey](https://github.com/7ka-Hiira/fcitx5-hazkey)もご覧ください

* iOS版のazooKeyと学習や設定を同期する

## Reference

Thanks to authors!!

* https://mzp.hatenablog.com/entry/2017/09/17/220320
* https://www.logcg.com/en/archives/2078.html
* https://stackoverflow.com/questions/27813151/how-to-develop-a-simple-input-method-for-mac-os-x-in-swift
* https://mzp.booth.pm/items/809262
