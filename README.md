# ssh-hardening

A single, well-commented OpenSSH **drop-in** that applies sensible hardening
defaults without replacing your `sshd_config`: keys-only auth, root login
restricted, no empty passwords, capped auth attempts/sessions, idle-session
reaping, forwarding off by default, legacy trust/GSSAPI/rhosts vectors disabled,
verbose auth logging, and weak KEX/cipher/MAC algorithms pruned.

It installs as `/etc/ssh/sshd_config.d/50-hardening.conf`.

## Prerequisite

This drop-in only takes effect if your main `sshd_config` **includes** the
drop-in directory (the `Include` directive was added in **OpenSSH 8.2**).
Debian/Ubuntu ship this near the top of `sshd_config` by default. Check:

```sh
grep -E '^[[:space:]]*Include[[:space:]]+.*sshd_config\.d' /etc/ssh/sshd_config
```

If there's no match, add `Include /etc/ssh/sshd_config.d/*.conf` near the **top**
of `/etc/ssh/sshd_config` first — otherwise the file is silently ignored and
`sshd -t` will still pass. `install.sh` checks this for you.

## Install

```sh
sudo ./install.sh          # preflight (key + Include), copy, `sshd -t`, then reload hint
sudo systemctl reload ssh  # Debian/Ubuntu; use `sshd` on RHEL/Fedora/Arch/SUSE
```

`install.sh` refuses to proceed if it can't find a working `authorized_keys`
for the invoking admin (pass `--force` to override). Or install by hand:

```sh
sudo install -Dm644 50-hardening.conf /etc/ssh/sshd_config.d/50-hardening.conf
sudo sshd -t && sudo systemctl reload ssh
```

Remove it with `sudo ./uninstall.sh`.

## ⚠️ Before you reload

This enforces **keys-only** authentication. Make sure the account you log in as
has a working `~/.ssh/authorized_keys` **before** reloading sshd — otherwise you
can lock yourself out. Keep a second session open and test a new login first.

Root login defaults to **`prohibit-password`** (key-based root still works,
password root is blocked) so root-only VPS/cloud/headless images aren't locked
out. Switch to `PermitRootLogin no` only once a separate, key-capable sudo
account is in place and tested.

## Verify it actually took effect

`sshd -t` only checks **syntax** — it does not prove the drop-in was read or
that its values win. Confirm the *effective* config:

```sh
sudo sshd -T | grep -Ei 'passwordauthentication|permitrootlogin|maxauthtries|x11forwarding'
```

(OpenSSH uses the **first** obtained value for most keywords. Because the
`Include` is near the top and drop-ins load in lexical order, a
**lower-numbered** file wins. On some Ubuntu cloud images `50-cloud-init.conf`
sorts before this file and can re-enable password auth — `sshd -T` reveals it,
and `install.sh` warns about it.)

## Override / customize

To change anything here, use a **lower-numbered** file (e.g.
`/etc/ssh/sshd_config.d/10-local.conf`) — *not* a higher-numbered one (first
value wins). To re-enable forwarding for specific users, use a `Match` block:

```
Match Group tunnel-users
    AllowTcpForwarding yes
```

## What it sets

| Setting | Value | Why |
|---|---|---|
| `PubkeyAuthentication` | `yes` | assert keys-only intent explicitly |
| `PasswordAuthentication` / `KbdInteractiveAuthentication` / `PermitEmptyPasswords` | `no` | keys only |
| `PermitRootLogin` | `prohibit-password` | key root OK, no password root (won't lock out root-only hosts) |
| `GSSAPIAuthentication` / `HostbasedAuthentication` / `IgnoreRhosts` / `PermitUserEnvironment` | hardened | disable legacy trust/env vectors (esp. on RHEL) |
| `MaxAuthTries` / `MaxSessions` / `MaxStartups` | `3` / `10` / `10:30:60` | limit brute-force & connection-flood surface |
| `ClientAliveInterval` / `ClientAliveCountMax` | `300` / `2` | reap idle/dead sessions (~600s) |
| `AllowTcpForwarding` / `AllowAgentForwarding` / `X11Forwarding` / `PermitTunnel` | `no` | least privilege; re-enable per-user via `Match` |
| `LogLevel` | `VERBOSE` | log the key fingerprint used for each login |
| `KexAlgorithms` / `Ciphers` / `MACs` | weak ones removed | drop SHA-1 / CBC / legacy DH (the cipher/kex lines are no-ops on modern defaults — belt-and-suspenders for old OpenSSH) |

## Caveats

- **Agent key offers:** `MaxAuthTries 3` also caps how many keys an agent offers
  before disconnect. If you load many keys, use `IdentitiesOnly yes` client-side.
- **Forwarding off** breaks `ssh -L/-R/-D` tunnels, `ProxyJump` bastions, DB
  tunnels, and some IDE remote features — re-enable per-user with `Match`.
- **Config-only:** this hardens `sshd` settings; it is not a firewall, fail2ban,
  or port change. Pair it with those.
- **CVE-2024-6387 (regreSSHion):** a non-zero `LoginGraceTime` does **not**
  mitigate it. Patch OpenSSH (≥ 9.8p1); `LoginGraceTime 0` is only a stopgap.

## Compatibility

Validated on Debian/Ubuntu with OpenSSH 8.x–9.x. The `Include` mechanism needs
OpenSSH ≥ 8.2 and the `-`/`^` algorithm-list modifiers need ≥ 7.8. Pruning
CBC/SHA-1/legacy-DH can lock out legacy or embedded clients — test every client
type before a fleet rollout.

## License

Dual-licensed under [MIT](LICENSE-MIT) or [Apache-2.0](LICENSE-APACHE) at your option.
