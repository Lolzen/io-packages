#!/bin/bash
# notes.sh <title> <previous tag> <previous name> <range end> - release notes:
# the commits since the previous release, then how to install.
set -euo pipefail
title=$1 prev=$2 prev_name=$3 end=$4
repo=${GITHUB_REPOSITORY:-Lolzen/io-packages}
url=https://github.com/$repo
count=$(git rev-list --no-merges --count "$prev..$end")

echo "## $title"
echo
echo "Changes since [$prev_name]($url/releases/tag/$prev) ($count commits, [full diff]($url/compare/$prev...$end)):"
echo
git log --no-merges --reverse --format="- %s ([%h]($url/commit/%H))" "$prev..$end"
cat << EOF

**Install:** \`cat io.img.xz.part* > io.img.xz\`, check it against \`io.img.xz.sha256\`, then see [Installation]($url/wiki/Installation). For the internal SSD: the recovery stick, \`cat recovery.img.xz.part* > recovery.img.xz\`, checked against \`recovery.img.xz.sha256\`. The parts exist because GitHub takes no file of 2 GiB or more.

Existing installs update from Steam (Settings → System) or with \`sudo xbps-install -Syu\`.
EOF
