# Core2 画面表示・GPU 実機検証（2026-10-16）

## 結論

**成功: Core2のi915フレームバッファへHTML由来の画像を書き込み、読み戻し、元の画面メモリへ復元。**

**未実施: WPE WebKitが直接DRM/KMSへ描画するランチャーの稼働。**

WPE WebKit 2.54.1は、別のDebian sid CIランナーでネイティブビルドとheadless DOM/JavaScript回帰テストに成功している。Core2上にはWPEPlatform 2.0がインストールされていないため、混同して「WPE実機描画成功」としない。

## Core2の実測環境

| 項目 | 実測 |
|---|---|
| OS | Ubuntu 24.04.5 LTS / kernel 7.0.0-38 |
| CPU | Intel Core 2 Duo T7250 |
| RAM | 3.8GiB (2GB環境の性能測定ではない) |
| GPU | Intel Mobile GM965/GL960 8086:2a02, i915 |
| 画面 | LVDS-1 1280×800 connected、VGA-1 disconnected |
| fbdev | /dev/fb0、i915drmfb、1280×800、32bpp、stride 5120 |
| DRM | /dev/dri/card1、/dev/dri/renderD128 |
| Mesa EGL | 1.5 |
| GLES | OpenGL ES 2.0 Mesa 25.2.8 |
| Renderer | Mesa Intel(R) 965GM (CL) |
| WPE 2.0 | 未導入 |

## 実表示実験の方式

1. Core2に既存のPlaywright Chromium 153でHTMLをレンダリング（headlessなのでX11/Wayland不要）。
2. 1280×800 PNGを保存。
3. mmapにより、/dev/fb0の画面メモリを全退避。
4. PNGのピクセルを32bit RGBレイアウトへ変換し、フレームバッファへ書き込み。
5. メモリを読み戻して比較。5秒後に元の画面メモリを復元。
6. libdrmで一時的なdrmSetMaster/drmDropMasterも成功。

重要: 読み戻し成功は「画面メモリの書き換え」を証明するが、LCDの肉眼での表示確認はまだできていない。KMS mode変更は行っていない。

主なログ:

```text
BACKUP_OK; rendering screenshot into i915 framebuffer without modeset
FRAMEBUFFER_READBACK=PASS
DISPLAY_TEST_VISIBLE_FOR_5_SECONDS
FRAMEBUFFER_RESTORED=PASS
DRM_MASTER_ACQUIRED=YES
DRM_MASTER_RELEASED
```

## GitHub Actions実行

- [実機表示実験と全ログ](https://github.com/2rwa/bridge/actions/runs/38857859998)
- [分離ブランチの診断スクリプト](https://github.com/2rwa/bridge/tree/core2-wpe-audit-20261016/scripts/core2)
- [既存WPE 2.54.1 CI検証](https://github.com/2rwa/tmp-wpe-kms/actions/runs/38855991787)

## root/render/DRM権限

```text
/etc/group render: github-runner が登録済み
Actionsサービス内 id: github-runner / audio / video / users
render group: 実行中のランナープロセスへは未反映
/dev/dri/card1: アクセス可能
/dev/dri/renderD128: 現状のサービスプロセスからアクセス不可
drmSetMaster(card1): 成功
```

グループ変更を反映するにはサービスの再起動などが必要。ただし、現在のvideoグループだけでGBM、DRM masterおよびfbdev表示が通っているため、今回の検証ではランナーサービスの再起動は行っていない。

## WPE 直接表示までの残り

- Ubuntu 24.04互換の WPE WebKit 2.54+ runtime（WPEPlatform DRMバックエンドを含む）を構築・配置。
- 対応するランチャーをCore2上で実行し、GBM/EGLによる直接出力とHTML描画を検証。
- 入力イベント、セッション/DRM master競合を検証。
- 2GB制限時のRAM消費と安定動作を測定。

### 重要な区別

今回表示したのは **Chromiumが生成したHTMLの画像をfbdevへコピーした結果**。WPEエンジン自体の実機描画ではなく、その前段となるi915画面出力・GPUの準備確認である。
