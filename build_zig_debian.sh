ZIG_VERSION=$1
BUILD_VERSION=$2
ARCH=${3:-amd64}

if [ -z "$ZIG_VERSION" ] || [ -z "$BUILD_VERSION" ]; then
    echo "Usage: $0 <zig_version> <build_version> [architecture]"
    echo "Example: $0 0.16.0-dev.2682+02142a54d 1 arm64"
    echo "Example: $0 0.16.0-dev.2682+02142a54d 1 all    # Build for all architectures"
    echo "Supported architectures: amd64, arm64, armel, riscv64, ppc64el, i386, loong64, s390x, all"
    exit 1
fi

# Map Debian architecture to zig release arch name
get_zig_arch() {
    local arch=$1
    case "$arch" in
        "amd64")    echo "x86_64" ;;
        "arm64")    echo "aarch64" ;;
        "armel")    echo "arm" ;;
        "riscv64")  echo "riscv64" ;;
        "ppc64el")  echo "powerpc64le" ;;
        "i386")     echo "x86" ;;
        "loong64")  echo "loongarch64" ;;
        "s390x")    echo "s390x" ;;
        *)          echo "" ;;
    esac
}

build_architecture() {
    local build_arch=$1
    local zig_arch

    zig_arch=$(get_zig_arch "$build_arch")
    if [ -z "$zig_arch" ]; then
        echo "❌ Unsupported architecture: $build_arch"
        echo "Supported architectures: amd64, arm64, armel, riscv64, ppc64el, i386, loong64, s390x"
        return 1
    fi

    echo "Building for architecture: $build_arch using zig arch $zig_arch"

    declare -a arr=("bookworm" "trixie" "forky" "sid")

    for dist in "${arr[@]}"; do
        FULL_VERSION="$ZIG_VERSION-${BUILD_VERSION}+${dist}_${build_arch}"
        echo "  Building zig $FULL_VERSION"

        if ! docker build . -t "zig-$dist-$build_arch" \
            --build-arg ZIG_VERSION="$ZIG_VERSION" \
            --build-arg DEBIAN_DIST="$dist" \
            --build-arg BUILD_VERSION="$BUILD_VERSION" \
            --build-arg FULL_VERSION="$FULL_VERSION" \
            --build-arg ARCH="$build_arch" \
            -f meta_Dockerfile; then
            echo "❌ Failed to build Docker image for zig $dist on $build_arch"
            return 1
        fi
        id="$(docker create "zig-$dist-$build_arch")"
        docker cp "$id:/zig_$FULL_VERSION.deb" - > "./zig_$FULL_VERSION.deb"
        tar -xf "./zig_$FULL_VERSION.deb"

        if ! docker build . -t "zig-$dist-$build_arch" \
            --build-arg ZIG_VERSION="$ZIG_VERSION" \
            --build-arg DEBIAN_DIST="$dist" \
            --build-arg BUILD_VERSION="$BUILD_VERSION" \
            --build-arg FULL_VERSION="$FULL_VERSION" \
            --build-arg ARCH="$build_arch" \
            --build-arg ZIG_ARCH="$zig_arch" \
            -f zero_Dockerfile; then
            echo "❌ Failed to build Docker image for zig-zero $dist on $build_arch"
            return 1
        fi
        id="$(docker create "zig-$dist-$build_arch")"
        docker cp "$id:/zig-zero_$FULL_VERSION.deb" - > "./zig-zero_$FULL_VERSION.deb"
        tar -xf "./zig-zero_$FULL_VERSION.deb"
    done

    echo "✅ Successfully built for $build_arch"
    return 0
}

if [ "$ARCH" = "all" ]; then
    echo "🚀 Building zig $ZIG_VERSION-$BUILD_VERSION for all supported architectures..."
    echo ""

    ARCHITECTURES=("amd64" "arm64" "armel" "riscv64" "ppc64el" "i386" "loong64" "s390x")

    for build_arch in "${ARCHITECTURES[@]}"; do
        echo "==========================================="
        echo "Building for architecture: $build_arch"
        echo "==========================================="

        if ! build_architecture "$build_arch"; then
            echo "❌ Failed to build for $build_arch"
            exit 1
        fi

        echo ""
    done

    echo "🎉 All architectures built successfully!"
    echo "Generated packages:"
    ls -la zig_*.deb zig-zero_*.deb
else
    if ! build_architecture "$ARCH"; then
        exit 1
    fi
fi
