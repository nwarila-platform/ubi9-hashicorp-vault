# Testing Strategy

This repository builds and exercises a working Vault image so the manifest,
Dockerfile, generator, signed upstream artifact verification, and runtime
hardening assertions are proven together on every change.

## Contract Checks (`python tools/verify.py ci`)

Run on every push and PR; no Docker required. Validates:

- Diataxis and ADR directory layout.
- The committed image manifest in strict mode, plus an in-process check that the
  shared validator's permissive template mode still accepts `REPLACE_WITH_*`
  markers (a capability inherited from `NWarila/ubi9-application-template`).
- Dockerfile contract markers that protect the UBI 9 build pattern.
- The build-args generator: every Dockerfile ARG (other than runtime-only
  inputs) has a manifest source, and every generated arg has a matching
  Dockerfile ARG.
- The local image helper uses `--load` for runtime tests and disables
  provenance so it is not mistaken for the release evidence path.
- The Vault release artifacts come from official HashiCorp release URLs, and
  `tools/build_app.sh` verifies the signed SHA256SUMS file before extracting
  binaries.
- Runtime hardening script coverage for forbidden tools.
- Stale placeholder markers that indicate unfinished template text.
- Local Markdown links, so documentation cannot point at missing handoff or
  release guides.

## End-To-End Image Build (CI `image-build` job)

Runs on every push and PR; needs Docker. Proves the entire pipeline by:

1. Downloading official `vault_<version>_linux_<arch>.zip` artifacts.
2. Verifying the HashiCorp-signed SHA256SUMS file, each archive SHA256, and the
   extracted `dist/vault-{amd64,arm64}` binary SHA256 values.
3. Running `tools/verify_app_shas.py` to detect drift before the image build
   begins.
4. Generating docker buildx flags from the manifest via
   `tools/generate_build_args.py` (no hand-typed duplication).
5. Building and loading the OCI image for `linux/amd64`.
6. Running `tests/runtime-hardening.sh`, including `vault version` and a
   non-dev server startup under read-only/no-new-privileges/cap-drop hardening.

The PR CI image build uses Docker's `--load` path so the runtime tests can
inspect the image locally; that path does not push or keep attestations. BuildKit
SBOM and provenance attestations are emitted by this repo's `publish-image.yaml`
release workflow, where the image is pushed by digest and the registry can store
the attestation manifests.

Any future breakage in the Vault release pin chain, the UBI 9 base digest pins,
the Dockerfile, or the build helpers surfaces immediately as a CI failure.

## Release Path And Deployment Additions

This repository's `publish-image.yaml` release workflow already pushes the image
by digest, uploads a GitHub artifact attestation for the pushed digest and SBOM,
and Cosign-signs the image digest on `main` and `v*` pushes.

Beyond what this repository owns, a deployment platform consuming the image can
add:

- Production-grade image CVE scanning (Trivy/Grype) of the published image as a
  runtime/release gate.
- Environment promotion and admission-control policy.

## Non-Goals

This repository does not include fake or decorative tests. Every check in CI
exercises a real artifact or contract. Steps that depend on a registry
destination (push, sign, attest) run in this repo's `publish-image.yaml` release
workflow rather than in PR CI, which loads the image locally for runtime tests.
