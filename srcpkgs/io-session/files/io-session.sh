# Io: Game Mode auf tty1 starten
if [ "$(tty)" = "/dev/tty1" ]; then
    START=$(date +%s)
    io-start
    END=$(date +%s)
    if [ $((END - START)) -lt 15 ]; then
        echo "io: Sitzung endete nach $((END - START))s, Shell statt Neustart."
    else
        exec io-start
    fi
fi