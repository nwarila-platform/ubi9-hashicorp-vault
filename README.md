# ubi9-hashicorp-vault

Red Hat UBI 9 (`ubi-micro`) image repository for HashiCorp Vault. It downloads
official HashiCorp Vault release artifacts, verifies the signed checksum file,
verifies the archive and extracted binary hashes, and builds a minimal
`ubi-micro` runtime image whose root filesystem is assembled from digest-pinned
UBI 9 bases with `microdnf --installroot`.

The runtime is intentionally narrow: non-root user, no shell, no package
manager, no curl/wget, a populated CA trust store at
`/etc/pki/tls/certs/ca-bundle.crt` for outbound TLS, a preserved rpm database so
scanners enumerate the installed packages, read-only-rootfs compatibility,
dropped capabilities, and a tmpfs-only writable data path for the server.

## Prerequisites

The contract checks need only Python; the image lifecycle needs Docker:

- Python 3.12+
- Bash, for the build and runtime hardening scripts
- Docker Buildx, when building the image

## Quickstart

Run the contract checks (no Docker required):

```sh
python tools/verify.py ci
```

Build the Vault image end-to-end (Docker required):

```sh
make image
```

`make image` downloads and verifies the Vault release artifacts, verifies the
extracted binary SHA256 values against the committed manifest, generates the
docker buildx flags from the manifest, builds the UBI 9 (`ubi-micro`) image for
`linux/amd64`, and runs the runtime hardening assertions against it.

## Repository Layout

| Path | Role |
| --- | --- |
| [`contracts/image-manifest.schema.json`](contracts/image-manifest.schema.json) | Human-reviewable image manifest schema (v2: UBI 9 bases + dnf packages + Vault vendor artifacts). |
| [`examples/image-manifest.json`](examples/image-manifest.json) | Manifest with real pinned UBI 9 base digests and Vault release values. |
| [`examples/vault-server.hcl`](examples/vault-server.hcl) | Minimal non-dev server config used by the hardened runtime smoke test. |
| [`containers/Dockerfile`](containers/Dockerfile) | Three-stage UBI 9 pattern: `ubi-minimal` rootfs assembly with `microdnf --installroot`, `ubi-minimal` application stage that verifies the Vault binary, `ubi-micro` runtime. |
| [`.dockerignore`](.dockerignore) | Deny-all build-context baseline that only allows reviewed application artifacts by default. |
| [`tests/runtime-hardening.sh`](tests/runtime-hardening.sh) | Runtime assertion script for no shell, package manager, curl, or wget; preserved rpmdb; populated UBI CA bundle. |
| [`tools/verify.py`](tools/verify.py) | Local and CI contract checks. |
| [`docs/compliance/rhel-9-stig-v2r8-applicability.md`](docs/compliance/rhel-9-stig-v2r8-applicability.md) | Rule-by-rule DISA RHEL 9 STIG V2R8 image applicability checklist. |
| [`docs/compliance/cis-docker-image-applicability.md`](docs/compliance/cis-docker-image-applicability.md) | CIS Docker image-scope applicability checklist. |
| [`tools/generate_build_args.py`](tools/generate_build_args.py) | Render docker buildx flags from a reviewed manifest. |
| [`tools/build_app.sh`](tools/build_app.sh) | Download, signature-verify, and checksum-verify the upstream Vault release artifacts and extract the binaries. |
| [`tools/build_image.sh`](tools/build_image.sh) | Build the image from a manifest plus the rendered build args. |
| [`tools/verify_app_shas.py`](tools/verify_app_shas.py) | Verify built application binaries match the manifest's SHA256 values. |
| [`docs/`](docs/) | Diataxis documentation plus derivation, publishing, governance, and org/template/repo ADR scopes. |
| [`.github/workflows/`](.github/workflows/) | `ci.yaml` runs the contract checks and calls the image-build reusable; `codeql.yaml`, `scorecard.yaml`, `security.yaml`, and `repo-hygiene.yaml` call the canonical reusable workflows in `nwarila-platform/.github` for CodeQL, OpenSSF Scorecard, Trivy + Gitleaks + zizmor, and org repo hygiene. |
| [`.github/workflows/reusable-ubi-image-build.yaml`](.github/workflows/reusable-ubi-image-build.yaml) | Repository-specific reusable: build app binaries -> verify SHA256 -> build UBI 9 image -> run runtime hardening. |
| [`.github/workflows/publish-image.yaml`](.github/workflows/publish-image.yaml) | Main/tag/manual publish workflow: build app -> verify SHA256 -> BuildKit push with SBOM/provenance -> OpenSCAP RHEL 9 STIG + Trivy + Grype gates -> GitHub artifact attestation -> Cosign signature -> runtime hardening against the pushed digest. |

## What This Is, And What It Is Not

This is a leaf container-image repository derived from the UBI 9 application
template. It is not itself a template; nothing is meant to be derived from it.

| Property | This repository |
| --- | --- |
| Defines the UBI 9 image contract | Yes |
| Builds a working image end-to-end | Yes, with real Vault release artifacts |
| Pins UBI 9 base digests + dnf content | Real pins for the Vault image |
| Publishes SBOM, provenance, signatures, and attestations | Yes, through the main/tag/manual publish workflow |
| Contains Vault-specific logic | Yes |

This repository does not consume a shared mutable base image. It assembles its
own root filesystem from digest-pinned UBI 9 bases so review can trace the
builder image, runtime image, `dnf` package set, application artifact, and
runtime policy in one place.

## Normalized Repo Interface

| Command | Purpose |
| --- | --- |
| `make verify` | Run the local CI-equivalent contract checks. |
| `make build-args` | Render docker buildx flags from the manifest. |
| `make app-build` | Download, signature-check, checksum-check, and extract Vault artifacts. |
| `make app-verify` | Check extracted Vault binary SHA256 values against the manifest. |
| `make image-build` | Build the OCI image for `linux/amd64`. |
| `make image-test` | Run runtime hardening assertions against the built image. |
| `make image` | Run the full app -> image -> hardening pipeline. |

## Build Evidence Expectations

On pushes to `main` and `v*` tags, this repository publishes the image by digest
and attaches:

- BuildKit provenance with `--provenance=mode=max`.
- BuildKit SBOM attestations with `--sbom=true`.
- A GitHub artifact attestation for the pushed image digest. BuildKit carries
  the SBOM attestation.
- Cosign/Sigstore signatures on the image digest.
- Anonymous GHCR manifest access for the pushed digest, so package visibility
  drift fails during publish instead of later during cluster pulls.
- Runtime hardening evidence from `tests/runtime-hardening.sh`.

PR CI loads the image locally for runtime testing and explicitly disables local
provenance so the test path is not confused with release evidence. BuildKit
SBOM, BuildKit provenance, signing, and GitHub artifact attestations are emitted
by the [`.github/workflows/publish-image.yaml`](.github/workflows/publish-image.yaml)
release workflow. The detailed expectations live in
[`docs/reference/supply-chain-evidence.md`](docs/reference/supply-chain-evidence.md),
and [`docs/how-to/publish-image.md`](docs/how-to/publish-image.md) describes
the publish workflow that wires build + push, Cosign keyless signing,
GitHub artifact attestation upload, and runtime hardening against the pushed
digest around the manifest-driven pipeline.

## License

MIT - see [LICENSE](LICENSE).
