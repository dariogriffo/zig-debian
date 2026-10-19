ZIG_VERSION=$1
BUILD_VERSION=$2
ARCH=${3:-amd64}
ZIG_OLDSTABLE_VERSION=${4:-}   # optional, as in the release workflow
./build_zig_stable_debian.sh $1 $2 $3
if [ -n "$ZIG_OLDSTABLE_VERSION" ]; then
    ./build_zig_oldstable_debian.sh $ZIG_OLDSTABLE_VERSION $2 $3
fi
./build_src.sh $1 $2
