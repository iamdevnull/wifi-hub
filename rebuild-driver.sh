#!/usr/bin/env bash
set -Eeuo pipefail

# rebuild-driver.sh — Idempotent carl9170 driver rebuild after kernel upgrade.
# Run from wifi-hub or carl9170-driver. Safe to run anytime — skips if
# the installed module already matches the running kernel.

DRIVER_REPO="${DRIVER_REPO:-$(cd "$(dirname "$0")/../carl9170-driver" 2>/dev/null && pwd)}"
KVER="$(uname -r)"
MODULE_DIR="/lib/modules/${KVER}/kernel/drivers/net/wireless/ath/carl9170"

log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$1"; }

if [[ ! -f "$DRIVER_REPO/build.sh" ]]; then
    log "ERROR: carl9170-driver not found at $DRIVER_REPO"
    log "Set DRIVER_REPO= or ensure ../carl9170-driver/ exists relative to this script"
    exit 1
fi

# Idempotency: skip if module exists for running kernel and is loaded with matching srcversion
needs_rebuild() {
    if [[ ! -f "$MODULE_DIR/carl9170.ko" ]]; then
        log "No carl9170.ko for kernel $KVER — rebuild needed"
        return 0
    fi

    if ! grep -q "^carl9170 " /proc/modules 2>/dev/null; then
        log "carl9170.ko exists but not loaded — rebuild + load needed"
        return 0
    fi

    local vermagic
    vermagic="$(modinfo -F vermagic "$MODULE_DIR/carl9170.ko" 2>/dev/null || true)"
    if [[ "$vermagic" == "$KVER "* ]]; then
        log "carl9170 installed and loaded for kernel $KVER — nothing to do"
        return 1
    fi

    log "vermagic mismatch (got='$vermagic', want='$KVER ...') — rebuild needed"
    return 0
}

if ! needs_rebuild; then
    exit 0
fi

log "Rebuilding carl9170 for kernel $KVER"
bash -x "$DRIVER_REPO/build.sh" --deps --prepare --build --install --load --validate
log "Done — carl9170 rebuilt and loaded for kernel $KVER"
