#!/bin/bash
set -euo pipefail

ZIG_VERSION=$1
BUILD_VERSION=$2

if [ -z "$ZIG_VERSION" ] || [ -z "$BUILD_VERSION" ]; then
    echo "Usage: $0 <zig_version> <build_version>"
    echo "Example: $0 0.13.0 1"
    exit 1
fi

PACKAGE_NAME="zig-stable"
ORIG_TARBALL="${PACKAGE_NAME}_${ZIG_VERSION}.orig.tar.gz"
BUILD_DIR="zig-${ZIG_VERSION}"

echo "Creating the source package for zig-stable ${ZIG_VERSION}-${BUILD_VERSION}..."

# A rebuild of an upstream version already released here (a +N build bump)
# must ship the very same orig tarball: the pool holds one per upstream
# version and reprepro refuses a different one, and nothing guarantees the
# archive download is byte-identical next time. Reuse the earlier release's copy.
if [ ! -f "$ORIG_TARBALL" ]; then
    for ((b = BUILD_VERSION - 1; b >= 1; b--)); do
        if wget -q "https://github.com/dariogriffo/zig-debian/releases/download/${ZIG_VERSION}%2B${b}/${ORIG_TARBALL}" -O "$ORIG_TARBALL"; then
            echo "  Reusing $ORIG_TARBALL from release ${ZIG_VERSION}+${b}"
            break
        fi
        rm -f "$ORIG_TARBALL"
    done
fi

# Download upstream source tarball (shared .orig.tar.gz across all distributions)
if [ ! -f "$ORIG_TARBALL" ]; then
    echo "Downloading upstream source from Codeberg..."
    wget -q "https://codeberg.org/ziglang/zig/archive/${ZIG_VERSION}.tar.gz" -O "$ORIG_TARBALL"
    echo "  Downloaded $ORIG_TARBALL"
else
    echo "  Using existing $ORIG_TARBALL"
fi

build_source_package() {
    local FULL_VERSION="${ZIG_VERSION}-${BUILD_VERSION}~griffo"

    echo "  Building source package ${FULL_VERSION}..."

    # Clean and recreate build directory from orig tarball
    # Codeberg archives extract as zig/, not zig-0.x.y/, so strip the top
    # directory and extract straight into BUILD_DIR
    rm -rf "$BUILD_DIR"
    mkdir "$BUILD_DIR"
    tar -xf "$ORIG_TARBALL" -C "$BUILD_DIR" --strip-components=1

    # Copy Debian packaging directory
    cp -r debian "$BUILD_DIR/"

    # Generate the changelog (overwrites placeholder)
    cat > "$BUILD_DIR/debian/changelog" << EOF
zig-stable (${FULL_VERSION}) stable; urgency=medium

  * New upstream release ${ZIG_VERSION}.

 -- Dario Griffo <dariogriffo@gmail.com>  $(date -R)
EOF

    # Build source package (.dsc + .debian.tar.xz); reuses existing .orig.tar.gz
    dpkg-source -b "$BUILD_DIR"

    rm -rf "$BUILD_DIR"
    echo "    ${FULL_VERSION}"
}

echo ""
# One source package for every suite, as with the binaries (see build_zig_stable_debian.sh).
build_source_package

echo ""
echo "Source packages created successfully!"
echo ""
echo "Generated files:"
ls -la "${PACKAGE_NAME}_"*.dsc "${PACKAGE_NAME}_"*.orig.tar.gz "${PACKAGE_NAME}_"*.debian.tar.xz 2>/dev/null || true
