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

# ---------------------------------------------------------------------------
# Extra LuCI themes (not in the ImmortalWrt feed), pinned commits.
# ---------------------------------------------------------------------------
prepare_themes() {
    local src=/build/themes-src pkg=/build/repo/package/themes
    mkdir -p "$src" "$pkg"

    fetch_theme() { # name repo sha
        local name=$1 repo=$2 sha=$3
        if [ ! -d "$src/$name" ]; then
            echo "== theme: $name ($sha) =="
            mkdir -p "$src/.tmp-$name"
            curl -fsSL "https://codeload.github.com/$repo/tar.gz/$sha" \
                | tar -xz -C "$src/.tmp-$name"
            mv "$src/.tmp-$name"/* "$src/$name"
            rmdir "$src/.tmp-$name"
        fi
    }

    fetch_theme glass   rchen14b/luci-theme-glass      68e26dc41c254e68f37f184ebe64a9925da7d539
    fetch_theme liquid  zzsj0928/luci-theme-liquid     5bbe31e2a3e158750cd472aac3dcef39a54045de
    fetch_theme fluent  LazuliKao/luci-theme-fluent    e19720d8b9fc7ddc7ba32cb6c7375c04c366b1f2
    fetch_theme vantage anothaDev/luci-theme-vantage   8d1a8d2c959a3cd7561dfc76c2a7d345e441ee85

    rm -rf "$pkg/luci-theme-glass" "$pkg/luci-theme-liquid" \
           "$pkg/luci-theme-fluent" "$pkg/luci-theme-vantage" \
           "$pkg/luci-app-vantage"
    cp -a "$src/glass"   "$pkg/luci-theme-glass"
    cp -a "$src/liquid"  "$pkg/luci-theme-liquid"
    cp -a "$src/fluent/package/luci-theme-fluent" "$pkg/luci-theme-fluent"
    cp -a "$src/vantage/luci-theme-vantage" "$pkg/luci-theme-vantage"
    cp -a "$src/vantage/luci-app-vantage"   "$pkg/luci-app-vantage"
    find "$pkg" -name .git -prune -exec rm -rf {} + 2>/dev/null || true
}
prepare_themes

# ---------------------------------------------------------------------------
# Restore the extra app set and the themes.  Applied once per volume.
# ---------------------------------------------------------------------------
if [ ! -f /build/.zero2-extras-applied ]; then
    cat /src/zero2-build/configs/extras.fragment >> .config
    touch /build/.zero2-extras-applied
fi
sed -i 's/^CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=2048/' .config

if [ ! -f .config ]; then
    cp /src/zero2-build/configs/zero2.config .config
fi
make defconfig

# Samba4 needs a host perl.  On Ubuntu 24.04 the default PIE link of the
# miniperl globals fails; pre-build host perl with -fno-PIE / -no-pie.
if grep -q '^CONFIG_PACKAGE_samba4-server=y' .config; then
    echo "== host perl (no-pie workaround) =="
    make package/feeds/packages/perl/host/compile -j1 \
        HOST_CFLAGS="-O2 -fno-PIE" HOST_LDFLAGS="-no-pie" \
        2>&1 | tee /build/logs/perl-host.log || true
fi

echo "== make =="
make -j"$(nproc)" 2>&1 | tee /build/logs/build.log

ls -lh bin/targets/sunxi/cortexa53/*.img.gz 2>/dev/null || true