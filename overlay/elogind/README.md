# elogind-holo

Replaces Void's `elogind`, `libelogind` and `elogind-devel`
(`libelogind-32bit` stays Void's).

No source patch: `template.append` changes the runit service only.

| Change | Source | Upstream |
|---|---|---|
| `SYSTEMD_BYPASS_HIBERNATION_MEMORY_CHECK=1` in `/etc/sv/elogind/run` | Valve's `systemd-logind.service.d/homedir-override.conf` (steamos-customizations-jupiter 20260827.2, SteamOS 3.9.2), which sets it for systemd-logind | an environment variable logind reads; elogind 252 reads it as well |

Why: logind only offers hibernation (CanHibernate,
CanSuspendThenHibernate) when the active swap can hold the memory in use.
On SteamOS 3.9.2, and on Io with `steamos-tuning` 1.5, the swap file for the
image is created only when hibernating (Valve's `hibernate-swap-helper.sh`),
so before that only the 1 GiB swap file is there and the check would always
fail. Valve skips the check with this variable; Io does the same. Where Io
may not hibernate (not on the internal NVMe), `61-io-hibernate-guard.sh`
switches hibernation off in elogind's configuration, so the variable changes
nothing there.

How: Void's run script ends with `exec /usr/libexec/elogind/elogind.wrapper`
and runit starts services with an empty environment, so the variable is set
in the run script. Void's `post_install` is kept as it is (copied under
another name with `declare -f`) and the run script is changed after it; the
build fails if the line is not found.

Way back: none planned, as long as Io hibernates like SteamOS. Without
hibernation, remove this overlay and switch `io-desktop` and
`deck-hw-support` back to `elogind`; an Io package must then replace
`elogind-holo`, `libelogind-holo` and `elogind-devel-holo`.
