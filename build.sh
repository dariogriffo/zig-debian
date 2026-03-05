ZIG_VERSION=$1
BUILD_VERSION=$2
ARCH=${3:-amd64}
./build_zig_debian.sh $1 $2 $3
./build_zig_ubuntu.sh $1 $2 $3
