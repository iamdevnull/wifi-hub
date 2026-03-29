# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

Debugging and integration testing tools for the Atheros AR9170 (carl9170) USB WiFi driver ecosystem. Part of a 4-project ecosystem:

- **carl9170-driver** (`~/WebstormProjects/carl9170-driver/`) — Linux kernel driver patches
- **carl9170fw-custom** (`~/WebstormProjects/carl9170fw-custom/`) — Firmware (SH-2 cross-compiled)
- **linux-wifi-analyzer** (`~/WebstormProjects/linux-wifi-analyzer/`) — WiFi analyzer TUI (fork of wavemon, full rewrite)
- **wifi-hub** (this repo) — Debug tooling and integration

## 360° Ecosystem View

This hub exists to work across all 4 repos with a holistic view. Every change — driver patch, firmware fix, analyzer feature, or debug script — must be considered from the full-stack perspective:

- **Driver change?** → Does the firmware need to match? Does the analyzer display it? Does the hub need a new test?
- **Firmware change?** → Does the driver expect the old behavior? Does dmesg output change? Does the analyzer parse it?
- **Analyzer change?** → Does it rely on driver/firmware features that might not be present? Does the help screen match?
- **Bug found?** → Which layer owns the fix? Trace from hardware → firmware → driver → mac80211 → analyzer before deciding.

Never work in isolation. Always ask: "What does this change mean for the other 3 repos?"

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

## Conventions

- **Bash scripts**: `set -Eeuo pipefail`, ShellCheck-clean, `timeout` on all external tool calls
- **Tests**: Run with `bash -x` during development; max 30s timeout per script

## Related Project Commands

```bash
# Driver: build and test
cd ~/WebstormProjects/carl9170-driver
bash -x build.sh --deps --prepare --build --install --load
bash -x test.sh

# Firmware: build and validate
cd ~/WebstormProjects/carl9170fw-custom
bash -x build.sh --prepare --build --install --load --validate

# linux-wifi-analyzer: build (add --deb for .deb package)
cd ~/WebstormProjects/linux-wifi-analyzer
bash -x build.sh
```

## Hardware Target

Atheros AR9170 USB WiFi chipset (e.g., Fritz!WLAN N). Driver unmaintained since 2016; this ecosystem updates it to ratified 802.11n (Sept 2009) and fixes stability issues.

## Project-Specific Rules

### Repo Boundaries

- wifi-hub is for debug tooling and integration ONLY — no UI code, no driver code, no firmware code
- All code changes go into the repo that owns them: linux-wifi-analyzer, carl9170-driver, or carl9170fw-custom
