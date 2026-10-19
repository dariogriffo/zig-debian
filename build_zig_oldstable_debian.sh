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

build_man_page() {
    local build_arch=$1
    local zig_arch=$2

    echo "  Generating man page for oldstable ($build_arch)..."
    mkdir -p "build/man"

    if ! docker build . -t "zig-docs-oldstable-$build_arch" \
        --build-arg ZIG_VERSION="$ZIG_VERSION" \
        --build-arg ZIG_ARCH="$zig_arch" \
        --build-arg ARCH="$build_arch" \
        --build-arg VARIANT="oldstable" \
        -f docs_Dockerfile; then
        echo "❌ Failed to build man page for oldstable"
        return 1
    fi
    local id
    id="$(docker create "zig-docs-oldstable-$build_arch")"
    docker cp "$id:/man/zig-oldstable.1.gz" "build/man/zig-oldstable.1.gz"
    docker rm "$id"
}

# One set of packages for every suite: upstream's binaries are static, so
# only the old ~<suite> version suffix ever differed. The fixed ~griffo keeps
# it below the distro's own build of the same version.
build_packages() {
    local build_arch=$1
    local zig_arch=$2
    local full_ver="$ZIG_VERSION-${BUILD_VERSION}~griffo_${build_arch}"

    echo "  Building zig-oldstable $full_ver"

    if ! docker build . -t "zig-oldstable-$build_arch" \
        --build-arg ZIG_VERSION="$ZIG_VERSION" \
        --build-arg BUILD_VERSION="$BUILD_VERSION" \
        --build-arg FULL_VERSION="$full_ver" \
        --build-arg ARCH="$build_arch" \
        --build-arg ZIG_ARCH="$zig_arch" \
        -f oldstable_Dockerfile; then
        echo "❌ Failed oldstable build"
        return 1
    fi
    id="$(docker create "zig-oldstable-$build_arch")"
    docker cp "$id:/zig-oldstable_$full_ver.deb" - > "./zig-oldstable_$full_ver.deb"
    tar -xf "./zig-oldstable_$full_ver.deb"

    echo "  ✅ Done"
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

    # Download and extract on the host; the Dockerfiles copy from build/<arch>/.
    local tarball="zig-${zig_arch}-linux-${ZIG_VERSION}.tar.xz"
    if ! wget -q "https://ziglang.org/download/${ZIG_VERSION}/${tarball}" -O "$tarball"; then
        echo "❌ Failed to download zig tarball for $build_arch"
        return 1
    fi
    mkdir -p "build/${build_arch}"
    tar -xf "$tarball" -C "build/${build_arch}"
    rm -f "$tarball"

    # Generate the man page, shared by every package of this architecture
    if ! build_man_page "$build_arch" "$zig_arch"; then
        return 1
    fi

    local failed=0
    build_packages "$build_arch" "$zig_arch" || failed=1

    rm -rf "build/${build_arch}"
    rm -f "build/man/zig-oldstable.1.gz"

    if [ $failed -ne 0 ]; then
        echo "❌ Build failed for $build_arch"
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
