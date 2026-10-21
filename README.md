# 黒歴史ノート・クロニクル

設定を積み上げ、本物の力にする縦持ちiOSゲームの試作。
右腕・魔眼・詠唱の各3段階を解放し、設定を組み合わせて複合能力を発動する。
会話やあだ名よりも、設定を極める成長ループを優先する。

## 構成

- `Sources/ChronicleCore`：JSONカタログ、解放条件、設定倍率、戦闘、進行。
- `iOS/ChronicleApp.swift`：ノート、スキルの系譜、戦闘、簡易カットイン、端末への自動保存。
- `Tests/ChronicleCoreTests`：解放条件、複合能力、戦闘、報酬、保存形式のテスト。

## Macで実行

Xcode 15以降が必要。共有プロジェクトを同梱しているため、XcodeGenは不要。

```sh
git clone https://github.com/koheisuzuk25252525/Kurorekishi.git
cd Kurorekishi
swift test
open iOS/Chronicle.xcodeproj
```

XcodeでChronicleスキームとiPhoneシミュレータを選び、Run。
コマンドラインで署名なしのビルドを確認する場合：

```sh
cd iOS
xcodebuild -project Chronicle.xcodeproj -scheme Chronicle \
  -sdk iphonesimulator -configuration Debug \
  -derivedDataPath ../DerivedData CODE_SIGNING_ALLOWED=NO build
```

各クラウドタスクは既に隔離されているため、既存のチェックアウトを使い、追加のworktreeは作らない。
LinuxでもSwift 5.9以降があれば`swift test`でロジックを検証できるが、SwiftUIとiOSシミュレータにはMacが必要。

## 試遊手順

1. 初期3点で各ルートの最初の設定を解放する。設定強度と技威力が変わる。
2. 「現実を書き換える」で戦闘へ。技で敵を倒し、記述点を得る。
3. 次の頁で「魔眼開放」を解放。「右腕の包帯」と組み合わせ、複合能力を確認する。
4. 設定を外して倍率と詠唱が戻ることを確認する。
5. 戦闘と解放を繰り返し、黒龍顕現や因果終焉を目指す。
6. アプリを終了・再起動して進行が残ることを確認する。「書き直す」で初期化できる。

## 試作上の仮決め

- 表示名は「設定強度」。基本倍率は`1 + 選択した★合計 × 0.25`、複合倍率は乗算。
- 設定は無制限に併用可能。解放済みの親設定を外しても子設定は使用できる。
- 通常攻撃14、技の基礎威力24、詠唱3回。抑えるは次の技を1.5倍にする（重複しない）。
- 敵HPは65から毎頁20ずつ増加。敗北時は同じ頁で再挑戦、解放済み設定は失わない。
- 初期記述点3、勝利報酬は3＋頁番号。物語・代償・音声・本格的な絵素材は未実装。
- 複合能力が複数成立すると倍率は全て適用し、技表示はカタログ順の最初を採用。

## 検証状況

実装したLinux環境にはSwift/Xcodeがないため、Swiftテスト・iOSビルド・実機試遊は未実行。
JSONの構造、IDの参照整合性、前提条件の循環の有無、成長ループの数値を別途確認。
Macで上記コマンドと試遊手順を実行してから、iOSでの動作確認済みと扱うこと。

## MacとXcodeへの自動反映

更新経路は「Codexで編集 → GitにコミットしてGitHubのmainへpush → Macが取得 → XcodeでRun」。
クラウド内だけの未コミット変更は配信されない。今後Codexへ更新を依頼するときは、
「変更を検証してmainへpushまで」と指定する。

Macで上記のcloneを行い、Xcodeを開いた後、一度だけ実行：

```sh
bash scripts/sync-mac.sh
bash scripts/install-mac-sync.sh
```

ログイン中、60秒ごとにmainを取得する。Xcodeは同じローカルフォルダを開き続ける。
通常はファイルの更新が反映される。プロジェクトの再読み込み確認が出た場合は、ディスク側を読み込む。
実行中のアプリには変更が反映されないため、取得後に停止してCmd+Rで再ビルド・再起動する。
新しいSwiftファイルをiOS側に追加するときは、同梱プロジェクトの参照も更新する。
`project.yml`は参考用で、自動同期時の再生成には使わない。

安全のため、ローカルに未保存の編集がある場合は、まずXcodeで保存する。
保存済みの変更や未追跡ファイルがある場合、main以外の場合、履歴が分岐している場合は同期をスキップする。
reset、強制上書き、自動マージはしない。自動同期中はXcode側で編集せず、編集する場合は先に同期を停止する。
認証が必要なprivateリポジトリでは、Mac側でGitの認証を設定しておく。
トークンをスクリプトに埋め込まない。

```sh
# 状況確認
cat .mac-sync/sync.log
cat .mac-sync/sync-error.log
# 停止
bash scripts/uninstall-mac-sync.sh
```

GitHub ActionsにはSwiftテストとiOSシミュレータ用ビルドを設定。
push後にActionsの結果を確認する。CI成功は実際の画面操作の検証とは別。
