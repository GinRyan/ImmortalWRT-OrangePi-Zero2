#!/usr/bin/env bash
# Build the target, kernel, kmod-uwe5622 and the package set from the source
# tree.  This is the one-off (or driver-patch-change) step; it is incremental.
set -euo pipefail

export FORCE_UNSAFE_CONFIGURE=1
cd /build/repo
mkdir -p /build/logs

if [ ! -d feeds/luci ] || [ ! -d feeds/packages ]; then
    echo "== feeds update =="
    ./scripts/feeds update -a 2>&1 | tee /build/logs/feeds-update.log
    echo "== feeds install =="
    ./scripts/feeds install -a 2>&1 | tee /build/logs/feeds-install.log
fi

if [ ! -f .config ]; then
    cp /src/zero2-build/configs/zero2.config .config
fi
make defconfig

echo "== make -j$(nproc) =="
make -j"$(nproc)" 2>&1 | tee /build/logs/build.log

ls -lh bin/targets/sunxi/cortexa53/*.img.gz 2>/dev/null || true