# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- `50-hardening.conf`: idle-session reaping (`ClientAliveInterval`/
  `ClientAliveCountMax`), explicit `PubkeyAuthentication yes`, cross-distro
  defense-in-depth pins (`GSSAPIAuthentication`, `HostbasedAuthentication`,
  `IgnoreRhosts`, `IgnoreUserKnownHosts`, `PermitUserEnvironment`, `UsePAM`),
  connection-flood throttling (`MaxStartups`, optional `PerSource*`),
  `AllowAgentForwarding`/`GatewayPorts` pins, `Compression no`,
  `LogLevel VERBOSE`, and a commented `AllowGroups` allowlist template.
- `install.sh`: lockout preflight (requires a working `authorized_keys`, or
  `--force`), `Include`-directive preflight, absolute `sshd` path resolution,
  backup + rollback of an existing drop-in, effective-config assertion via
  `sshd -T`, and distro-aware reload hint.
- `uninstall.sh` to remove the drop-in and re-validate.
- GitHub Actions CI: shellcheck + containerized `sshd -t` + effective-config
  assertion.

### Changed
- `PermitRootLogin no` → `prohibit-password` (documented switch) so root-only
  VPS/cloud/headless images are not locked out.
- Corrected the drop-in precedence guidance in the config header and README:
  OpenSSH uses first-obtained-value-wins, so a **lower**-numbered file overrides
  this one (was incorrectly documented as higher-numbered).
- Honest comments noting the `Ciphers`/`KexAlgorithms` removal lines are no-ops
  on modern OpenSSH defaults; added a CVE-2024-6387 note on `LoginGraceTime`.
