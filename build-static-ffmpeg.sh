#!/bin/sh
# Build a fully static, musl-linked FFmpeg via Docker and extract the
# resulting binaries to ./out/ on the host.
#
# The heavy lifting (codec compiles + FFmpeg build) happens inside the
# container described by Dockerfile.static-musl.
set -eu

usage() {
    cat <<'EOF'
Usage: ./build-static-ffmpeg.sh [--stable | --latest]
  --stable  Use pinned releases for Alpine and source components (default).
  --latest  Use alpine:latest and current upstream main/master branches.
Set OUT to override the default output directory (./out).
EOF
}

if [ "$#" -gt 1 ]; then
    usage >&2
    exit 2
fi

case "${1---stable}" in
    --stable) MODE=stable ;;
    --latest) MODE=latest ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac

# Sources are release tarballs or Git URLs ending in #<tag-or-branch>.
if [ "$MODE" = stable ]; then
    ALPINE_VERSION=3.24.4
    PCRE2_TAG=pcre2-10.49
    DAV1D_VERSION=1.5.5
    LIBASS_TAG=0.17.5

    PCRE2_SOURCE=https://github.com/PCRE2Project/pcre2/releases/download/$PCRE2_TAG/$PCRE2_TAG.tar.gz
    OPUS_SOURCE=https://downloads.xiph.org/releases/opus/opus-1.6.1.tar.gz
    VPX_SOURCE=https://github.com/webmproject/libvpx/archive/refs/tags/v1.17.0.tar.gz
    X265_SOURCE=https://github.com/Multicorewareinc/x265.git#4.3
    DAV1D_SOURCE=https://download.videolan.org/pub/videolan/dav1d/$DAV1D_VERSION/dav1d-$DAV1D_VERSION.tar.xz
    SVTAV1_SOURCE=https://github.com/AOMediaCodec/SVT-AV1/archive/refs/tags/v4.3.1.tar.gz
    ZIMG_SOURCE=https://github.com/sekrit-twc/zimg.git#release-3.0.6
    FDKAAC_SOURCE=https://github.com/mstorsjo/fdk-aac/archive/refs/tags/v2.0.3.tar.gz
    LIBASS_SOURCE=https://github.com/libass/libass/releases/download/$LIBASS_TAG/libass-$LIBASS_TAG.tar.gz
    FFMPEG_SOURCE=https://ffmpeg.org/releases/ffmpeg-9.1.tar.gz
else
    ALPINE_VERSION=latest
    PCRE2_SOURCE=https://github.com/PCRE2Project/pcre2.git#main
    OPUS_SOURCE=https://github.com/xiph/opus.git#main
    VPX_SOURCE=https://github.com/webmproject/libvpx.git#main
    X265_SOURCE=https://github.com/Multicorewareinc/x265.git#master
    DAV1D_SOURCE=https://code.videolan.org/videolan/dav1d.git#master
    SVTAV1_SOURCE=https://github.com/AOMediaCodec/SVT-AV1.git#main
    ZIMG_SOURCE=https://github.com/sekrit-twc/zimg.git#master
    FDKAAC_SOURCE=https://github.com/mstorsjo/fdk-aac.git#master
    LIBASS_SOURCE=https://github.com/libass/libass.git#master
    FFMPEG_SOURCE=https://github.com/FFmpeg/FFmpeg.git#master
fi

# Resolve the directory this script lives in, so it works from anywhere.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

DOCKERFILE="${DOCKERFILE:-Dockerfile.static-musl}"
OUT="${OUT:-$SCRIPT_DIR/out}"
TAG="${TAG:-ffmpeg-static-musl}"

set --
if [ "$MODE" = latest ]; then
    set -- --pull --no-cache
fi

echo ">> Building FFmpeg ($MODE) on alpine:$ALPINE_VERSION with $DOCKERFILE..."
DOCKER_BUILDKIT=1 docker build \
    "$@" \
    -f "$DOCKERFILE" \
    --build-arg "ALPINE_VERSION=$ALPINE_VERSION" \
    --build-arg "PCRE2_SOURCE=$PCRE2_SOURCE" \
    --build-arg "OPUS_SOURCE=$OPUS_SOURCE" \
    --build-arg "VPX_SOURCE=$VPX_SOURCE" \
    --build-arg "X265_SOURCE=$X265_SOURCE" \
    --build-arg "DAV1D_SOURCE=$DAV1D_SOURCE" \
    --build-arg "SVTAV1_SOURCE=$SVTAV1_SOURCE" \
    --build-arg "ZIMG_SOURCE=$ZIMG_SOURCE" \
    --build-arg "FDKAAC_SOURCE=$FDKAAC_SOURCE" \
    --build-arg "LIBASS_SOURCE=$LIBASS_SOURCE" \
    --build-arg "FFMPEG_SOURCE=$FFMPEG_SOURCE" \
    --tag "$TAG" \
    --output "type=local,dest=$OUT" \
    "$SCRIPT_DIR"

echo
echo ">> Build complete. Artifacts in: $OUT"
ls -lh "$OUT"

echo
echo ">> Verifying the binary is fully static..."
file "$OUT/ffmpeg"
if command -v readelf >/dev/null 2>&1 && readelf -d "$OUT/ffmpeg" 2>/dev/null | grep -q NEEDED; then
    echo "WARNING: ffmpeg has dynamic dependencies:"
    readelf -d "$OUT/ffmpeg" | grep NEEDED
elif file "$OUT/ffmpeg" | grep -q "statically linked"; then
    echo "OK: statically linked, no dynamic dependencies (portable across any x86_64 Linux)."
else
    echo "NOTE: could not fully confirm static linkage; inspect with: file/readelf -d $OUT/ffmpeg"
fi

echo
echo ">> Version + enabled external libraries:"
"$OUT/ffmpeg" -hide_banner -buildconf | grep -oE 'enable-(lib[a-z0-9-]+|mbedtls|gpl|version3|nonfree)' | sort

echo
echo ">> Done. Copy $OUT/ffmpeg to your machine and run it directly."
