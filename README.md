# tmp-wpe-kms

WPE WebKit 2.54+ の **WPEPlatform DRM/KMS** を使い、X11/Waylandなしで画面へ描画する実験。

- [ビルド・検証ダッシュボード (GitHub Pages)](https://2rwa.github.io/tmp-wpe-kms/)
- [Actions](https://github.com/2rwa/tmp-wpe-kms/actions)
- [実装と実機試験手順](docs/BUILD.md)
- [Debian公式ビルド定義との比較](docs/DEBIAN_BUILD_REVIEW.md)
- [Ubuntu 24.04向けソースビルド](docs/NOBLE.md)
- **[Core2リモートブラウザ実機レポート：LCD・キーボード・QR・メモリ](docs/CORE2_REMOTE_BROWSER.md)**

## 実験の位置づけ

`src/main.c` は WPEPlatform API 2.0 の小さなCランチャーです。
通常起動では `WPE_PLATFORM=drm` でローカルモニターへ直接出力します。
CIでは `WPE_PLATFORM=headless` で実際にWebKitを起動し、DOM・JavaScriptの状態遷移を検証します。
両方式ともX11/Waylandサーバーは必要ありません。

**2026-10-16 時点:** Ubuntu 24.04向けにWPE 2.54.1をソースビルドし、Core2実機でのDRM/KMS表示、物理キーボード入力、スマホからのURL切替を確認済みです。QR接続・スマホ入力の試作もビルド・Core2ジョブまで通過しました。重い動画サイトや日本語IMEは未検証です。詳細は [Core2リモートブラウザ実機レポート](docs/CORE2_REMOTE_BROWSER.md) を参照してください。

通常のCIではDebian sidパッケージ版WPEでheadlessテストを実施し、Core2用ランタイムは別のUbuntu 24.04 Actionsでビルドします。OS間バイナリの互換性を前提にしないでください。
