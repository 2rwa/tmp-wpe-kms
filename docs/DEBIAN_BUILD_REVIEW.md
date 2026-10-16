# Debian WPE 2.54.1-1 ビルド定義の照合（2026-10-16）

対象：Ubuntu 24.04.5 / Intel Core 2 Duo T7250 / RAM 3.8GiB の実機へ、WPE WebKit 2.54.1 をソースビルドして導入するための比較。

## 比較元

- Debian sid の **wpewebkit 2.54.1-1**（`libwpewebkit-2.0-1` / `libwpewebkit-2.0-dev`）
- `wpewebkit_2.54.1-1.debian.tar.xz` を Debian の配布サーバから取得し、SHA-256を検証。
- `debian/control`、`debian/rules`、`debian/patches/series` をGitHub Actions上で展開。
- [解析済みビルド定義Artifact](https://github.com/2rwa/tmp-wpe-kms/actions/runs/38869552639/artifacts/12032516433)
- [パッケージ情報](https://packages.debian.org/source/unstable/wpewebkit)
- [DebianメンテナのGit](https://salsa.debian.org/webkit-team/webkit/-/tree/wpe/unstable)

## 実際に確認できた点

| 比較 | Debian 2.54.1-1 | ここまでの独自ソースビルド |
| --- | --- | --- |
| C/C++コンパイラ（amd64） | clang / clang++ | GCC |
| Make/CMake | dh + CMake/Ninja | CMake/Ninja |
| `-g1` | デバッグ情報を抑える | 通常のRelease |
| `LDFLAGS` | `-Wl,--reduce-memory-overheads` | 未指定 |
| LTO | `optimize=-lto` | 明示していない |
| Install RPATH | `CMAKE_BUILD_WITH_INSTALL_RPATH=ON` | 未指定 |
| Documentation/Introspection | `nodoc` 条件でOFF | OFF |
| `USE_LIBBACKTRACE` | OFF | OFF |
| CPU最適化 | ビルドアーキ依存 | `-march=core2` |
| WPE / DRM | WPE 2.0パッケージを生成 | WPEPlatform DRMの利用を目的 |

`debian/control` はBuild-Dependsとして44項目を列挙している。
このうち `unifdef`、`libatk-bridge2.0-dev`、`flite1-dev` は以前のCIで露呈した依存関係と一致。

Ubuntu 24.04の標準Actions環境では候補が見つからなかったもの：`libwpe-1.0-dev`、`libwpebackend-fdo-1.0-dev`。
この結果は**その時点のAPTキャッシュで候補がなかった**という意味で、Ubuntu全体で絶対に入手できないという意味ではない。
DebianのBuild-Dependsを無条件でUbuntuにコピーせず、WPE 2.0 + WPEPlatform DRM構成に必要な依存だけを選別する。

Debianのパッチシリーズ：

```text
fix-ftbfs-riscv64.patch
fix-ftbfs-x32.patch
fix-ftbfs-sh4.patch
no-must-tail.patch
```

パッチ名だけでは、Ubuntu amd64ビルドへ必要なものかは断定できない。実際のパッチ内容と適用条件を確認してから判断する。

## 推奨する以後のビルド手順

1. **ビルド定義を基準にする**：Debianの`control`と`rules`から必要な依存・CMakeフラグを抽出する。
2. **Ubuntu 24.04への移植部分を明示する**：clang、`-march=core2`、WPEPlatform DRM、headless、X11/Wayland不使用のターゲット構成。
3. **安価なCMake設定チェックを先行する**：フルコンパイル前に不足パッケージとfeature summaryを検査する。
4. **その後にActionsでビルド**：巨大なWebKit本体はCore2でコンパイルしない。
5. **ランタイムテスト→実機**：headless実行、Core2の共有ライブラリ確認、DRM直接表示。実機の描画成否を単なるCI終了コードと混同しない。

既存の`scripts/build-noble.sh`は独自フラグを多く指定しており、この文書を基に整理する余地がある。Debian sidバイナリをUbuntu 24.04にそのまま移植するのは避ける。
