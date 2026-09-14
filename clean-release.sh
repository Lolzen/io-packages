#!/bin/sh
set -eu
cd ~/io-repo-pub
gh release view current --repo Lolzen/io-repo --json assets --jq '.assets[].name' | sort > /tmp/uploaded-assets.txt
ls *.xbps *.sig2 x86_64-repodata | sort > /tmp/current-assets.txt
comm -23 /tmp/uploaded-assets.txt /tmp/current-assets.txt > /tmp/stale-assets.txt

echo "Veraltet, wird geloescht:"
cat /tmp/stale-assets.txt
echo
printf "Fortfahren? [y/N] "
read confirm
if [ "$confirm" != "y" ]; then
    echo "Abgebrochen."
    exit 0
fi

while read -r f; do
    gh release delete-asset current "$f" --repo Lolzen/io-repo --yes
done < /tmp/stale-assets.txt
echo "Fertig."