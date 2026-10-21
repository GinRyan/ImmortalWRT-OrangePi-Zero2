#!/usr/bin/env bash
# Quick packaging: assemble a flashable image with the ImageBuilder (no source
# compilation).  Override PACKAGES / EXTRA_IMAGE_NAME from the environment.
set -euo pipefail

d=$(ls -d /build/ib/immortalwrt-imagebuilder-* 2>/dev/null | head -n1)
[ -n "$d" ] || { echo "no ImageBuilder in /build/ib; run 20-imagebuilder.sh first" >&2; exit 1; }

DEFAULT_PACKAGES="luci luci-i18n-base-zh-cn luci-i18n-firewall-zh-cn \
luci-app-passwall luci-i18n-passwall-zh-cn easytier-noweb luci-app-easytier \
luci-theme-argon luci-app-argon-config luci-i18n-argon-config-zh-cn \
luci-theme-glass luci-theme-liquid luci-theme-fluent luci-theme-vantage luci-app-vantage \
luci-app-nfs luci-i18n-nfs-zh-cn luci-app-vsftpd luci-i18n-vsftpd-zh-cn \
luci-app-samba4 luci-i18n-samba4-zh-cn luci-app-openclash \
luci-app-zerotier luci-i18n-zerotier-zh-cn luci-app-cloudflared luci-i18n-cloudflared-zh-cn \
luci-app-haproxy-tcp luci-app-mwan3 luci-app-nft-qos luci-app-sqm \
luci-app-wifischedule luci-app-cpulimit luci-app-autoreboot"

PACKAGES="${PACKAGES:-$DEFAULT_PACKAGES}"
EXTRA_IMAGE_NAME="${EXTRA_IMAGE_NAME:-passwall-easytier}"
ROOTFS_PARTSIZE="${ROOTFS_PARTSIZE:-2048}"

# luci / first-boot defaults: Argon is the default theme, the other four are
# installed but selectable from LuCI -> System -> Language and Style.
FILES_DIR=/build/ib-files
rm -rf "$FILES_DIR"
mkdir -p "$FILES_DIR/etc/uci-defaults"
cat >"$FILES_DIR/etc/uci-defaults/99-zero2-default-theme" <<'EOF'
#!/bin/sh
uci -q set luci.main.mediaurlbase='/luci-static/argon'
uci -q commit luci
exit 0
EOF
chmod 0755 "$FILES_DIR/etc/uci-defaults/99-zero2-default-theme"

cd "$d"
make image \
    PROFILE=xunlong_orangepi-zero2 \
    PACKAGES="$PACKAGES" \
    FILES="$FILES_DIR" \
    ROOTFS_PARTSIZE="$ROOTFS_PARTSIZE" \
    EXTRA_IMAGE_NAME="$EXTRA_IMAGE_NAME" \
    FORCE=1

mkdir -p /out
cp bin/targets/sunxi/cortexa53/*.img.gz /out/
cp bin/targets/sunxi/cortexa53/*.manifest /out/
( cd /out && sha256sum *.img.gz > sha256sums.txt )
ls -lh /out/*.img.gz /out/*.manifest