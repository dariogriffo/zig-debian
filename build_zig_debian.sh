ZIG_VERSION=$1
BUILD_VERSION=$2
declare -a arr=("bookworm" "trixie" "sid")
for i in "${arr[@]}"
do
  DEBIAN_DIST=$i
  FULL_VERSION=$ZIG_VERSION-${BUILD_VERSION}+${DEBIAN_DIST}_amd64
  docker build . -t zig-$DEBIAN_DIST --build-arg ZIG_VERSION=$ZIG_VERSION --build-arg DEBIAN_DIST=$DEBIAN_DIST --build-arg BUILD_VERSION=$BUILD_VERSION --build-arg FULL_VERSION=$FULL_VERSION
  id="$(docker create zig-$DEBIAN_DIST)"
  docker cp $id:/zig_$FULL_VERSION.deb - > ./zig_$FULL_VERSION.deb
  tar -xf ./zig_$FULL_VERSION.deb
done

  