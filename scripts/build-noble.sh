#!/usr/bin/env bash
# Build official WPE WebKit 2.54.1 against Ubuntu 24.04 LTS userspace.
# Target is the unmodified x86_64 Core2 Duo (SSE2/SSSE3, no SSE4).
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
export TZ=Etc/UTC
VERSION=2.54.1
PREFIX=/home/github-runner/wpe-${VERSION}
TARBALL=wpewebkit-${VERSION}.tar.xz
URL=https://wpewebkit.org/releases/${TARBALL}
SHA256=0de8bdfba011f9cd63ba9a9171fa6038dd2c08237894f4082abbb821f29d3fe9
echo "::group::Install build dependencies"
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  build-essential ninja-build cmake pkg-config python3 perl ruby bison flex gperf gettext \
  curl xz-utils ca-certificates file patchelf git lld clang unifdef \
  libglib2.0-dev libharfbuzz-dev libicu-dev libjpeg-dev libpng-dev libwebp-dev \
  libxml2-dev libxslt1-dev libsqlite3-dev libgcrypt20-dev libtasn1-6-dev \
  libepoxy-dev libsoup-3.0-dev libfreetype-dev libfontconfig-dev \
  libdrm-dev libgbm-dev libegl-dev libgles-dev libinput-dev libudev-dev \
  libxkbcommon-dev libsystemd-dev libatk1.0-dev libatspi2.0-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  libgstreamer-plugins-bad1.0-dev libenchant-2-dev libhyphen-dev \
  liblcms2-dev libwoff-dev libgudev-1.0-dev libbrotli-dev \
  libnghttp2-dev libpsl-dev libsecret-1-dev libunwind-dev
echo "::endgroup::"
echo "::group::Download verified official release"
mkdir -p build-area
cd build-area
curl -fL --retry 3 --connect-timeout 20 --max-time 240 "$URL" -o "$TARBALL"
echo "$SHA256  $TARBALL" | sha256sum -c -
tar -xf "$TARBALL"
src=$PWD/wpewebkit-$VERSION
echo "WEBKIT_SOURCE=$src" >> "$GITHUB_ENV"
echo "::endgroup::"
echo "::group::Configure WPEPlatform headless+DRM for old Intel GPU"
# Install path must be identical on the build host and Core2, no root needed.
sudo mkdir -p /home/github-runner
sudo chown "$USER" /home/github-runner
# Explicitly avoid targeting modern x86-64-v2/AVX CPUs.
export CFLAGS="-O2 -march=core2 -mtune=core2"
export CXXFLAGS="-O2 -march=core2 -mtune=core2"
# Minimise memory, disk and GPU driver requirements.
cmake -S "$src" -B build -GNinja \
 -DPORT=WPE -DCMAKE_BUILD_TYPE=Release \
 -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_INSTALL_LIBDIR=lib/x86_64-linux-gnu \
 -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
 -DENABLE_WPE_PLATFORM=ON -DENABLE_WPE_PLATFORM_DRM=ON \
 -DENABLE_WPE_PLATFORM_HEADLESS=ON -DENABLE_WPE_PLATFORM_WAYLAND=OFF \
 -DENABLE_WPE_LEGACY_API=OFF \
 -DENABLE_INTROSPECTION=OFF -DENABLE_DOCUMENTATION=OFF \
 -DENABLE_WEBGL=OFF -DENABLE_WEB_RTC=OFF -DENABLE_GAMEPAD=OFF \
 -DENABLE_SPELLCHECK=OFF -DENABLE_JOURNALD_LOG=OFF \
 -DENABLE_MEDIA_STREAM=OFF -DENABLE_SPEECH_SYNTHESIS=OFF -DENABLE_WEBDRIVER=OFF \
 -DENABLE_BUBBLEWRAP_SANDBOX=OFF \
 -DUSE_FLITE=OFF -DUSE_ATK=OFF -DUSE_LIBBACKTRACE=OFF \
 -DUSE_WOFF2=OFF -DUSE_AVIF=OFF -DUSE_JPEGXL=OFF \
 -DUSE_LIBHYPHEN=OFF -DUSE_LCMS=OFF
echo "::endgroup::"
echo "::group::Build on hosted runner, never on Core2"
# Build only 2 parallel compilations to avoid memory pressure and OOM.
cmake --build build --parallel 2
echo "::endgroup::"
echo "::group::Install and build launcher"
cmake --install build
export PKG_CONFIG_PATH="$PREFIX/lib/x86_64-linux-gnu/pkgconfig:$PREFIX/lib/pkgconfig"
export LD_LIBRARY_PATH="$PREFIX/lib/x86_64-linux-gnu:$PREFIX/lib"
pkg-config --modversion wpe-webkit-2.0
cd "$GITHUB_WORKSPACE"
mkdir -p "$PREFIX/bin"
cc -std=c11 -O2 -march=core2 -Wall -Wextra -Werror \
 src/main.c -o "$PREFIX/bin/wpe-kms-launcher" \
 $(pkg-config --cflags --libs wpe-webkit-2.0 wpe-platform-2.0)
# Preserve exact link/build metadata, useful for Core2 runtime triage.
ldd "$PREFIX/bin/wpe-kms-launcher" > "$PREFIX/linkage.txt"
cat "$PREFIX/linkage.txt"
cat > "$PREFIX/launch" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export WPE_PLATFORM="${WPE_PLATFORM:-drm}"
export LD_LIBRARY_PATH="/home/github-runner/wpe-2.54.1/lib/x86_64-linux-gnu:/home/github-runner/wpe-2.54.1/lib:${LD_LIBRARY_PATH:-}"
exec /home/github-runner/wpe-2.54.1/bin/wpe-kms-launcher "$@"
EOF
chmod 755 "$PREFIX/launch"
echo "$VERSION" > "$PREFIX/VERSION"
echo "::endgroup::"
echo "::group::Smoke actual WebKit headless with DOM + interactions"
python3 -m http.server 8766 --directory docs >/tmp/wpe-http.log 2>&1 &
server=$!
trap 'kill "$server" 2>/dev/null || true' EXIT
sleep 2
export WPE_PLATFORM=headless
export WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1
export LIBGL_ALWAYS_SOFTWARE=1
export EGL_PLATFORM=surfaceless
timeout 90s "$PREFIX/launch" --test http://127.0.0.1:8766/
echo "::endgroup::"
echo "::group::Pack relocatability-constrained Ubuntu Noble build"
mkdir -p "$GITHUB_WORKSPACE/dist"
tar -C /home/github-runner -caf "$GITHUB_WORKSPACE/dist/wpe-webkit-2.54.1-ubuntu2404-core2-x86_64.tar.xz" wpe-2.54.1
(cd "$GITHUB_WORKSPACE/dist" && sha256sum *.tar.xz | tee SHA256SUMS)
du -sh "$PREFIX" "$GITHUB_WORKSPACE/dist/"
echo "::endgroup::"
