#!/usr/bin/env bash
# Downloads every source in sources.txt into cache/ and verifies its SHA-256.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$here/cache"
grep -v '^#' "$here/sources.txt" | while read -r name version sha url; do
  [ -n "$name" ] || continue
  file=$here/cache/$name-$version.archive
  if [ ! -s "$file" ]; then
    curl -sfL --retry 3 -o "$file.part" "$url"
    mv "$file.part" "$file"
  fi
  if ! echo "$sha  $file" | sha256sum -c --status 2>/dev/null && ! echo "$sha  $file" | shasum -a 256 -c --status 2>/dev/null; then
    echo "Checksum mismatch for $name" >&2; exit 1
  fi
  echo "$name $version verified"
done
