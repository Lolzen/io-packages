# Io: start game mode on tty1
if [ "$(tty)" = "/dev/tty1" ]; then
    START=$(date +%s)
    io-start
    END=$(date +%s)
    if [ $((END - START)) -lt 15 ]; then
        echo "io: session ended after $((END - START))s, dropping to a shell instead of restarting."
        IO_LOG=$(ls -t /run/user/$(id -u)/io-log-*/current "$HOME"/.local/state/io/log-*/current 2> /dev/null | head -1)
        if [ -n "$IO_LOG" ]; then
            echo "io: last messages from $IO_LOG:"
            tail -n 20 "$IO_LOG"
        fi
        unset IO_LOG
    else
        exec io-start
    fi
fi
