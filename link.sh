#!/bin/sh
set -eu
IO_DIR="${IO_DIR:-$HOME/io-packages}"
VP_DIR="${VP_DIR:-$HOME/void-packages}"

for p in "$IO_DIR"/srcpkgs/*/; do
    [ -d "$p" ] || continue
    name=$(basename "$p")
    rm -rf "$VP_DIR/srcpkgs/$name"
    ln -sfn "${p%/}" "$VP_DIR/srcpkgs/$name"
    echo "linked: $name"
done