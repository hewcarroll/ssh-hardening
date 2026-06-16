#!/usr/bin/env bash
# Remove the SSH hardening drop-in and re-validate the remaining sshd config.
#
# Usage: sudo ./uninstall.sh

set -euo pipefail

DEST=/etc/ssh/sshd_config.d/50-hardening.conf

if [ "$(id -u)" -ne 0 ]; then
    echo "error: run as root (sudo ./uninstall.sh)" >&2
    exit 1
fi

SSHD="$(command -v sshd || true)"
if [ -z "$SSHD" ]; then
    for c in /usr/sbin/sshd /sbin/sshd /usr/local/sbin/sshd; do
        if [ -x "$c" ]; then SSHD="$c"; break; fi
    done
fi

if [ ! -e "$DEST" ]; then
    echo "nothing to do: $DEST is not present"
    exit 0
fi

rm -f "$DEST"
echo "removed $DEST"

if [ -n "$SSHD" ] && [ -x "$SSHD" ] && ! "$SSHD" -t; then
    echo "warning: 'sshd -t' reports a problem in the REMAINING config" >&2
    echo "         (unrelated to this drop-in) — review before reloading." >&2
fi

UNIT=ssh
if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files 2>/dev/null | grep -q '^sshd\.service'; then
    UNIT=sshd
fi
echo "Reload to apply the removal:  systemctl reload $UNIT"
