# Build The Vault Image

This repository ships a working Vault image build. Use these flows to download
official HashiCorp release artifacts, verify them, build the UBI 9 (`ubi-micro`)
image, and run the runtime hardening checks.

## End-To-End

```sh
make image
```

This runs:

1. `tools/build_app.sh` - downloads official Vault release zips, imports
   HashiCorp's published PGP key, verifies the signed SHA256SUMS file, verifies
   each archive SHA256, extracts the Vault binaries, and verifies each
   extracted-binary SHA256.
2. `tools/verify_app_shas.py` - checks the extracted binary SHA256 values
   against `examples/image-manifest.json`. Drift fails the build and prints
   both expected and actual digests so the manifest update is obvious.
3. `tools/build_image.sh` - renders the docker buildx flags from the manifest
   via `tools/generate_build_args.py`, then runs `docker buildx build` for
   `linux/amd64` and loads the result into the local Docker daemon for testing.
4. `tests/runtime-hardening.sh` - exports the rootfs of the built image and
   asserts no shell, no `dnf`/`microdnf`/`rpm`/`yum`/`curl`/`wget`, a preserved
   non-empty rpm database, a populated CA bundle at
   `/etc/pki/tls/certs/ca-bundle.crt`, no setuid or world-writable-without-sticky
   paths, a non-root runtime user, and the expected `/usr/local/bin/vault`
   entrypoint.

The local `--load` path is not an evidence path. Docker does not preserve
BuildKit SBOM attestations in the local image store, and the helper disables
BuildKit provenance explicitly. The push, SBOM/provenance, attestation, and
Cosign signing steps are performed by this repo's
[`publish-image.yaml`](../../.github/workflows/publish-image.yaml) release
workflow; see [`publish-image.md`](publish-image.md).

### Prepare Inputs

1. Pin the UBI 9 `ubi-minimal` builder image by digest in `base.builder`.
2. Pin the UBI 9 `ubi-micro` runtime image by digest in `base.runtime`.
3. Choose the `dnf.packages` installed into the runtime rootfs (at minimum
   `ca-certificates` for outbound TLS).
4. Choose the Vault version and record official release URLs, signed-checksum
   URLs, archive SHA256 values, and extracted-binary SHA256 values in the
   manifest.

Do not pass secrets through Docker build args. If a future build needs private
fetch credentials, use BuildKit secrets and keep them out of the final image and
provenance-visible build arguments.

### Build From The Manifest

The recommended pattern reads the build args from the manifest rather than
duplicating them:

```sh
# Single-platform build that loads the image into the local Docker daemon.
bash tools/build_image.sh examples/image-manifest.json ubi9-hashicorp-vault:dev linux/amd64
```

To bypass the helper and call docker buildx directly in a release workflow that
needs `--push`, multi-platform output, and BuildKit attestations:

```sh
mapfile -t buildargs < <(python tools/generate_build_args.py path/to/image-manifest.json)

docker buildx build \
  --file containers/Dockerfile \
  --tag ghcr.io/<owner>/<image>:<version> \
  "${buildargs[@]}" \
  --provenance=mode=max \
  --sbom=true \
  --push \
  .
```

`tools/generate_build_args.py` emits one token per line (alternating
`--build-arg` and `KEY=VALUE`) so that `mapfile -t` produces an array suitable
for `"${buildargs[@]}"` expansion without shell-quoting concerns. Use
`--format=json` instead when feeding values into a GitHub Actions matrix.

The Dockerfile selects the matching application artifact path and application
SHA256 based on `TARGETARCH`, and fails fast if the selected architecture's
value is empty or points outside the build context.

## Verify Runtime Hardening

```sh
tests/runtime-hardening.sh <image-ref>
```

The script exports the image filesystem and checks for forbidden runtime tools,
then verifies basic Vault operation under hardened Docker flags.
