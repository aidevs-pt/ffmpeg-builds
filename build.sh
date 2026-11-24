#!/usr/bin/env bash
# Builds static ffmpeg and ffprobe with a small, redistributable GPL configuration:
#
#   ./build.sh <linux-x64|macos-arm64|macos-x64|windows-x64> <output-directory>
#
# Linux and macOS build natively on that platform; windows-x64 cross-compiles from Linux with
# mingw-w64 (POSIX threads). Every source is verified against sources.txt before it is used.
set -euo pipefail

target=${1:?target}
output=$(mkdir -p "${2:?output directory}" && cd "$2" && pwd)
here=$(cd "$(dirname "$0")" && pwd)
work=${WORK:-$here/work}/$target
prefix=$work/prefix
cache=$here/cache
jobs=$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu)
mkdir -p "$work/src" "$prefix/lib/pkgconfig" "$cache"
export PKG_CONFIG_PATH=$prefix/lib/pkgconfig
export PKG_CONFIG_LIBDIR=$prefix/lib/pkgconfig
export PATH=$prefix/bin:$PATH

host="" cross="" meson_cross="" ffmpeg_platform=""
extra_libs="-lm"
case $target in
  linux-x64)
    export CFLAGS="-O2 -fPIC" CXXFLAGS="-O2 -fPIC"
    extra_libs="-lstdc++ -lm -lpthread"
    ffmpeg_platform="--enable-pthreads --enable-libfontconfig"
    ;;
  macos-arm64 | macos-x64)
    export MACOSX_DEPLOYMENT_TARGET=11.0
    export CFLAGS="-O2 -mmacosx-version-min=11.0" CXXFLAGS="-O2 -mmacosx-version-min=11.0"
    export LDFLAGS="-mmacosx-version-min=11.0"
    extra_libs="-lc++ -lm"
    ffmpeg_platform="--enable-pthreads --enable-videotoolbox --enable-audiotoolbox"
    ;;
  windows-x64)
    triple=x86_64-w64-mingw32
    export CC=$triple-gcc-posix CXX=$triple-g++-posix AR=$triple-ar RANLIB=$triple-ranlib
    # Static libraries: without FRIBIDI_LIB_STATIC, fribidi's headers ask for DLL imports.
    export CFLAGS="-O2 -DFRIBIDI_LIB_STATIC" CXXFLAGS="-O2" LDFLAGS="-static -static-libgcc -static-libstdc++"
    host="--host=$triple"
    cross="--arch=x86_64 --target-os=mingw32 --cross-prefix=$triple- --cc=$CC --cxx=$CXX"
    cat > "$work/cross.ini" <<EOF
[binaries]
c = '$CC'
cpp = '$CXX'
ar = '$AR'
strip = '$triple-strip'
windres = '$triple-windres'
pkg-config = 'pkg-config'
[host_machine]
system = 'windows'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
EOF
    meson_cross="--cross-file $work/cross.ini"
    extra_libs="-lstdc++ -lm"
    ffmpeg_platform="--enable-w32threads"
    ;;
  *) echo "Unknown target $target" >&2; exit 2 ;;
esac

# Download (once), verify and unpack a source from sources.txt; prints its directory.
source_dir() {
  local name=$1 version sha url file
  read -r _ version sha url < <(grep "^$name " "$here/sources.txt")
  file=$cache/$name-$version.archive
  if [ ! -s "$file" ]; then curl -sfL --retry 3 -o "$file.part" "$url" && mv "$file.part" "$file"; fi
  if ! echo "$sha  $file" | sha256sum -c --status 2>/dev/null && ! echo "$sha  $file" | shasum -a 256 -c --status 2>/dev/null; then
    echo "Checksum mismatch for $name" >&2; exit 1
  fi
  rm -rf "$work/src/$name"; mkdir -p "$work/src/$name"
  tar -xf "$file" -C "$work/src/$name" --strip-components=1
  echo "$work/src/$name"
}

autotools() { # name configure-arguments...
  local dir; dir=$(source_dir "$1"); shift
  (cd "$dir" && ./configure --prefix="$prefix" --enable-static --disable-shared $host "$@" && make -j"$jobs" && make install)
}

meson_lib() { # name meson-options...
  local dir; dir=$(source_dir "$1"); shift
  (cd "$dir" && meson setup build --prefix="$prefix" --libdir=lib --buildtype=release \
    --default-library=static $meson_cross "$@" && ninja -C build -j"$jobs" && ninja -C build install)
}

# zlib: PNG, for stills and image sequences.
dir=$(source_dir zlib)
(cd "$dir" && if [ "$target" = windows-x64 ]; then CHOST=x86_64-w64-mingw32 ./configure --prefix="$prefix" --static; else ./configure --prefix="$prefix" --static; fi && make -j"$jobs" && make install)

# x264: H.264, the most widely playable video format.
dir=$(source_dir x264)
(cd "$dir" && ./configure --prefix="$prefix" --enable-static --disable-cli --enable-pic \
  $host $([ "$target" = windows-x64 ] && echo --cross-prefix=x86_64-w64-mingw32-) && make -j"$jobs" && make install)

# LAME: MP3, for audio exports.
autotools lame --disable-frontend --disable-gtktest --disable-decoder

# Text: freetype, harfbuzz and fribidi for drawn text and subtitles, through libass.
autotools freetype --with-zlib=no --with-png=no --with-bzip2=no --with-brotli=no --with-harfbuzz=no
meson_lib harfbuzz -Dfreetype=enabled -Dglib=disabled -Dgobject=disabled -Dcairo=disabled -Dicu=disabled \
  -Dchafa=disabled -Dtests=disabled -Ddocs=disabled -Dutilities=disabled -Dintrospection=disabled
meson_lib fribidi -Ddocs=false -Dbin=false -Dtests=false
if [ "$target" = linux-x64 ]; then
  # libass finds system fonts through fontconfig on Linux; macOS and Windows use the system APIs.
  autotools expat --without-docbook --without-examples --without-tests --without-xmlwf
  # It reads the user's /etc/fonts at runtime; only its sample configuration installs into the prefix.
  dir=$(source_dir fontconfig)
  (cd "$dir" && ./configure --prefix="$prefix" --enable-static --disable-shared --disable-docs \
    --disable-cache-build --sysconfdir=/etc --localstatedir=/var && make -j"$jobs" \
    && make install sysconfdir="$prefix/etc" localstatedir="$prefix/var")
fi
autotools libass

# dav1d: AV1 decoding for footage from newer cameras and screen recorders.
meson_lib dav1d -Denable_tools=false -Denable_tests=false -Denable_examples=false

dir=$(source_dir ffmpeg)
(cd "$dir" && ./configure --prefix="$prefix" --pkg-config-flags=--static \
  --extra-cflags="-I$prefix/include ${CFLAGS:-}" --extra-ldflags="-L$prefix/lib ${LDFLAGS:-}" --extra-libs="$extra_libs" \
  $cross \
  --enable-gpl --enable-static --disable-shared --disable-debug --disable-doc --disable-ffplay \
  --disable-autodetect --disable-network \
  --enable-zlib --enable-libx264 --enable-libmp3lame --enable-libfreetype --enable-libharfbuzz \
  --enable-libfribidi --enable-libass --enable-libdav1d $ffmpeg_platform \
  || { tail -60 ffbuild/config.log >&2; exit 1; }
  make -j"$jobs" && make install)

exe=""; [ "$target" = windows-x64 ] && exe=.exe
strip_tool=strip; [ "$target" = windows-x64 ] && strip_tool=x86_64-w64-mingw32-strip
for tool in ffmpeg ffprobe; do
  cp "$prefix/bin/$tool$exe" "$output/$tool$exe"
  "$strip_tool" "$output/$tool$exe" 2>/dev/null || true
done

# Licenses travel with the binaries.
mkdir -p "$output/licenses"
cp "$work/src/ffmpeg/COPYING.GPLv2" "$work/src/ffmpeg/LICENSE.md" "$output/licenses/" 2>/dev/null || true
for name in x264 lame zlib freetype harfbuzz fribidi libass dav1d expat fontconfig; do
  [ -d "$work/src/$name" ] || continue
  for file in COPYING LICENSE LICENSE.TXT COPYING.LIB docs/FTL.TXT docs/LICENSE.TXT; do
    [ -f "$work/src/$name/$file" ] && cp "$work/src/$name/$file" "$output/licenses/$name-$(basename "$file")"
  done
done
{
  echo "FFmpeg $(grep '^ffmpeg ' "$here/sources.txt" | cut -d' ' -f2) for $target, built from these sources:"
  grep -v '^#' "$here/sources.txt" | while read -r name version sha url; do
    [ -d "$work/src/$name" ] && echo "  $name $version  sha256 $sha  $url"
  done
  echo
  echo "FFmpeg configuration:"
  sed -n 's/^#define FFMPEG_CONFIGURATION "\(.*\)"/  \1/p' "$work/src/ffmpeg/config.h"
} > "$output/BUILD.txt"
echo "Built $target into $output"
