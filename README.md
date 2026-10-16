# tmp-wpe-kms

WPE WebKit 2.54+ の **WPEPlatform DRM/KMS** を使い、X11/Waylandなしで画面へ描画する実験。

- [ビルド・検証ダッシュボード (GitHub Pages)](https://2rwa.github.io/tmp-wpe-kms/)
- [Actions](https://github.com/2rwa/tmp-wpe-kms/actions)
- [実装と実機試験手順](docs/BUILD.md)
- [Debian公式ビルド定義との比較](docs/DEBIAN_BUILD_REVIEW.md)
- [Ubuntu 24.04向けソースビルド](docs/NOBLE.md)

## 実験の位置づけ

`src/main.c` は WPEPlatform API 2.0 の小さなCランチャーです。
通常起動では `WPE_PLATFORM=drm` でローカルモニターへ直接出力します。
CIでは `WPE_PLATFORM=headless` で実際にWebKitを起動し、DOM・JavaScriptの状態遷移を検証します。
両方式ともX11/Waylandサーバーは必要ありません。

**注意:** 通常のCIはDebian sidのパッケージ版WPEでランチャーをビルドし、headlessで実行テストします。
別のActionsジョブでUbuntu 24.04互換のWPEエンジン全体をソースビルドする実験も行っています。
バイナリのOS間互換性、Core2実機でのWPEによるDRM/KMS直接出力はまだ未検証です。
