#!/bin/sh
# Build a scratch Oracle7 root from the package tarball: every entry of upstream/root is a symlink (nothing is
# written under upstream/), except specialists/, a real folder holding symlinks to the shipped specialists plus the
# unpacked package. Usage: tools/organs/smoke_root.sh <tarball> <scratch dir>
set -eu
tarball=$1; dest=$2
REPO=$(cd "$(dirname "$0")/../.." && pwd -P)
UP=${PARITY_UPSTREAM:-$REPO/upstream}/root
rm -rf "$dest"; mkdir -p "$dest/root/specialists"
for e in "$UP"/*; do
  [ "$(basename "$e")" = specialists ] || ln -s "$e" "$dest/root/$(basename "$e")"
done
for e in "$UP"/specialists/*; do ln -s "$e" "$dest/root/specialists/$(basename "$e")"; done
tar -xzf "$tarball" -C "$dest/root"
echo "$dest/root"
