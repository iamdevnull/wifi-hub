# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

Debugging and integration testing tools for the Atheros AR9170 (carl9170) USB WiFi driver ecosystem. Part of a 4-project ecosystem:

- **carl9170-driver** (`~/WebstormProjects/carl9170-driver/`) — Linux kernel driver patches
- **carl9170fw-custom** (`~/WebstormProjects/carl9170fw-custom/`) — Firmware (SH-2 cross-compiled)
- **linux-wifi-analyzer** (`~/WebstormProjects/linux-wifi-analyzer/`) — WiFi analyzer TUI (fork of wavemon, full rewrite)
- **wavemon-carl9170-debug** (this repo) — Debug tooling and integration

## Architecture

```
AR9170 USB WiFi Hardware
  ↕ USB
Firmware (SH-2 processor) ← carl9170fw-custom patches
  ↕
carl9170 Linux kernel driver ← carl9170-driver patches
  ↕
mac80211 WiFi stack
  ↕
linux-wifi-analyzer ← fork of wavemon
```

## Languages & Build

| Component | Language | Build |
|-----------|----------|-------|
| Debug/test scripts | Bash | `bash -x script.sh` (always `-x` during development) |
| C tools | C | kernel-style Makefile or gcc directly |

## Conventions

- **C code**: Linux kernel coding style — tabs, 80-column lines, validate with `checkpatch.pl`
- **Bash scripts**: `set -Eeuo pipefail`, ShellCheck-clean, `timeout` on all external tool calls
- **Tests**: Run with `bash -x` during development; max 30s timeout per script
- **Driver module builds**: Against local kernel headers matching `uname -r`
- **Upstream patches**: Against current mainline HEAD via `git sparse-checkout`

## Related Project Commands

```bash
# Driver: build and test
cd ~/WebstormProjects/carl9170-driver
bash -x build.sh --deps --prepare --build --install
bash -x test.sh

# Firmware: build and validate
cd ~/WebstormProjects/carl9170fw-custom
bash -x build.sh --build --install --load --validate

# linux-wifi-analyzer: build
cd ~/WebstormProjects/linux-wifi-analyzer
bash -x build.sh
```

## Hardware Target

Atheros AR9170 USB WiFi chipset (e.g., Fritz!WLAN N). Driver unmaintained since 2016; this ecosystem updates it to ratified 802.11n (Sept 2009) and fixes stability issues.
