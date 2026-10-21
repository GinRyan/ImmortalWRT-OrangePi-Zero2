#!/usr/bin/env bash
# Sync the source tree into the persistent build volume and normalise line
# endings.  Build artifacts (bin/, build_dir/, staging_dir/, feeds/, dl/) and
# the build .config are preserved in the volume.
set -euo pipefail

SRC="${SRC:-/src}"
BUILD="${BUILD:-/build/repo}"

mkdir -p "$BUILD"

rsync -a --delete \
    --exclude=bin \
    --exclude=build_dir \
    --exclude=staging_dir \
    --exclude=tmp \
    --exclude=dl \
    --exclude=logs \
    --exclude=feeds \
    --exclude=.config \
    --exclude=.config.old \
    --exclude=.git \
    --exclude=images \
    --exclude=work \
    --exclude=packages \
    --exclude=zero2-build \
    "$SRC"/ "$BUILD"/

# exFAT/NTFS checkouts may contain CRLF; the OpenWrt build needs LF.
python3 - "$BUILD" <<'PY'
import os, subprocess, sys
repo = sys.argv[1]
os.chdir(repo)
try:
    files = subprocess.check_output(["git", "ls-files", "-z"]).split(b"\0")
except Exception:
    files = []
changed = 0
for f in files:
    if not f:
        continue
    p = f.decode("utf-8")
    if not os.path.isfile(p):
        continue
    with open(p, "rb") as fh:
        data = fh.read()
    if b"\r\n" not in data or b"\x00" in data[:8192]:
        continue
    new = data.replace(b"\r\n", b"\n")
    if new != data:
        with open(p, "wb") as fh:
            fh.write(new)
        changed += 1
print(f"sync: converted CRLF -> LF in {changed} files")
PY

# First run: seed the known-good configuration (ccache + passwall + IB).
if [ ! -f "$BUILD/.config" ]; then
    cp "$SRC/zero2-build/configs/zero2.config" "$BUILD/.config"
    echo "sync: seeded $BUILD/.config from zero2-build/configs/zero2.config"
fi

echo "sync: done -> $BUILD"