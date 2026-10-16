#!/usr/bin/env bash
# Inspect Debian's packaged build recipe for the exact upstream WPE version.
set -Eeuo pipefail
version="2.54.1-1"
filename="wpewebkit_$version.debian.tar.xz"
sha256="25f4c349dca8a98932ec69854916dbb81fc6da2a259f6f14369064b5818cf531"
url="https://deb.debian.org/debian/pool/main/w/wpewebkit/$filename"
mkdir -p dist/debian-review
curl -fL --retry 3 --connect-timeout 20 --max-time 180 "$url" -o "$filename"
echo "$sha256  $filename" | sha256sum -c -
tar -xJf "$filename" -C dist/debian-review
test -s dist/debian-review/debian/rules
test -s dist/debian-review/debian/control
echo "=== PACKAGE SOURCE: $url ==="
echo "=== RULES ==="
cat dist/debian-review/debian/rules
echo "=== CONTROL / BUILD-DEPENDS ==="
sed -n '1,190p' dist/debian-review/debian/control
echo "=== PATCH SERIES ==="
if [ -f dist/debian-review/debian/patches/series ]; then cat dist/debian-review/debian/patches/series; fi
echo "=== LOCAL UBUNTU 24.04 DEPENDENCY AVAILABILITY ==="
python3 - <<'PY'
from pathlib import Path
import re
control=Path('dist/debian-review/debian/control').read_text()
fields=[]
for line in control.splitlines():
    if line.startswith('Build-Depends:'):
        fields.append(line.split(':',1)[1].strip())
    elif fields and (line.startswith(' ') or line.startswith('\t')):
        fields.append(line.strip())
    elif fields:
        break
depends=' '.join(fields)
packages=[]
for item in depends.split(','):
    pkg=re.split(r'[\s(\[|<!]',item.strip())[0]
    if pkg and pkg not in packages: packages.append(pkg)
Path('dist/debian-review/build-depends-names.txt').write_text('\n'.join(packages)+'\n')
print('Build-Depends package count:',len(packages))
print('Packages:',', '.join(packages))
PY
while read -r pkg; do
  if [ -z "$pkg" ]; then continue; fi
  candidate=$(apt-cache policy "$pkg" | sed -n 's/^[ ]*Candidate:[ ]*//p' | head -1)
  if [ -z "$candidate" ]; then candidate="not in apt cache"; fi
  printf '%-42s %s\n' "$pkg" "$candidate"
done < dist/debian-review/build-depends-names.txt | tee dist/debian-review/ubuntu2404-candidates.txt
echo "=== IMPORTANT FLAGS & PATCH HINTS ==="
grep -nE 'EXTRA_CMAKE_ARGUMENTS|ENABLE_|USE_|LDFLAGS|CFLAGS|CXXFLAGS|parallel|DEBUG_FISSION|INTERNAL|C_LOOP|SKIA' dist/debian-review/debian/rules | head -140 || true
echo "DEBIAN_PACKAGING_REVIEW_OK"
