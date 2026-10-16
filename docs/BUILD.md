# ビルド・回帰テスト・実機確認

## 実装範囲

- ソース: `src/main.c`（WPEPlatform 2.0 + WebKitWebView）
- バージョン: WPE WebKit 2.54以降
- 方式: DRM/KMS（`WPE_PLATFORM=drm`）、headless（`WPE_PLATFORM=headless`）
- `/dev/fb0` への mmap 描画ではなく `/dev/dri/card*` の DRM/KMS を使用
- Wayland / X11 / ウィンドウマネージャー不要
- CI: Debian sid の WPE エンジンパッケージでランチャーをビルド・実行
- Pages: ドキュメントとUI設定プレビュー、Actionsの結果

**区別すること:** ここでビルドするのはWPE WebKit *を使うランチャー*であり、WebKitエンジン本体のソースビルドではありません。Debian sidで作ったバイナリは、Ubuntu Serverへコピーしてもglibc/依存ライブラリの不一致で起動しないことがあります。Ubuntuでは対応するWPE 2.54+の開発環境で再ビルドしてください。

## CI検証内容

1. `node --check docs/app.js`、HTMLの構造チェック
2. PlaywrightのChromiumで実際にボタン→状態反映→DOM再描画を検証
3. `pkg-config` による WPE2.0、DRM、headless バックエンド検出
4. `make` でgccネイティブビルド、`ldd` でリンク情報確認
5. 実際のWPE WebKitを `WPE_PLATFORM=headless` で起動してHTMLをロード、JS操作と表示値を再検証
6. GitHub Pagesへビルド対象とActions結果を公開

## Ubuntu Server 実機

```sh
sudo apt-get update
sudo apt-get install -y build-essential pkg-config libwpewebkit-2.0-dev
pkg-config --modversion wpe-webkit-2.0
pkg-config --exists wpe-platform-drm-2.0 && echo "DRM available"
ls -la /dev/dri
lspci -nnk | grep -A4 -Ei 'VGA|Display|3D'
make
python3 -m http.server 8080 --directory docs &
WPE_PLATFORM=drm ./dist/wpe-kms-launcher http://127.0.0.1:8080/
```

**注意**: 実機で `libwpewebkit-2.0-dev` が見つからない場合、OSのリポジトリではWPE 2.54+の準備が必要です。古いWPE 2.4x等に対してはコンパイルできない場合があります。SSH管理端末の物理GPU・モニターが必要です。リモートSSHセッションから直接DRMを開くには権限・seatアクセスに注意してください。まずローカルTTYから動作確認を推奨します。GPUがDRM/KMSを提供してもEGL/GBMが非対応なら画面表示できません。

## RAM 2GBでの注意

- WPEは複数プロセスで動き、動的ページはメモリを消費します。
- 単純なHTML UIは有望ですが、ここでは2GB実機で動作確認していません。
- `free -m`, `ps -eo pid,rss,cmd --sort=-rss | head -20`, `dmesg | grep -i oom` を記録します。
- SSHを維持して画面プログラムを安全に停止できるようにしてください。

## 公式資料

- https://wpewebkit.org/about/faq.html
- https://wpewebkit.org/blog/2026-10-06-wpe-platform.html
- https://wpewebkit.org/about/architecture.html

## 初回CI失敗と恒久対策

初回CIではWPE 2.54.1ランチャーのビルドは成功しましたが、headlessテストで `FAIL: controls missing` が発生。ブラウザUIテストは成功していたため、`file://` スキームで期待したHTMLを取得できない可能性を切り分けました。以後、実運用と同じローカルHTTPサーバを `make check` が起動し、`http://127.0.0.1:8766/` でテストします。さらに `shared-mime-info` を導入します。

WPEのJavaScript評価結果でDOM要素の存在、クリック操作、選択変更、再描画を検証します。ビルド成功だけで合格とはみなしません。


## Core2 実機表示テスト（2026-10-16）

詳細: [CORE2.md](CORE2.md)。Core2上でGBM/EGL/GLES2のコンテキスト生成、DRM master取得・解放が成功。
HTMLをheadless ChromiumでPNGにレンダリングし、i915drmfbの1280x800/32bitメモリに転送。
書き込み前にフレームバッファを退避し、書き込み後のreadbackと5秒後のrestoreが成功した。
これは **WPE WebKitによる直接出力ではない**。WPE本体はCore2にまだインストールされていない。
Core2の表示光学系の視認確認も未実施。


## 2026-10-16 Core2実機WPE/KMSスキャンアウト検証

Ubuntu 24.04互換ランタイムのビルド、Core2への展開、WPE headless回帰、DRM/KMSのスキャンアウト変更51回、および終了後のコンソール復帰が確認できた。現在の状況は[CORE2.md](CORE2.md)を参照。
