# Io: Game Mode auf tty1 starten
if [ "$(tty)" = "/dev/tty1" ]; then
    START=$(date +%s)
    io-start
    END=$(date +%s)
    if [ $((END - START)) -lt 15 ]; then
        echo "io: Sitzung endete nach $((END - START))s, Shell statt Neustart."
        IO_LOG=$(ls -t /run/user/$(id -u)/io-log-*/current "$HOME"/.local/state/io/log-*/current 2> /dev/null | head -1)
        if [ -n "$IO_LOG" ]; then
            echo "io: letzte Meldungen aus $IO_LOG:"
            tail -n 20 "$IO_LOG"
        fi
        unset IO_LOG
    else
        exec io-start
    fi
fi
