# Io: os-release and lsb_release belong to Void's base-files, which restores
# its own versions on every update. io-release keeps Io's under /usr/share/io
# and puts them back at boot when they differ (/etc/os-release is a link to
# /usr/lib/os-release).
for f in os-release:/usr/lib/os-release lsb_release:/usr/bin/lsb_release; do
	src="/usr/share/io/${f%%:*}"
	dst="${f#*:}"
	if [ -f "$src" ] && ! cmp -s "$src" "$dst"; then
		cp -f "$src" "$dst"
		[ "$dst" = /usr/bin/lsb_release ] && chmod 755 "$dst"
	fi
done
