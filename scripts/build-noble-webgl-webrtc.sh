#!/usr/bin/env bash
# Isolated experimental variant of the known-working Ubuntu 24.04 Core2 build.
# Derives a temporary script; does not edit the original script or release.
set -Eeuo pipefail
cd "${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
original=scripts/build-noble.sh
for required in 'ENABLE_WEBGL=OFF' 'ENABLE_WEB_RTC=OFF' 'ENABLE_MEDIA_STREAM=OFF' 'src/main.c' 'wpe-2.54.1' 'wpe-webkit-2.54.1-ubuntu2404-core2-x86_64.tar.xz'; do
  grep -Fq -- "$required" "$original" || { echo "::error::Unexpected original build script; refusing unsafe transformation: $required"; exit 1; }
done
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
sed \
 -e 's@PREFIX=/home/github-runner/wpe-${VERSION}@PREFIX=/home/github-runner/wpe-${VERSION}-webgl-webrtc@' \
 -e 's@libgstreamer-plugins-bad1.0-dev @libgstreamer-plugins-bad1.0-dev libnice-dev libsrtp2-dev @' \
 -e 's@-DENABLE_WEBGL=OFF -DENABLE_WEB_RTC=OFF @-DENABLE_WEBGL=ON -DENABLE_WEB_RTC=ON -DUSE_GSTREAMER_WEBRTC=ON @' \
 -e 's@-DENABLE_MEDIA_STREAM=OFF@-DENABLE_MEDIA_STREAM=ON@' \
 -e 's@src/main.c -o @src/feature-main.c -o @' \
 -e 's@wpe-2.54.1@wpe-2.54.1-webgl-webrtc@g' \
 -e 's@wpe-webkit-2.54.1-ubuntu2404-core2-x86_64.tar.xz@wpe-webkit-2.54.1-ubuntu2404-core2-webgl-webrtc-x86_64.tar.xz@g' \
 "$original" > "$tmp"
bash -n "$tmp"
for required in '-DENABLE_WEBGL=ON' '-DENABLE_WEB_RTC=ON' '-DUSE_GSTREAMER_WEBRTC=ON' '-DENABLE_MEDIA_STREAM=ON' 'src/feature-main.c' 'wpe-2.54.1-webgl-webrtc'; do
  grep -Fq -- "$required" "$tmp" || { echo "::error::Missing transformed setting $required"; exit 1; }
done
if grep -Eq '\-DENABLE_(WEBGL|WEB_RTC|MEDIA_STREAM)=OFF' "$tmp"; then
  echo "::error::A requested feature remained disabled"
  exit 1
fi
echo "Experimental WebGL/WebRTC build; stable Core2 build and release remain untouched."
bash "$tmp"
