# Io

Ein Void-Linux-Nachbau von SteamOS für das Steam Deck. Ohne systemd.

Io ist ein Jupitermond und die vulkanisch aktivste Welt des Sonnensystems. Der
ausgeworfene Schwefel bildet einen Plasmaring um Jupiter, den Io-Torus. Daher
das Logo: ein Ring um einen Gasriesen, auf dem Ring der Mond, der ihn erzeugt.

> **Status:** funktionsfähiger Prototyp auf SD-Karte. Kernel, Audio, WLAN und
> der Steam Game Mode laufen. Autostart, Session-Umschaltung und ISO fehlen
> noch.

---

## Aufbau

| Paket | Inhalt |
|---|---|
| `linux-neptune` | Kernel 6.15.8 aus kernel.org-Tarball plus Valve-Patchset, Deck-Config-Fragment |
| `deck-firmware-cirrus` | CS35L41-DSP-Firmware, Mixer-Initialisierung |
| `io-base` | Repo-Konfiguration, Powerbutton, dracut-Snippet |
| `io-branding` | os-release, ASCII- und SVG-Logo, fastfetch-Konfiguration |
| `io-session` | Game-Mode-Startskripte, Steam-Kompatibilitäts-Stubs |
| `io-desktop` | Metapaket, bindet alles zusammen |

Der Kernel wird nicht als Fork gepflegt, sondern als Patch gegen den offiziellen
Tarball. Valves Delta liegt als eine Datei in `patches/`, das Config-Fragment
kommt unverändert aus dem jupiter-PKGBUILD-Mirror. Ein Versionssprung bedeutet
neuer Tag, neuer Patch, neues Fragment.

---

## Was funktioniert

- Boot auf dem Steam Deck LCD, korrekte Panel-Rotation
- Grafik über radv auf Van Gogh, gamescope direkt auf DRM
- Audio über beide CS35L41-Verstärker, Kopfhörer und internes Mikrofon
- WLAN über NetworkManager
- Suspend und Resume, inklusive Aufwecken über den Powerbutton
- Steam im Game Mode, Controller vollständig, Steam-Taste, Overlay
- Eigenes Branding in fastfetch und im Steam-Systemmenü

---

## Offen

### Kurzfristig

- [ ] Powerbutton mit Paketkonfiguration testen (`logind.conf.d` statt
      handgeänderter `handler.sh`); falls elogind das Verzeichnis nicht liest,
      auf `conf_files` für die Hauptdatei umstellen
- [ ] `deck-audio-init` klären: Ton funktioniert derzeit ohne den Dienst. Wenn
      beide Lautsprecher spielen, kann das Paket auf die reine Firmware
      reduziert werden
- [ ] Versionsnummer von `io-base` hochsetzen, damit Updates greifen

### Phase 4: Session

- [ ] Autologin auf tty1 plus automatischer Start des Game Mode
- [ ] `steamos-session-select` schreiben (wird von Steam beim Wechsel zum
      Desktop aufgerufen)
- [ ] Desktop-Sitzung testen — Plasma ist installiert, aber nie gestartet
- [ ] Rückweg aus dem Desktop in den Game Mode
- [ ] Umstellung von `-gamepadui` auf `-steamdeck -steamos3`, sobald die Stubs
      vollständig sind

### Hardware

- [ ] Lüftersteuerung (`jupiter-fan-control` als runit-Dienst); läuft aktuell
      nach BIOS-Kurve
- [ ] TDP und Ladelimit über `steamos-manager`; ohne ihn bleiben die
      zugehörigen Steam-Menüpunkte wirkungslos
- [ ] Gyro und Rückseitentasten über `inputplumber`
- [ ] Bildschirmaufnahme: `xdg-desktop-portal-wlr` scheitert im Game Mode,
      betrifft Screenshots und Streaming
- [ ] `CAP_SYS_NICE` für gamescope setzen; läuft derzeit mit normaler Priorität

### Infrastruktur

- [ ] Paketrepo signieren und als GitHub-Release veröffentlichen; die URL in
      `io-base` zeigt bisher ins Leere
- [ ] Wiki: Installation, bekannte Fallstricke, Kernel-Bump-Prozess
- [ ] GitHub Actions für automatische Builds (optional)
- [ ] ISO über `void-mklive`, sobald das Metapaket vollständig ist

### Größere Entscheidung

- [ ] Umzug auf die interne NVMe. Die SD-Karte ist für Spiele zu langsam und
      hat mehrfach Startprobleme durch Zeitüberschreitungen verursacht.

---

## Fallstricke

Dinge, die viel Zeit gekostet haben und nirgends dokumentiert sind.

**wireplumber nie manuell starten.** Void konfiguriert PipeWire so, dass es den
Session-Manager selbst startet, über einen Symlink in
`/etc/pipewire/pipewire.conf.d/`. Ein zusätzlich gestarteter wireplumber
erzeugt eine zweite Instanz. Die Folge sind ein `auto_null`-Sink statt der
echten Geräte und ein gamescope, das zwar läuft, aber kein Fenster anzeigt —
ohne jede brauchbare Fehlermeldung.

**`vk_xwayland_wait_ready=true`** vor gamescope setzen, wenn das System auf
langsamem Speicher läuft. Ohne die Variable startet Steam, bevor Xwayland
bereit ist.

**Steam nie mit `pkill -9` beenden.** Der Client hinterlässt einen Zustand, der
den nächsten Start lahmlegt. Die Datei `~/.local/share/Steam/.crash` zeigt an,
dass der letzte Lauf unsauber endete.

**Der CS35L41 braucht zwei Firmware-Dateien**, die nicht in Voids
`linux-firmware` stecken: `cs35l41-dsp1-spk-prot.wmfw` und
`cs35l41-dsp1-spk-prot-vlv1776.bin` aus `linux-firmware-neptune`. Ohne sie
bleibt ein Lautsprecher stumm.

**`force_drivers+=" amdgpu "` in der dracut-Konfiguration** ist zwingend. Ohne
das Modul im initramfs bleibt der Bildschirm beim frühen KMS schwarz.

---

## Quellen

- Kernel und Firmware: `gitlab.com/evlaV` (inoffizieller Mirror der
  SteamOS-Pakete)
- Config-Fragment: `jupiter-PKGBUILD/linux-neptune-615/config-neptune`
- Basis-Templates: `github.com/void-linux/void-packages`

## Lizenz

MIT für die eigenen Pakete. Firmware-Blobs und Valve-Patches unterliegen ihren
jeweiligen Lizenzen.