# Core2 / WPE WebKit 2.54.1 DRM・KMS実機検証

検証日: **2026-10-16**。Core2ノートPCの内蔵LCD（LVDS-1、1280×800）を直接使い、X11/Waylandなしで WPEPlatform DRM バックエンドを動作させる検証。

## 結論

**WPEの実機ランタイム起動・WebKit DOM操作・KMSスキャンアウトのバッファ更新を確認。**

- Ubuntu 24.04向けにソースからビルドした WPE WebKit 2.54.1 のランタイム（圧縮約40MB、展開約160MB）をCore2へ配置。
- Core2実機でheadlessモードのWebKit DOM/JavaScript操作回帰テストに成功。
- WPEを\`WPE_PLATFORM=drm\`で実行し、アニメーションHTMLをローカルWebサーバから読み込み。
- /dev/dri/card1 のCRT CRTC45 / プレーン34の表示用FBが **81（起動前）→82↔80（WPE動作中）** と切り替わった。
- 0.25秒刻みの監視20秒間で **DRM_SCANOUT_CHANGES=51** を計測。
- WPEが終了した後、別のread-only計測でフレームバッファが元の **81** に復帰したことを確認。

**目視確認:** 後続の実機テストで、利用者がWPEによるLCD上のテスト画面（文字・色）を直接確認しました。外部カメラ等による独立した光学的証拠はまだ保存していません。スキャンアウトのログ観測と目視報告は別の証跡です。

## 実機環境

| 項目 | 実測 |
|---|---|
| OS | Ubuntu 24.04.5 LTS / kernel 7.0.0-38-generic |
| CPU | Intel Core 2 Duo T7250 (SSE2/SSSE3) |
| メモリ | 3.8 GiB（2GB制約は未測定） |
| GPU | Intel GM965/GL960, i915 |
| ディスプレイ | LVDS-1: connected 1280×800 / VGA-1: disconnected |
| ドライバ | i915 / Mesa Intel 965GM |
| GLES | OpenGL ES 2.0 / EGL 1.5 |
| デバイス | /dev/dri/card1, /dev/dri/renderD128 |
| root権限 | 不要。ユーザー\`github-runner\`が\`video\`・\`render\`に所属 |
| WPEパス | \`/home/github-runner/wpe-2.54.1\` |
| X11/Wayland | WPEの画面出力には使用しない |

## 動的DRMスキャンアウトの証跡

試験用アニメーションHTMLは数百msごとにカウンターと背景色を変化させ、WebKitからの画面更新を発生させる。
同時に別プロセスからlibdrmの\`drmModeGetCrtc()\`と\`drmModeGetPlane()\`で実際に接続されるバッファIDをサンプリングする。

\`\`\`text
DRM_MONITOR_MASTER_RELEASE=YES errno=0
DRM_SAMPLER_NODE=/dev/dri/card1 DRM_UNIVERSAL_PLANES=YES
DRM_RESOURCE_CRTCS=2 DRM_RESOURCE_PLANES=4

DRM_SCANOUT_STATE t=0.00s CRTC45:fb=81:active=1:1280x800 PLANE34:crtc=45:fb=81
DRM_SCANOUT_STATE t=3.00s CRTC45:fb=82:active=1:1280x800 PLANE34:crtc=45:fb=82
DRM_SCANOUT_STATE t=3.25s CRTC45:fb=80:active=1:1280x800 PLANE34:crtc=45:fb=80
DRM_SCANOUT_STATE t=3.50s CRTC45:fb=82:active=1:1280x800 PLANE34:crtc=45:fb=82
... (繰り返し)
DRM_SCANOUT_CHANGES=51
WEBKIT_DRM_HTTP_REQUEST=CONFIRMED
DRM_SCANOUT_FB_CHANGED=YES (KMS scanout state changed during WPE)
\`\`\`

WPE開始時点での制御権について注意：DRMのプライマリノードを監視用に開くと、そのプロセスがDRM masterを握ってしまい、WPEが\`Failed to become DRM master\`となる場合があった。
修正版では監視プロセスが**明示的に\`drmDropMaster()\`**してから観測する。これによりWPEが表示制御権を取得し、50回を超えるフレームバッファ切替を観測できた。

### 終了後の復帰

終了直後の一時的な\`fb=0\`を観測したので、別ワークフローから画面を変更せず再測定：

\`\`\`text
connector=/sys/class/drm/card1-LVDS-1 status=connected
i915drmfb
DRM_SCANOUT_STATE t=0.00s CRTC45:fb=81:active=1:1280x800 PLANE34:crtc=45:fb=81
DRM_SCANOUT_TOTAL_SAMPLES=24
DRM_SCANOUT_CHANGES=0
\`\`\`

約6秒間安定しており、元のFB 81に復帰した。

## 以前のfbdevテストとの違い

旧試験はheadless ChromiumでHTMLをPNG化し、\`/dev/fb0\`をmmapで直接書き換えて読み戻した。こちらはWPEで描画したものではなかった。

今回の試験は実際にCore2上で動いている **WPE WebKit 2.54.1自身のDRM/KMSバックエンド**が、i915のCRTCとプライマリプレーンのスキャンアウト先を切り替える動作を検証している。

## 実行リンク

- [Ubuntu 24.04用WPEビルド成功](https://github.com/2rwa/tmp-wpe-kms/actions/runs/38885631520)
- [WPE 2.54.1 ランタイムRelease](https://github.com/2rwa/tmp-wpe-kms/releases/tag/core2-noble-wpe-2.54.1)
- [Core2 headless DOM + DRM起動テスト](https://github.com/2rwa/bridge/actions/runs/38866697372)
- [Core2 DRMスキャンアウト更新（51変化）](https://github.com/2rwa/bridge/actions/runs/38899525934)
- [スキャンアウト証跡Artifact](https://github.com/2rwa/bridge/actions/runs/38899525934/artifacts/12044873470)
- [終了後コンソール復帰](https://github.com/2rwa/bridge/actions/runs/38899757249)
- [実機検証用ソース・HTML・監視ワークフロー](https://github.com/2rwa/bridge/tree/core2-wpe-runtime-20261016/scripts/core2)
- [旧fbdev画面メモリ書換試験](https://github.com/2rwa/bridge/actions/runs/38857859998)

## 後続の実機検証（2026-10-16）

試験の詳細・公開できる測定データは [Core2リモートブラウザ実機レポート](CORE2_REMOTE_BROWSER.md) に集約。

- **画面表示:** WPEのHTML表示を実機の内蔵LCDで目視確認（先行試験のスキャンアウト51回とは別の後続検証）。
- **キー入力:** ネイティブlibinput → WebKit → JavaScriptへの経路を確認し、`keydown` 41件、`input` 32件。
- **アクセス権の原因:** libinputは `/dev/input/event*` を `O_RDWR` で開くため、キーボードの読み取り専用ACLでは `EACCES`。対象キーボードに限定した読書きACL後に入力を確認。
- **軽量HTMLメモリ計測:** WPE3プロセス、75秒、PSS最大 **200.5 MiB**、RSS合計最大 **320.0 MiB**、Swap 0 MiB。
- **スマホリモコン:** LANからURL指定、QRトークン認証、CランチャーによるWPEネイティブ入力注入を試作。QR・入力版Actionsのpreflight/build/Core2ジョブ成功。ただしYouTube動画再生や任意サイト操作の完全性は未確認。

公開レポートでは内部LANアドレス、認証コード、ホスト内部構成やログの個人情報を転載していない。

## これから

- 目視確認済みのLCD表示について写真または独立した画素証跡の収集
- 長時間表示・入力デバイス・終了後の復帰の耐久テスト（短時間動作は確認済み）
- 2GBメモリ制約で起動時間、RSS、スワップ、OOM発生有無を調べる
- WebGL無効 / OpenGL ES 2.0の制約に適した描画の安定性を確認

rootでWPEを常駐起動する必要はなく、上記の実機検証は\`github-runner\`一般ユーザーで行った。
