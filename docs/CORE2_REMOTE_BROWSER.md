# Core2 WPE WebKit DRM/KMS ブラウザ実機レポート

**2026-10-16 時点 / 公開用の技術情報のみ。**

この実験は、古い x86 ノートPCを **X11・Wayland・デスクトップ環境なし**のWeb表示端末として使用するものです。WPE WebKit 2.54.1 の WPEPlatform DRM バックエンドで内蔵LCDに表示し、キーボードとスマートフォンのブラウザから操作できるところまで検証しました。一般向けの完成済みLinuxディストリビューションや製品ではありません。

## 要点

- **画面表示成功:** WPE WebKitがCore2の内蔵LCD（LVDS、1280×800）をDRM/KMSで直接駆動。テスト画面の色・文字は実機を見て確認済み。KMSのスキャンアウト変更は別途ログで測定。
- **物理キーボード入力成功:** libinput経由の入力がJavaScriptの `keydown` / `input` に到達し、41件 / 32件をイベント数ログで確認。
- **スマホからURL切替成功:** LAN内の専用ページからHTTPSの外部ページに遷移する試験を実施。
- **スマホリモコンの試験版を実装:** QR接続、トラックパッド風操作、クリック、スクロール、ASCIIの文字・操作キー送信。WPEの公開APIに直接入力イベントを渡す。QRリモコン版のActionsはビルド・Core2起動とも成功。すべての実Webサイトでのクリック・動画操作の互換性は未確認。
- **WPE音声再生成功:** WPE WebKitのHTML5 Audioで出力先を一時ALSA設定（カード0・デバイス0）に切り替え、実機利用者がスピーカーからの音を確認（2026-10-17）。元のRunner環境ではPulseAudio接続拒否／ALSA defaultへの接続失敗があり、ブラウザ内部で再生が進んでも無音だった。WPE再ビルドなしで解消。YouTubeの動画・音声再生性能は未検証。
- **軽量HTMLで安定:** 75秒間、WPE関連3プロセスの最大PSS **200.5 MiB**、最大RSS単純合計 **320.0 MiB**、Swap使用 **0 MiB**。これは**軽量ページ**の値であり、YouTube等の重いページや長時間運用を代表しません。

## 実機とビルド

| 項目 | 検証環境 |
| --- | --- |
| OS | Ubuntu 24.04.5 LTS |
| CPU | Intel Core 2 Duo T7250 |
| RAM | 3.8 GiB（2 GiB制限での試験は未実施） |
| GPU | Intel GM965/GL960 / i915 / GLES 2.0 |
| 内蔵LCD | 1280×800 / LVDS |
| エンジン | WPE WebKit 2.54.1 |
| 描画経路 | WPEPlatform DRM → GBM/EGL/GLES → DRM/KMS → 内蔵LCD |
| コンポジタ | X11、Waylandとも不要 |
| ビルド | GitHub Actions Ubuntu 24.04、`-march=core2 -mtune=core2` |
| 主要設定 | DRM・headless有効、Wayland・WebGL・WebRTC無効 |
| バイナリ | WPEランタイムは約160MB展開、共有ライブラリ等はOS依存 |

WPE本体はGitHub Actionsでソースビルドし、[WPE 2.54.1 Core2 release](https://github.com/2rwa/tmp-wpe-kms/releases/tag/core2-noble-wpe-2.54.1) として配布。ネイティブリモコン入力のCランチャー**だけ**を既存のWPEライブラリにリンクして別途ビルドしています。動画対応に必要なGStreamerプラグインはOS側のパッケージ／コーデック状況に依存します。

## 構成図

```text
Core2 Linux (X11/Waylandなし)
  WPE WebKit 2.54.1
    WPEPlatform DRM → i915 KMS → 内蔵LCD
    ↑
    ├── 物理キーボード → evdev → libinput
    └── Cランチャー → WPEView にネイティブ入力イベント
                         ↑  0600のローカルUnixソケット
LAN上のスマホ → QR接続 → 認証付きHTTPリモコン → Pythonブリッジ
                                 ├── URLナビゲーション
                                 ├── マウス移動 / 左・右クリック / スクロール
                                 └── キー操作 / ASCII文字
```

Cランチャーが `wpe_view_event()`、`wpe_event_pointer_move_new()`、`wpe_event_pointer_button_new()`、`wpe_event_scroll_new()`、`wpe_event_keyboard_new()` を使用。任意のWebページにDOMの `dispatchEvent` を送信する方式ではありません。

スマホ側は**専用アプリ不要**で、通常のブラウザから操作します。QRコードに一時トークンをURLフラグメントとして付け、ページ側で取り込んでフラグメントを消去します。試験版はLAN内限定・有効時間10分で、URL切替時はWPEプロセスを再起動します。

## 計測結果と証跡

| 試験 | 確認事項 | 証跡 |
| --- | --- | --- |
| WPE 2.54.1のソースビルド | Core2対応リリース作成 | [Actions](https://github.com/2rwa/tmp-wpe-kms/actions/runs/38885631520) |
| DRM/KMSスキャンアウト | 画面バッファ切替51回・終了後復帰 | [実機走行](https://github.com/2rwa/bridge/actions/runs/38899525934) / [終了後](https://github.com/2rwa/bridge/actions/runs/38899757249) |
| LCDの目視 | 実機画面表示を利用者が確認 | 目視報告。写真など独立した光学的証跡は未保存 |
| キーボード | `keydown=41`、`input=32` | [実機操作](https://github.com/2rwa/bridge/actions/runs/38901244234) |
| evdev生入力 | 押下38・解放38 | [単体テスト](https://github.com/2rwa/bridge/actions/runs/38905889914) |
| libinputの権限診断 | 読取ACLのみでは `O_RDWR` がEACCES、ACL変更後にWPE入力成功 | [libinput試験](https://github.com/2rwa/bridge/actions/runs/38906555297) |
| メモリ | 3プロセス、最大PSS 200.5MiB、最大RSS計320.0MiB、Swap 0MiB | [75秒計測](https://github.com/2rwa/bridge/actions/runs/38908458229) |
| URLリモコン | WPEをLANから外部HTTPS URLへ切替 | [実機試験](https://github.com/2rwa/bridge/actions/runs/38909984079) |
| QR＋スマホ入力版 | 事前検証・Cランチャービルド・Core2上で10分間のジョブ成功 | [実機試験](https://github.com/2rwa/bridge/actions/runs/38915150110) |
| WPE HTML5 Audio音声経路 | 一時ALSA設定で実機再生ポインタの進行を確認し、後続のスマホリモコン修正版で利用者が実音を確認 | [音声経路実機診断](https://github.com/2rwa/bridge/actions/runs/38927674995) / [音声対応QRリモコン](https://github.com/2rwa/bridge/actions/runs/38928072305) |

**PSSとRSSについて:** PSSは共有メモリをプロセス間で按分した目安、RSSを単純合計すると共有ページが重複します。今回の値はシステム全体のピーク消費量でも2GiB環境での保証値でもありません。

## 実装と再現の入口

- [WPEビルドスクリプト](../scripts/build-noble.sh)
- [Ubuntu 24.04ビルド解説](NOBLE.md)、[実機DRM検証の詳細](CORE2.md)
- [最小WPEランチャー](../src/main.c)
- [スマホリモコンの実装・操作説明（bridge）](https://github.com/2rwa/bridge/blob/core2-wpe-runtime-20261016/docs/core2-wpe-smartphone-remote.md)
- [WPE入力Cランチャー（bridge）](https://github.com/2rwa/bridge/blob/core2-wpe-runtime-20261016/scripts/core2/wpe-remote-launcher.c)
- [認証付きHTTP/QRリモコン（bridge）](https://github.com/2rwa/bridge/blob/core2-wpe-runtime-20261016/scripts/core2/wpe-lan-remote.py)
- [Actions: QR入力ランチャーのビルド・実機試験](https://github.com/2rwa/bridge/blob/core2-wpe-runtime-20261016/.github/workflows/core2-wpe-smartphone-remote.yml)
- QR生成は [Nayuki QR Code generator](https://github.com/nayuki/QR-Code-generator) のMITライセンス実装を利用。

### 実装上の注意

- `/dev/input` の物理キーボードをlibinputから使用するとき、読み取り権限だけでは失敗する場合があります。libinputは `O_RDWR` で開くため、最小のデバイス範囲で権限を検討します。USB・内蔵キーを含めデバイス番号は環境ごとに異なります。権限の恒久化は未実施。
- DRM masterの検査プロセスが画面制御権を占有するとWPEと競合する場合があります。監視時に `drmDropMaster()` が必要でした。
- 古いi915ではハードウェアカーソルが出ない可能性があるため、試験版は非インタラクティブなポインタ表示をHTMLにも追加します。
- HTTPSサイトをWPEで**閲覧できること**と、**リモコン通信自体がHTTPSで保護されていること**は別です。現在の試験リモコンはLAN上のHTTPです。
- 現状の検証ランチャーには、WebKitサンドボックスを無効化する設定を使うものがあります。**信頼できないページを閲覧する一般向けの安全なブラウザとして公開運用しないでください。**
- ローカルLANアドレス、内部ホスト名、アクセスコード、QRに含む秘密値、資格情報、実機由来の生ログ等を本レポートには掲載していません。

## 未確認・今後の課題

1. **YouTubeの動画再生:** ページへの遷移は実行済み。動画の選択、実映像、音声、FPS、CPU負荷はまだ実測していません。WebGLはビルド時に無効であり、GStreamerのデコーダー構成も要確認。
2. **スマホ操作の互換性:** QR接続や入力コードのテストは通過。サイトごとのクリック・キーボード挙動、フォーカス、ポインタ位置の操作性を継続確認する必要があります。
3. **日本語IME:** WPEPlatform DRMの標準入力メソッド連携は未実装のため、Fcitx/Mozcを入れるだけでは動作しません。WASM日本語IMEまたはアプリ側の確定文字列注入を別途検討。
4. **2 GiB実機制限:** 現状の計測は3.8GiB搭載機での軽量ページのみ。
5. **本番用リモコン:** HTTPS化、認証と利用者管理、セッション維持、URL切替時にWebKitを再起動しない方式、アクセシビリティと入力安全性の改善。
6. **長時間耐久試験:** OOM、スワップ、画面の復帰、メディア再生の安定性。

関連する研究用途の試作であり、オフィシャルなWPE WebKit製品・ディストリビューションを意味しません。
