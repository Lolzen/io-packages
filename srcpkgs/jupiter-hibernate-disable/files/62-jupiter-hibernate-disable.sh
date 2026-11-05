# Valve's jupiter-hibernate-disable (0.1): no hibernation on the Steam Deck.
# On Valve's Jupiter (LCD) and Galileo (OLED) elogind is told that
# hibernation, suspend-then-hibernate and hybrid sleep are not allowed, so
# nothing offers them; elsewhere the drop-in is removed. Sourced by runit's
# stage 1, before elogind starts: no exit here. The drop-in keeps Valve's
# name and sorts after Valve's steamos-suspend-then-hibernate.conf.
jupiter_nohibernate=/etc/elogind/sleep.conf.d/zz-holo-jupiter-nohibernate.conf
jupiter_vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)
jupiter_product=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
case "$jupiter_vendor:$jupiter_product" in
    Valve:Jupiter|Valve:Galileo)
        if [ ! -f "$jupiter_nohibernate" ]; then
            mkdir -p "${jupiter_nohibernate%/*}"
            printf '%s\n' "[Sleep]" "AllowHibernation=no" "AllowSuspendThenHibernate=no" "AllowHybridSleep=no" > "$jupiter_nohibernate"
        fi
        ;;
    *)
        rm -f "$jupiter_nohibernate"
        ;;
esac
unset jupiter_nohibernate jupiter_vendor jupiter_product
