#!/bin/bash
ZIG_VERSION=$1
BUILD_VERSION=$2
TARGET_ARCH=$3

declare -a dists=("bookworm" "trixie" "forky" "sid")

for dist in "${dists[@]}"
do
  DEBIAN_DIST=$dist

  if [ "$arch" = "arm64" ]; then
    ZIG_ARCH="aarch64"
  else
    ZIG_ARCH="x86_64"
  fi

  FULL_VERSION=$ZIG_VERSION-${BUILD_VERSION}+${DEBIAN_DIST}_${TARGET_ARCH}

  docker build . -t zig-$DEBIAN_DIST-$TARGET_ARCH \
    --build-arg ZIG_VERSION=$ZIG_VERSION \
    --build-arg DEBIAN_DIST=$DEBIAN_DIST \
    --build-arg BUILD_VERSION=$BUILD_VERSION \
    --build-arg FULL_VERSION=$FULL_VERSION \
    --build-arg DEBIAN_ARCH=$TARGET_ARCH \
    --build-arg ZIG_ARCH=$ZIG_ARCH \
    -f meta_Dockerfile
  id="$(docker create zig-$DEBIAN_DIST-$TARGET_ARCH)"
  docker cp $id:/zig_$FULL_VERSION.deb ./zig_$FULL_VERSION.deb

  docker build . -t zig-zero-$DEBIAN_DIST-$TARGET_ARCH \
    --build-arg ZIG_VERSION=$ZIG_VERSION \
    --build-arg DEBIAN_DIST=$DEBIAN_DIST \
    --build-arg BUILD_VERSION=$BUILD_VERSION \
    --build-arg FULL_VERSION=$FULL_VERSION \
    --build-arg DEBIAN_ARCH=$TARGET_ARCH \
    --build-arg ZIG_ARCH=$ZIG_ARCH \
    -f zero_Dockerfile
  id="$(docker create zig-zero-$DEBIAN_DIST-$TARGET_ARCH)"
  docker cp $id:/zig-zero_$FULL_VERSION.deb ./zig-zero_$FULL_VERSION.deb
done
