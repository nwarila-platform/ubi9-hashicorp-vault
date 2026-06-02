# Publish The Vault Image

This repository publishes the Vault image and its evidence from
[`.github/workflows/publish-image.yaml`](../../.github/workflows/publish-image.yaml).
Keep the local `make image` flow for fast runtime checks; the publish flow
produces digest evidence on `main` and `v*` pushes.

## Release Contract

The release job does the following:

1. Download and signature- and checksum-verify the upstream Vault release
   artifacts against the reviewed manifest.
2. Build and push the image by digest with BuildKit SBOM and provenance
   enabled.
3. Generate a GitHub artifact attestation for the pushed image digest.
4. Sign the pushed digest with Cosign/Sigstore.
5. Run runtime hardening against the same digest, not a mutable tag.

Docker's local `--load` exporter is not an evidence path. It is useful for
runtime tests, but it does not preserve image attestations in the Docker image
store. Use a registry push for release evidence, or the local/tar exporter when
you are validating SBOM files before a push.

## Executable Workflow

The release path lives in
[`../../.github/workflows/publish-image.yaml`](../../.github/workflows/publish-image.yaml).
It is enabled for pushes to `main`, `v*` tags, and manual dispatch. Main pushes
publish the continuous `main` channel plus the commit SHA tag; release tags
publish the version tag plus the commit SHA tag. Every third-party action is
pinned to a reviewed 40-character commit SHA.

## Review Rules

- Do not pass secrets as Docker build args. BuildKit max provenance can expose
  build argument values.
- Attest and sign `image@sha256:...`, not a mutable tag.
- Keep registry credentials in GitHub Actions secrets or OIDC-backed registry
  auth, not in the manifest.
- For vendor release binaries, verify upstream checksum signatures or Sigstore
  bundles before writing the artifact SHA256 into the manifest.
- If you need an SBOM file before pushing, build with
  `docker buildx build --sbom=true --output type=local,dest=dist/evidence .`
  and inspect `dist/evidence/sbom.spdx.json`.

## Verification

After the workflow publishes an image, verify the evidence from a clean
checkout:

```sh
gh attestation verify oci://ghcr.io/OWNER/IMAGE@sha256:DIGEST -R OWNER/REPO
cosign verify ghcr.io/OWNER/IMAGE@sha256:DIGEST \
  --certificate-identity-regexp 'https://github.com/OWNER/REPO/.github/workflows/.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Consumer Contract

Consumers should deploy this image by digest, not by tag. A deployment pipeline
that consumes the image is expected to verify both GitHub artifact attestation
and Cosign signature before promotion, using the digest emitted by
`.github/workflows/publish-image.yaml`. A mutable tag may be used only to
discover the latest candidate digest; it must not be the final deployment
identifier.

The digest, attestation verification output, Cosign verification output, and
runtime hardening output are the minimum evidence set for promoting a published
image into an environment.

## Rollback And Revocation

If a pushed digest is later found to be bad, stop promoting the mutable channel
tag, redeploy the last known-good digest that has passing attestation, signature,
and runtime-hardening evidence, and open a follow-up fix against the manifest or
publish workflow. Do not overwrite or force-delete the bad digest; keeping it
referencable preserves the audit trail.

If the signing identity or workflow is suspected to be compromised, pause the
publish workflow, revoke or rotate the affected GitHub credentials and
environment permissions, publish a new digest only after a clean workflow run,
and require consumers to verify the new digest before promotion. Treat any
unverified digest as non-deployable even when a mutable tag points at it.
