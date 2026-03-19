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

- wifi-hub is for debug tooling and integration ONLY — no UI code, no driver code, no firmware code
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

### Patch Creation Workflow (MANDATORY)

Every new bugfix patch MUST follow this exact sequence:

```bash
# 1. Get clean baseline (all EXISTING patches applied, NOT the new one)
bash -x build.sh --prepare
# Result: build dir has source with N existing patches

# 2. Save baseline files you will modify
cp <build-dir>/<path>/file.c /tmp/file_base.c

# 3. Apply ONLY your change to a copy
cp /tmp/file_base.c /tmp/file_new.c
# Edit /tmp/file_new.c with your fix

# 4. Generate diff against baseline copy (NOT against /usr/local/src/)
diff -up /tmp/file_base.c /tmp/file_new.c | \
  sed 's|file_base.c|a/<path>/file.c|; s|file_new.c|b/<path>/file.c|' \
  > /tmp/my_patch.diff

# 5. Verify patch applies to clean baseline
cd <build-dir>/
patch -p1 --dry-run < /tmp/my_patch.diff
# or: git apply --check /tmp/my_patch.diff
# MUST print "APPLIES CLEANLY"

# 6. Write patch file with git-format header
cat > patches/<type>/NNNN-description.patch << 'EOF'
From 0000000000000000000000000000000000000000 Mon Sep 17 00:00:00 2001
From: ...
Subject: ...

<commit message body explaining WHY>

Signed-off-by: ...
---
 <diffstat>
EOF
cat /tmp/my_patch.diff >> patches/<type>/NNNN-description.patch

# 7. Verify full cycle
bash -x build.sh --prepare  # Must show N+1 patches applied
bash -x build.sh --build    # Must compile clean, 0 errors
bash -x build.sh --install --load  # Must load
# Health check: interface exists, connected, no crashes
```

### NEVER do this:
- `diff <build-dir>/file.c /usr/local/src/.../file.c` — `/usr/local/src/` has ALL your direct edits including unrelated changes from other patches
- Edit `/usr/local/src/` and expect build.sh to pick it up — it extracts fresh from tarball/git + applies .patch files only
- Generate one diff covering multiple unrelated patches — each patch must be a single logical change
- Write patches without git-format header (From, Subject, Signed-off-by)

### Dual Build Mode (Local + Upstream)

**Local mode** (default) — build + run:
- Patches in `patches/bugfix/` applied on top of local kernel source
- Built against `uname -r` headers
- Command: `bash -x build.sh --prepare --build --install --load`

**Upstream mode** — validate only (no build):
- Patches in `patches/upstream/` validated against mainline HEAD
- Fetched via `build.sh --rebase` (HTTP from git.kernel.org)
- Validated with `checkpatch.pl --strict`
- Not built — mainline may use APIs not in local kernel
- Sent via `git send-email`

**Never mix:** bugfix/ patches use local kernel baseline, upstream/ patches use mainline HEAD. A bugfix patch will NOT apply to mainline and vice versa.
