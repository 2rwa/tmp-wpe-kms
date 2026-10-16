# Ubuntu 24.04 native WPE 2.54 build

This project builds a WPE WebKit **2.54.1 runtime from upstream verified source** on a hosted Ubuntu 24.04 Actions runner, not Debian sid.

- [Build workflow](../.github/workflows/build-wpe-noble.yml)
- [Build script](../scripts/build-noble.sh)
- [Releases](https://github.com/2rwa/tmp-wpe-kms/releases)
- [Core2 device status](CORE2.md)

## Scope

- Target host: Core2 Duo T7250, Intel 965GM, Ubuntu 24.04.5
- Prefix: `/home/github-runner/wpe-2.54.1` (extracted as the `github-runner` user)
- CPU flags: `-march=core2 -mtune=core2`, no SSE4/AVX assumed
- WPEPlatform: DRM + headless enabled, Wayland + legacy API disabled
- Browser controls checked via headless WebKit before publishing a prerelease
- Direct DRM output on the Core2 LCD verified by **51 scanout framebuffer changes**; visual pixel/photographic evidence still pending
- Published tar contains dynamic libraries and WebKit auxiliary processes, not all system libraries

The release is published **only if the real build and headless WebKit test pass**.
Avoid attempting to build a full browser engine on the Core2's 5.5 GB of free storage.
The native binary was later deployed as the unprivileged github-runner user on Core2 and passed the DRM scanout test. See [Core2 results](CORE2.md).
