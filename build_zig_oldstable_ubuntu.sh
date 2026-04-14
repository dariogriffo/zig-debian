ZIG_VERSION=$1
BUILD_VERSION=$2
ARCH=${3:-amd64}

if [ -z "$ZIG_VERSION" ] || [ -z "$BUILD_VERSION" ]; then
    echo "Usage: $0 <zig_version> <build_version> [architecture]"
    echo "Example: $0 0.14.0 1 arm64"
    echo "Example: $0 0.14.0 1 all    # Build for all architectures"
    echo "Supported architectures: amd64, arm64, armel, riscv64, ppc64el, i386, loong64, s390x, all"
    exit 1
fi

# Map Ubuntu architecture to zig release arch name
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

build_dist() {
    local dist=$1
    local build_arch=$2
    local zig_arch=$3
    local full_ver="$ZIG_VERSION-${BUILD_VERSION}+${dist}_${build_arch}_ubu"

    echo "  [$dist] Building zig-oldstable $full_ver"

    if ! docker build . -f oldstable_Dockerfile.ubu -t "zig-ubuntu-oldstable-$dist-$build_arch" \
        --build-arg ZIG_VERSION="$ZIG_VERSION" \
        --build-arg UBUNTU_DIST="$dist" \
        --build-arg BUILD_VERSION="$BUILD_VERSION" \
        --build-arg FULL_VERSION="$full_ver" \
        --build-arg ARCH="$build_arch" \
        --build-arg ZIG_ARCH="$zig_arch"; then
        echo "❌ [$dist] Failed oldstable build"
        return 1
    fi
    id="$(docker create "zig-ubuntu-oldstable-$dist-$build_arch")"
    docker cp "$id:/zig-oldstable_$full_ver.deb" - > "./zig-oldstable_$full_ver.deb"
    tar -xf "./zig-oldstable_$full_ver.deb"

    echo "  ✅ [$dist] Done"
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

    # Download and extract once on the host before parallel distro builds.
    # Extraction happens here (not inside Docker) to avoid concurrent writes to the same folder name.
    local tarball="zig-${zig_arch}-linux-${ZIG_VERSION}.tar.xz"
    if ! wget -q "https://ziglang.org/download/${ZIG_VERSION}/${tarball}" -O "$tarball"; then
        echo "❌ Failed to download zig tarball for $build_arch"
        return 1
    fi
    mkdir -p "build/${build_arch}"
    tar -xf "$tarball" -C "build/${build_arch}"
    rm -f "$tarball"

    # Build all distros in parallel
    local pids=()
    for dist in "jammy" "noble" "questing"; do
        build_dist "$dist" "$build_arch" "$zig_arch" &
        pids+=($!)
    done

    local failed=0
    for pid in "${pids[@]}"; do
        wait "$pid" || failed=1
    done

    rm -rf "build/${build_arch}"

    if [ $failed -ne 0 ]; then
        echo "❌ One or more distro builds failed for $build_arch"
        return 1
    fi

    echo "✅ Successfully built for $build_arch"
    return 0
}

if [ "$ARCH" = "all" ]; then
    echo "🚀 Building zig-oldstable $ZIG_VERSION-$BUILD_VERSION for all supported architectures..."
    echo ""

    for build_arch in "amd64" "arm64" "armel" "riscv64" "ppc64el" "i386" "loong64" "s390x"; do
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
    ls -la zig-oldstable_*.deb
else
    if ! build_architecture "$ARCH"; then
        exit 1
    fi
fi
