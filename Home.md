# Io

A Void Linux rebuild of SteamOS for the Steam Deck (LCD, "Jupiter"), with
runit instead of systemd.

## Pages

- [Milestones](Milestones) — goals, work lists and final state of each milestone
- [Deviations from SteamOS](Deviations) — where Io differs from SteamOS, and why
- [Architecture](Architecture) — boot, sessions, SteamOS Manager, logging
- [Packages](Packages) — every package, its contents and source
- [Helper status](Helper-Status) — which of Valve's helper scripts are real
- [Building](Building) — building packages and images, release workflow
- [Pitfalls](Pitfalls) — things that cost real time and are documented nowhere else
- [Valve package survey](Valve-Package-Survey) — Valve's package catalogue, triaged for Io
- [Alpha 1](Alpha-1) — state at the first release

## Principle

Io is checked against a reference capture of SteamOS 3.8.4 taken on the
same hardware: process environments, D-Bus values and calls, sysfs values,
configuration. Where Io matches SteamOS, the wiki does not repeat it. Where
it differs, [Deviations](Deviations) says why.
