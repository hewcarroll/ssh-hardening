# ssh-hardening

A single, well-commented OpenSSH **drop-in** that applies sensible hardening
defaults without replacing your `sshd_config`: keys-only auth, no root login,
no empty passwords, capped auth attempts/sessions, forwarding off by default,
and weak KEX/cipher/MAC algorithms blacklisted.

It installs as `/etc/ssh/sshd_config.d/50-hardening.conf`. The `50-` prefix
loads it after the distro defaults but leaves room for your own machine-specific
overrides in a higher-numbered file (e.g. `99-local.conf`).

## Install

```sh
sudo ./install.sh          # copies the drop-in, runs `sshd -t`, then tells you to reload
sudo systemctl reload ssh
```

Or by hand:

```sh
sudo install -Dm644 50-hardening.conf /etc/ssh/sshd_config.d/50-hardening.conf
sudo sshd -t && sudo systemctl reload ssh
```

## ⚠️ Before you reload

This enforces **keys-only** authentication and disables root login. Make sure
you have a working `~/.ssh/authorized_keys` entry on the account you log in as
**before** reloading sshd — otherwise you can lock yourself out. Keep a second
session open while you test.

## What it sets

| Setting | Value | Why |
|---|---|---|
| `PasswordAuthentication` / `PermitEmptyPasswords` | `no` | keys only |
| `PermitRootLogin` | `no` | no direct root |
| `MaxAuthTries` / `MaxSessions` / `LoginGraceTime` | `3` / `10` / `30` | limit brute-force surface |
| `AllowTcpForwarding` / `X11Forwarding` / `PermitTunnel` | `no` | least privilege; enable per-host |
| `KexAlgorithms` / `Ciphers` / `MACs` | weak ones removed | drop SHA-1 / CBC / legacy DH |

Review and adjust for your environment before deploying widely.

## License

Dual-licensed under [MIT](LICENSE-MIT) or [Apache-2.0](LICENSE-APACHE) at your option.
