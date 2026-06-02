# Architecture

`ubi9-hashicorp-vault` is the downstream Red Hat UBI 9 image repository
for HashiCorp Vault. It consumes official HashiCorp Vault release artifacts,
verifies HashiCorp's signed checksum file, and assembles a minimal `ubi-micro`
runtime from digest-pinned UBI 9 bases.

## Repository Boundary

The repository owns:

- A manifest shape that records the UBI 9 base digests, `dnf` package set,
  application, runtime, and evidence inputs.
- A manifest-to-build-args generator so the manifest is the single review
  surface for buildx invocations.
- A Dockerfile for assembling a runtime rootfs with `microdnf --installroot`
  and building an `ubi-micro` final image.
- Official Vault release artifact download, signed-checksum verification,
  archive checksum verification, and extracted-binary checksum verification.
- Runtime hardening assertions that the Vault image must pass.
- Documentation for expected SBOM, provenance, signature, and attestation
  evidence.
- A CI workflow that builds the Vault image and runs the hardening checks
  against it on every push and pull request.

It does not own:

- A shared mutable base image.
- Promotion across environments or environment approval policy.

Registry publication, Cosign signing, and GitHub artifact attestation upload are
performed by this repo's `publish-image.yaml` release workflow on pushes to
`main` and `v*` tags.

## Build Flow

This repository's build has three layers:

1. **Input review.** The image manifest records the UBI 9 `ubi-minimal` builder
   and `ubi-micro` runtime base digests, the `dnf.packages` set, application
   Vault artifact URLs, archive checksums, extracted-binary checksums, runtime
   policy, and required evidence.
2. **Root filesystem construction.** The Dockerfile assembles the runtime rootfs
   from `ubi-minimal` with `microdnf install --installroot=/rootfs`, preserving
   the rpm database at `/var/lib/rpm`, and synthesizes the non-root account and
   `/vault` working directories.
3. **Runtime assembly.** The final image starts from `ubi-micro`, copies the
   rootfs and verified Vault binary, runs as `65532:65532`, and exposes only
   the Vault entrypoint.

## External Dependencies

- Red Hat UBI 9 `ubi-minimal` and `ubi-micro` base images and the RHEL 9 `dnf`
  repositories they resolve packages from.
- HashiCorp Vault releases, SHA256SUMS, SHA256SUMS.sig, and HashiCorp's
  published PGP key.
- Docker BuildKit and Buildx for SBOM and provenance attestations.
- GitHub Actions for CI and for the artifact attestations this repo's
  `publish-image.yaml` release workflow produces.
- Sigstore Cosign for image signatures.
