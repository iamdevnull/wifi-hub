# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

Debugging and integration testing tools for the Atheros AR9170 (carl9170) USB WiFi driver ecosystem. Part of a 4-project ecosystem:

- **carl9170-driver** (`~/WebstormProjects/carl9170-driver/`) — Linux kernel driver patches
- **carl9170fw-custom** (`~/WebstormProjects/carl9170fw-custom/`) — Firmware (SH-2 cross-compiled)
- **linux-wifi-analyzer** (`~/WebstormProjects/linux-wifi-analyzer/`) — WiFi analyzer TUI (fork of wavemon, full rewrite)
- **wifi-central** (this repo) — Debug tooling and integration

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

## Project-Specific Rules

### Repo Boundaries

- wifi-central is for debug tooling and integration ONLY — no UI code, no driver code, no firmware code
- All code changes go into the repo that owns them: linux-wifi-analyzer, carl9170-driver, or carl9170fw-custom

### Kernel Build Targets

- **Local builds** (module compilation, testing, loading): build against local kernel headers matching `uname -r`
- **Upstream patches** (for `git send-email`): generate against current mainline HEAD via `git sparse-checkout`
- Never mix: don't build local modules from mainline source, don't submit patches based on local kernel source

### Upstream Kernel Patches

- Generate against current mainline HEAD
- Validate with `checkpatch.pl --strict` — must be 0 errors/warnings/checks
- Verify patches apply cleanly to mainline source
- Send via `git send-email` to maintainer + mailing list
- Fallback for carl9170: Christian Lamparter `<chunkeey@googlemail.com>` + `linux-wireless@vger.kernel.org`
- `send-upstream` alias: 1. checkpatch 2. verify apply 3. get_maintainer.pl 4. summary + confirm 5. git send-email

### Health Check (loadmyenv)

After every driver/firmware/module load, scan dmesg for ALL WiFi errors filtered by current PHY:

```bash
PHY=$(basename $(ls -d /sys/class/ieee80211/phy* 2>/dev/null | tail -1) 2>/dev/null)
dmesg | grep -iE "ieee80211|carl9170|ath|wlan[0-9]|usb.*3-7|$PHY" | \
  grep -iE 'error|fail|timeout|crash|bug|panic|restart|reset|refused|denied|-110|-71|-5' | \
  grep "$PHY" | tail -20
```

Also check: interface exists, NM connection status, no crashes in current PHY.

### Build Cycle (driver/firmware projects)

**build → install → load → health check → test → verify**

1. Build: `bash -x build.sh --prepare --build`
2. Install: `--install`
3. Load: `--load`
4. Health check: interface exists, connected, no dmesg errors on current PHY
5. Test: run test suite
6. Verify: check logs, version, behavior

If health check fails after a new patch: **revert immediately**.

### Patch Creation (driver projects)

Every new bugfix patch MUST follow: get clean baseline → save baseline files → apply change to copy → generate diff against baseline → verify applies cleanly → write patch with git-format header → full cycle rebuild.
