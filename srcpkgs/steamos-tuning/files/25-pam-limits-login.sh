#!/bin/sh
# steamos-tuning's Proton nice ceiling (/etc/security/limits.d) needs
# pam_limits.so in the login PAM chain to actually be applied. Void's
# default /etc/pam.d/login doesn't include it (its system-local-login
# chain lacks it, unlike system-auth) - confirmed via prlimit showing
# HARD: 0 instead of 28 on the game-mode session without this.
grep -q "pam_limits.so" /etc/pam.d/login 2>/dev/null || \
    printf 'session\t\toptional\tpam_limits.so\n' >> /etc/pam.d/login
true