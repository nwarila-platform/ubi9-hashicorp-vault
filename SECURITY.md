# Security Policy

## Reporting a vulnerability

**Do not file public issues for security vulnerabilities.**

### Preferred: GitHub private vulnerability reporting

Use [GitHub's private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
on this repository's **Security** tab to report a vulnerability directly to the
maintainers.

### Fallback contact

If private vulnerability reporting is unavailable, contact the maintainer through
their [GitHub profile](https://github.com/NWarila).

## What to include

- Description of the vulnerability
- Steps to reproduce or a proof of concept
- The affected component (image build, manifest, workflow, or runtime contract)
  and the image tag/digest if known
- Potential impact

## Response timeline

| Stage | Target |
|-------|--------|
| Initial acknowledgement | 7 business days |
| Validation | 14 days |
| Remediation or mitigation | 90 days when reasonable |

These are targets, not guarantees. Complex issues may take longer; you will be
kept informed of progress.

## Scope

This repository packages the **official, signature- and checksum-verified upstream
HashiCorp Vault release** into a minimal Red Hat UBI 9 (`ubi-micro`) runtime image.
It does not modify the Vault binary.

### In scope

- The image build and packaging maintained here: `containers/Dockerfile`, the
  UBI 9 base digest pins and `dnf` package selection in
  `examples/image-manifest.json`, the download and GPG/SHA256 verification logic
  in `tools/`, the runtime-hardening contract in `tests/runtime-hardening.sh`, and
  the supply-chain evidence (SBOM, provenance, attestation, Cosign signature)
  emitted by `.github/workflows/publish-image.yaml`.
- Misconfigurations in this repository's GitHub Actions workflows that could lead
  to secret exposure or privilege escalation.

### Out of scope

- Vulnerabilities in **HashiCorp Vault itself** — report those upstream to
  [HashiCorp](https://www.hashicorp.com/security). This image carries the
  unmodified upstream release.
- Vulnerabilities in other third-party dependencies that should be reported
  upstream.
- Denial-of-service and social-engineering reports.

## Supported versions

Unless documented otherwise, only the most recent image published from the
default branch (and the latest `v*` release tag) is supported.

## Coordinated disclosure

We follow coordinated disclosure. Please give us reasonable time to investigate
and remediate before public disclosure, act in good faith, and do not access or
modify data that is not yours. We will credit reporters of valid vulnerabilities
unless they prefer to remain anonymous.
