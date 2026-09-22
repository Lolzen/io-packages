# Io: end SSH sessions while the network is still up.
#
# runit stops every service at once in 10-sv-stop.sh, NetworkManager
# included, and only kills the remaining processes in 70-pkill.sh. An SSH
# session ended there can no longer tell the client, which then sees
# "Connection reset by peer" instead of a clean close. systemd on SteamOS
# ends user sessions while the network is still up.
#
# Sourced by /etc/runit/3 - must not exit.
if pkill -TERM -x sshd-session 2> /dev/null; then
    sleep 1
fi