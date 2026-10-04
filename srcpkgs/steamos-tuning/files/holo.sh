# Valve's profile.d/holo.sh (steamos-customizations-jupiter 20260827.2,
# SteamOS 3.9.2; steamos.sh on 3.8.4), written for any POSIX shell: Valve's
# uses bash's [[ ]], and /etc/profile is not only read by bash.
if [ -z "$EDITOR" ] && command -v vim > /dev/null
then
	EDITOR=vim
	export EDITOR
fi

if [ -z "$VISUAL" ] && command -v gvim > /dev/null
then
	VISUAL=gvim
	export VISUAL
fi
