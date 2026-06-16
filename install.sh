#!/usr/bin/env bash
# Install the SSH hardening drop-in, with lockout preflight and validation.
#
# Usage: sudo ./install.sh [--force]
#   --force : skip the authorized_keys lockout preflight (only if you are
#             certain you already have working key-based access).
#
# WARNING: this enforces keys-only authentication. Ensure the account you log in
# as has a working ~/.ssh/authorized_keys entry BEFORE reloading sshd, or you
# may lock yourself out. Keep a second session open while you test.

set -euo pipefail

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/50-hardening.conf"
DEST=/etc/ssh/sshd_config.d/50-hardening.conf
MAIN_CFG=/etc/ssh/sshd_config

if [ "$(id -u)" -ne 0 ]; then
    echo "error: run as root (sudo ./install.sh)" >&2
    exit 1
fi

# Resolve the sshd binary by absolute path: it normally lives in /usr/sbin,
# which is often not on root's PATH under sudo/cron/containers.
SSHD="$(command -v sshd || true)"
if [ -z "$SSHD" ]; then
    for c in /usr/sbin/sshd /sbin/sshd /usr/local/sbin/sshd; do
        if [ -x "$c" ]; then SSHD="$c"; break; fi
    done
fi
if [ -z "$SSHD" ] || [ ! -x "$SSHD" ]; then
    echo "error: sshd binary not found — is the OpenSSH server installed?" >&2
    exit 1
fi

# Preflight 1: the drop-in only works if sshd_config Includes the directory
# (added in OpenSSH 8.2). Without it this file is silently ignored, while
# 'sshd -t' still passes — a false sense of security.
if ! grep -Eq '^[[:space:]]*Include[[:space:]]+.*sshd_config\.d' "$MAIN_CFG"; then
    echo "error: $MAIN_CFG has no 'Include .../sshd_config.d/*.conf' line." >&2
    echo "       This drop-in would be IGNORED. Add the Include near the TOP of" >&2
    echo "       $MAIN_CFG (requires OpenSSH >= 8.2), then re-run." >&2
    exit 1
fi

# Preflight 2: keys-only lockout guard. Identify the human admin (the sudo
# invoker) and require a non-empty authorized_keys before enforcing keys-only.
if [ "$FORCE" -ne 1 ]; then
    ADMIN_USER="${SUDO_USER:-}"
    if [ -z "$ADMIN_USER" ] || [ "$ADMIN_USER" = root ]; then
        if ! awk -F: '$3>=1000 && $3<65534 {found=1} END{exit !found}' /etc/passwd; then
            echo "warning: root appears to be the only login account. The shipped" >&2
            echo "         config uses 'PermitRootLogin prohibit-password', so" >&2
            echo "         key-based root still works. If you switch it to 'no'," >&2
            echo "         create a key-capable sudo account first." >&2
        fi
        if [ ! -s /root/.ssh/authorized_keys ] && [ ! -s /root/.ssh/authorized_keys2 ]; then
            echo "error: no non-root admin identified and /root/.ssh/authorized_keys" >&2
            echo "       is missing/empty. Installing keys-only auth could lock you" >&2
            echo "       out. Add a key first, or re-run with --force." >&2
            exit 1
        fi
    else
        ADMIN_HOME="$(getent passwd "$ADMIN_USER" | cut -d: -f6)"
        if [ ! -s "$ADMIN_HOME/.ssh/authorized_keys" ] && [ ! -s "$ADMIN_HOME/.ssh/authorized_keys2" ]; then
            echo "error: $ADMIN_USER has no non-empty ~/.ssh/authorized_keys." >&2
            echo "       Installing keys-only auth would lock you out. Add a key" >&2
            echo "       first, or re-run with --force." >&2
            exit 1
        fi
    fi
fi

# Back up an existing drop-in so a failed validation rolls back cleanly.
BACKUP=""
if [ -e "$DEST" ]; then
    BACKUP="$DEST.bak.$$"
    cp -a "$DEST" "$BACKUP"
fi

install -Dm644 "$SRC" "$DEST"
echo "installed $DEST"

# Validate syntax; on failure restore the previous file (or remove ours).
if ! "$SSHD" -t; then
    echo "error: sshd config test failed — reverting." >&2
    if [ -n "$BACKUP" ]; then mv -f "$BACKUP" "$DEST"; else rm -f "$DEST"; fi
    exit 1
fi
[ -n "$BACKUP" ] && rm -f "$BACKUP"

# Assert the hardening is actually live (catches a lexically-earlier file that
# wins under first-value-wins, e.g. 50-cloud-init.conf on Ubuntu images).
if eff="$("$SSHD" -T 2>/dev/null)"; then
    for kv in "passwordauthentication no" "kbdinteractiveauthentication no"; do
        if ! printf '%s\n' "$eff" | grep -qix "$kv"; then
            echo "WARNING: effective config does NOT honor '$kv' — an earlier file or" >&2
            echo "         line wins (e.g. 50-cloud-init.conf). Hardening NOT fully applied." >&2
        fi
    done
fi

# Choose the correct service unit for the reload hint (ssh on Debian/Ubuntu,
# sshd on RHEL/Fedora/Arch/SUSE).
UNIT=ssh
if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files 2>/dev/null | grep -q '^sshd\.service'; then
    UNIT=sshd
fi

echo "sshd config valid."
echo "Reload to apply:  systemctl reload $UNIT"
echo "Keep your current session open and confirm a NEW login works before closing it."
