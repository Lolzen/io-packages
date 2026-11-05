#!/bin/bash
# io-resume: resume from hibernation where Io's sleep hook (io-hibernate,
# steamos-tuning) wrote the image location, in the EFI variable
# IoHibernateLocation. Io's stand-in for systemd's
# systemd-hibernate-resume-generator, which SteamOS's initramfs runs.

check() {
    return 0
}

depends() {
    return 0
}

install() {
    inst_multiple -o cat tail sed sleep readlink mountpoint chattr
    inst_hook pre-mount 09 "$moddir/io-resume.sh"
}
