#!/usr/bin/env bash
# Quick packaging: assemble a flashable image with the ImageBuilder (no source
# compilation).  Override PACKAGES / EXTRA_IMAGE_NAME from the environment.
set -euo pipefail

d=$(ls -d /build/ib/immortalwrt-imagebuilder-* 2>/dev/null | head -n1)
[ -n "$d" ] || { echo "no ImageBuilder in /build/ib; run 20-imagebuilder.sh first" >&2; exit 1; }

PACKAGES="${PACKAGES:-luci luci-i18n-base-zh-cn luci-i18n-firewall-zh-cn luci-app-passwall luci-i18n-passwall-zh-cn easytier-noweb luci-app-easytier}"
EXTRA_IMAGE_NAME="${EXTRA_IMAGE_NAME:-passwall-easytier}"

cd "$d"
make image \
    PROFILE=xunlong_orangepi-zero2 \
    PACKAGES="$PACKAGES" \
    EXTRA_IMAGE_NAME="$EXTRA_IMAGE_NAME" \
    FORCE=1

mkdir -p /out
cp bin/targets/sunxi/cortexa53/*.img.gz /out/
cp bin/targets/sunxi/cortexa53/*.manifest /out/
( cd /out && sha256sum *.img.gz > sha256sums.txt )
ls -lh /out/*.img.gz /out/*.manifest