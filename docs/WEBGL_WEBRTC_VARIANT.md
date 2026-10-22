# WPE WebKit 2.54.1 feature build (WebGL + experimental WebRTC)

The known-working Core2 build stays untouched. This independent GitHub Actions
profile derives a temporary build script from `scripts/build-noble.sh`, using
the same verified source and Core2-compatible CPU target. The original build
script, installed binaries and Release are not overwritten.

| | Existing | Experimental |
|---|---|---|
| Build | `scripts/build-noble.sh` | `scripts/build-noble-webgl-webrtc.sh` |
| Launcher | `src/main.c` | `src/feature-main.c` |
| Install prefix | `/home/github-runner/wpe-2.54.1` | `/home/github-runner/wpe-2.54.1-webgl-webrtc` |
| Release tag | `core2-noble-wpe-2.54.1` | `core2-noble-wpe-2.54.1-webgl-webrtc-exp` |

The separate workflow enables `ENABLE_WEBGL=ON`, `ENABLE_WEB_RTC=ON`,
`ENABLE_MEDIA_STREAM=ON`, and `USE_GSTREAMER_WEBRTC=ON`. It installs
additional libnice/libsrtp development dependencies, builds and runs the
normal headless DOM smoke test with a modified launcher, and publishes a
distinct prerelease only on success.

The launcher explicitly switches on WebGL, WebRTC and MediaStream using
WebKitSettings and prints WebGL1/WebGL2/RTCPeerConnection detection. These
diagnostics are **not** proof of working GPU WebGL, DataChannel peer-to-peer
connectivity, camera/microphone capture or DRM/KMS output on actual hardware.

The [official WPE FAQ](https://wpewebkit.org/about/faq.html) states that
the GStreamer WebRTC backend in 2.54 is incomplete, unsupported and
experimental. LibWebRTC is unavailable in the official 2.54 tarballs.

Do not extract this experimental archive over the stable installation.
