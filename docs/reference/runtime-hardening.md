# Runtime Hardening

The runtime baseline is intentionally small and inspectable.

## Required Assertions

`tests/runtime-hardening.sh <image-ref> [expected-entrypoint]` checks that:

- The image config uses a non-root user.
- The entrypoint targets `/usr/local/bin/vault` (passed as the second argument).
- The CA bundle reachable from `/etc/pki/tls/certs/ca-bundle.crt` is present and
  populated (the UBI path; the Debian `/etc/ssl/certs/ca-certificates.crt` path
  does not exist on UBI).
- The rpm database under `/var/lib/rpm` is present and non-empty so scanners can
  enumerate the installed package set.
- `/bin/sh` and `/bin/bash` are absent.
- `dnf`, `microdnf`, `rpm`, `yum`, `curl`, and `wget` are absent.
- The regenerable `dnf` cache tree is absent (the rpmdb and dnf history are
  deliberately preserved).
- No setuid/setgid regular files and no world-writable-without-sticky
  directories exist.

The script inspects the image filesystem from `docker export` without extracting
it, so the check is identical on Linux CI runners and developer workstations. The
example non-dev server config in
[`../../examples/vault-server.hcl`](../../examples/vault-server.hcl) is provided
for operators who want to run the hardened server manually (read-only root
filesystem, all Linux capabilities dropped, no new privileges, and a
tmpfs-mounted `/vault/data` path).

## Operator Notes

The smoke-test config sets `disable_mlock = true` because the test drops all
Linux capabilities. Production deployments should either grant the memory-lock
capability needed by Vault and keep swap disabled on the host, or explicitly
accept and document the risk that secrets may be swapped by the node.

This image intentionally omits `tzdata`. Vault logs and audit records should be
treated as UTC unless a deployment adds and tests a time-zone database for a
specific local-time requirement.

## Application-Specific Extensions

This image's hardening can additionally assert Vault-specific properties, such as:

- Expected production listener ports and TLS configuration.
- Absence of unexpected interpreters or package managers introduced by extra
  `dnf` packages.
