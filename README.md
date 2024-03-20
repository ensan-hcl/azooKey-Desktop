# azooKey on Desktop

iOSのキーボードアプリ「azooKey」のデスクトップ版です。

現在アルファ版のため、動作は一切保証できません。

## 動作環境

macOS 14.3で動作確認しています。

## インストール

現在アルファ版のため、インストーラ等はありません。

以下のコマンドでビルドしてください。

```bash
git clone https://github.com/ensan-hcl/azooKey-Desktop
cd azooKey-Desktop
xcodebuild -project azooKeyMac.xcodeproj -scheme azooKeyMac -configuration Release
```

出来上がった`.app`を`/Library/Input\ Methods`に配置して、macOSからログアウトし、再ログインしてください。

## 開発ガイド

コントリビュート歓迎です！！

### TODO

* 入力モードの整備（英数キーと仮名キーでモード切り替え可能にする）
* 変換範囲のエディットを可能にする
* 変換候補ウィンドウが再前面に表示されないことがある問題を修正する
* インストーラのCIを実装する
* 学習機能を有効化する
* 予測変換を表示する
* ライブ変換をサポートする
* 設定メニューを作る

### Future Direction

* WindowsとLinuxもサポートする

## Reference

Thanks to authors!!

* https://mzp.hatenablog.com/entry/2017/09/17/220320
* https://www.logcg.com/en/archives/2078.html
* https://stackoverflow.com/questions/27813151/how-to-develop-a-simple-input-method-for-mac-os-x-in-swift
* https://mzp.booth.pm/items/809262
