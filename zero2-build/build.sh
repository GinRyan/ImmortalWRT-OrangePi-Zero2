#!/usr/bin/env bash
# Host-side helper (Linux/macOS/WSL) for the zero2-build stages.
# Usage: ./build.sh [all|sync|build|ib|image|shell]
set -euo pipefail

STAGE="${1:-all}"
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
OUT=${OUT_DIR:-$(cd "$REPO/.." && pwd)/images}
IMAGE=${IMAGE:-opizero2-builder:24.04}
VOLUME=${VOLUME:-opizero2-build}
CONTAINER=${CONTAINER:-opiz2}
PACKAGES=${PACKAGES:-"luci luci-i18n-base-zh-cn luci-i18n-firewall-zh-cn luci-app-passwall luci-i18n-passwall-zh-cn easytier-noweb luci-app-easytier"}
EXTRA_IMAGE_NAME=${EXTRA_IMAGE_NAME:-passwall-easytier}

mkdir -p "$OUT"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    docker build -t "$IMAGE" "$HERE"
fi
docker volume create "$VOLUME" >/dev/null
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$CONTAINER" --hostname opiz2 \
    -v "$REPO:/src" -v "$OUT:/out" -v "$VOLUME:/build" -w /build \
    "$IMAGE" sleep infinity >/dev/null

run() { docker exec "$@"; }
envfile=$(mktemp)
printf 'PACKAGES=%s\nEXTRA_IMAGE_NAME=%s\n' "$PACKAGES" "$EXTRA_IMAGE_NAME" >"$envfile"
trap 'rm -f "$envfile"' EXIT

case "$STAGE" in
    sync)  run "$CONTAINER" bash /src/zero2-build/scripts/00-sync.sh ;;
    build) run "$CONTAINER" bash /src/zero2-build/scripts/10-build.sh ;;
    ib)    run "$CONTAINER" bash /src/zero2-build/scripts/20-imagebuilder.sh ;;
    image) run --env-file "$envfile" "$CONTAINER" bash /src/zero2-build/scripts/30-pack-image.sh ;;
    shell) docker exec -it "$CONTAINER" bash ;;
    all)
        run "$CONTAINER" bash /src/zero2-build/scripts/00-sync.sh
        run "$CONTAINER" bash /src/zero2-build/scripts/10-build.sh
        run "$CONTAINER" bash /src/zero2-build/scripts/20-imagebuilder.sh
        run --env-file "$envfile" "$CONTAINER" bash /src/zero2-build/scripts/30-pack-image.sh
        ;;
    *) echo "usage: $0 [all|sync|build|ib|image|shell]" >&2; exit 1 ;;
esac

echo "output: $OUT"
ls -lh "$OUT" | tail -n 20