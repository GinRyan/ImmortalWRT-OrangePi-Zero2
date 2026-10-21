#!/usr/bin/env bash
# Build the target ImageBuilder from the (already built) source tree, add the
# EasyTier packages and repack a self-contained, unsigned-local-repo IB.
set -euo pipefail

export FORCE_UNSAFE_CONFIGURE=1
cd /build/repo
mkdir -p /build/logs

make target/imagebuilder/compile -j"$(nproc)" CONFIG_IB_STANDALONE=y \
    2>&1 | tee /build/logs/imagebuilder.log

tb=$(ls -t bin/targets/sunxi/cortexa53/*imagebuilder*.tar.zst | head -n1)
echo "imagebuilder: $tb"
mkdir -p /out

rm -rf /build/ib && mkdir -p /build/ib
tar -I zstd -xf "$tb" -C /build/ib
d=$(ls -d /build/ib/*)

# EasyTier ipks (arch rewritten to aarch64_cortex-a53) ship in the repo.
cp /src/zero2-build/easytier/*.ipk "$d/packages/"

# A fresh ImageBuilder has no private signing key; disable the local repo
# signature check, otherwise libc cannot be installed after a fresh extract.
sed -i '/^option check_signature$/d' "$d/repositories.conf"
sed -i 's/^CONFIG_SIGNATURE_CHECK=y/# CONFIG_SIGNATURE_CHECK is not set/' "$d/.config"
rm -f "$d/packages/Packages.sig"
rm -rf "$d"/keys/*
( cd "$d" && make package_index >/dev/null )

# Drop only scratch directories: build_dir/ carries the prebuilt kernel Image
# and the per-target files the image step needs, so it must stay.
( cd "$d" && rm -rf tmp dl logs .profiles.mk )

( cd /build/ib && tar -I 'zstd -T0 -19' -cf \
    /out/immortalwrt-imagebuilder-sunxi-cortexa53-with-easytier.tar.zst \
    "$(basename "$d")" )

cp "$tb" /out/immortalwrt-imagebuilder-sunxi-cortexa53.Linux-x86_64.tar.zst
ls -lh /out/*.zst