#!/bin/sh
for f in /sys/class/dmi/id/product_serial /sys/class/dmi/id/board_serial; do
    [ -e "$f" ] && chmod 440 "$f" && chgrp wheel "$f"
done
true