# Building

Io wird als Disk-Image gebaut, nicht als Live-ISO — die ISO-Route ist wegen
einer dracut/void-mklive-Versionsinkompatibilität aktuell blockiert.

## Voraussetzungen
- xbps-src-Umgebung (void-packages, gee-Fork)
- io-packages geklont neben void-packages

## Ablauf
1. Pakete bauen: `cd void-packages && ./xbps-src pkg <paket>`
2. Veröffentlichen: `~/io-packages/publish.sh [paket]`
3. Abbild bauen: `sudo ~/io-packages/mkimg.sh`
4. Auf Karte schreiben: `sudo dd if=io.img of=/dev/sdX bs=4M status=progress conv=fsync`