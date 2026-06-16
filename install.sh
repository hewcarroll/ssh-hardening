#!/usr/bin/env bash
# Install the SSH hardening drop-in, validating before you reload sshd.
#
# Usage: sudo ./install.sh
#
# WARNING: this enforces keys-only authentication. Ensure you have a working
# authorized_keys entry BEFORE reloading sshd, or you may lock yourself out.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/50-hardening.conf"
DEST=/etc/ssh/sshd_config.d/50-hardening.conf

if [ "$(id -u)" -ne 0 ]; then
    echo "error: run as root (sudo ./install.sh)" >&2
    exit 1
fi

install -Dm644 "$SRC" "$DEST"
echo "installed $DEST"

if sshd -t; then
    echo "sshd config valid. Reload with: systemctl reload ssh"
else
    echo "error: sshd config test failed — removing drop-in" >&2
    rm -f "$DEST"
    exit 1
fi
