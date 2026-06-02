# Quality Gates

These checks are only merge-blocking when the repository rulesets require their
reported status names. See [`governance.md`](governance.md) for the repository
settings that make the gates enforceable.

| Gate | Source | Role | Notes |
| --- | --- | --- | --- |
| Template verify | `python tools/verify.py ci` | Blocking | Checks docs layout, manifest contract, Dockerfile markers, runtime script coverage, compliance checklist consistency, Vault release artifact pinning, build-args generator, local build-helper boundaries, security caller workflows, the reusable image workflow, stale placeholders, local Markdown links, and documented workflow references. |
| actionlint | `.github/workflows/ci.yaml` | Blocking | Validates workflow syntax and common GitHub Actions mistakes. |
| markdownlint | `.github/workflows/ci.yaml` | Blocking | Keeps docs readable across this repository. |
| Image build + hardening | `.github/workflows/reusable-ubi-image-build.yaml` | Blocking | Downloads and verifies Vault artifacts, verifies extracted binary SHA256 against the manifest (`tools/verify_app_shas.py`), builds the UBI 9 (`ubi-micro`) image (`tools/build_image.sh`), and runs runtime hardening (`tests/runtime-hardening.sh`). |
| Runtime hardening | `tests/runtime-hardening.sh <image>` | Blocking | Runs against the freshly built Vault image, verifies forbidden runtime tools are absent, checks `vault version`, and starts a non-dev server under read-only/no-new-privileges/cap-drop hardening with tmpfs data. |
| CodeQL | `.github/workflows/codeql.yaml` | Blocking | Calls `nwarila-platform/.github/.github/workflows/reusable-codeql.yaml`. Scans `actions` and `python` because the repository ships executable workflow and tooling code. |
| Trivy + Gitleaks + zizmor | `.github/workflows/security.yaml` | Blocking | Calls `nwarila-platform/.github/.github/workflows/reusable-iac-security.yaml`. Trivy filesystem misconfig + secret scanning (HIGH/CRITICAL), Gitleaks full-history secret detection, zizmor GitHub Actions security analysis. SARIF uploaded to the Security tab. |
| OpenSSF Scorecard | `.github/workflows/scorecard.yaml` | Blocking | Calls `nwarila-platform/.github/.github/workflows/reusable-scorecard.yaml`. Repo-level supply-chain posture (branch protection, code review, pinned dependencies, signed releases, vulnerabilities). |
| Repo hygiene | `.github/workflows/repo-hygiene.yaml` | Blocking | Calls `nwarila-platform/.github/.github/workflows/reusable-repo-hygiene.yaml`. Enforces org workflow hygiene, including 40-character SHA pins and `pull_request_target` boundary safety. |
| Auto-merge for trusted bots | `.github/workflows/auto-merge.yaml` | Advisory | Calls `nwarila-platform/.github/.github/workflows/reusable-auto-merge.yaml`. Enables GitHub auto-merge on Renovate and Dependabot PRs once required checks pass; human-authored PRs are never auto-merged. The central reusable authorizes the PR author read-only before any write token is used. |
| BuildKit SBOM/provenance | `.github/workflows/publish-image.yaml` | Release | Emitted on the pushed image digest on `main` and `v*` pushes with `--sbom=true` and `--provenance=mode=max`. PR CI `--load` builds do not preserve attestations. |
| GitHub artifact attestations | `.github/workflows/publish-image.yaml` | Release | Attests the pushed image digest via `actions/attest-build-provenance` (push-to-registry) on `main` and `v*` pushes. See [`publish-image.md`](../how-to/publish-image.md). |
| Cosign signature | `.github/workflows/publish-image.yaml` | Release | Signs the image digest with keyless Cosign (`cosign sign`) on `main` and `v*` pushes. See [`publish-image.md`](../how-to/publish-image.md) for the keyless OIDC details. |

## Release vs. PR CI

PR CI builds the image with Docker's `--load` exporter for runtime testing only:
it does not push to a registry and does not keep SBOM, provenance, or
attestations (the local exporter strips them). The release path is
`.github/workflows/publish-image.yaml`, which on `main` and `v*` pushes builds
both declared platforms (`linux/amd64,linux/arm64`), pushes to `ghcr.io`, emits
the BuildKit SBOM (`--sbom=true`) and provenance (`--provenance=mode=max`),
attaches a GitHub artifact attestation (`actions/attest-build-provenance`,
push-to-registry), signs the digest with keyless Cosign (`cosign sign`), and
re-runs runtime hardening against the pushed image.

Deliberately scoped out:

- Multi-architecture runtime hardening in PR CI: the PR self-test is `amd64`-only
  because cross-platform assertions need QEMU and add CI time without changing
  the contract; the release workflow builds both declared platforms.
- Image CVE scanning of the published Vault binary: Vault is imported as a
  signature- and checksum-verified upstream release, so runtime CVE monitoring is
  a deployment concern for the platform consuming this image.
