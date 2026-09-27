# Io

A Void Linux rebuild of SteamOS for the Steam Deck (LCD, "Jupiter"), with
runit instead of systemd.

## Pages

- [Milestones](Milestones) — what is open, and where it is headed
- [Changelog](Changelog) — what each release brought
- [Deviations from SteamOS](Deviations) — where Io differs from SteamOS, and why
- [Architecture](Architecture) — boot, sessions, SteamOS Manager, logging
- [Packages](Packages) — every package, its contents and source
- [Kernel](Kernel) — source, configuration layers, what to do on a kernel update
- [Helper status](Helper-Status) — which of Valve's helper scripts are real
- [Building](Building) — building packages and images, release workflow
- [Pitfalls](Pitfalls) — things that cost real time and are documented nowhere else
- [SteamOS packages](Valve-Package-Survey) — every SteamOS-specific package, and what Io has in its place

## Principle

Io is checked against a reference capture of SteamOS 3.8.4 taken on the
same hardware: process environments, D-Bus values and calls, sysfs values,
configuration. Where Io matches SteamOS, the wiki does not repeat it. Where
it differs, [Deviations](Deviations) says why.
