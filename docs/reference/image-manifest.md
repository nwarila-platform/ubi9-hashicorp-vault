# Image Manifest Contract

The image manifest is the review surface for this image repository. The
working example is [`examples/image-manifest.json`](../../examples/image-manifest.json)
and the schema is [`contracts/image-manifest.schema.json`](../../contracts/image-manifest.schema.json).
The example ships with real pinned upstream values so this image builds
end-to-end without any further edits.

## Required Sections

| Section | Purpose |
| --- | --- |
| `image` | Image name, optional RHEL version, and supported platforms. |
| `base.builder` | Digest-pinned UBI 9 `ubi-minimal` builder image (carries `microdnf`). |
| `base.runtime` | Digest-pinned UBI 9 `ubi-micro` runtime image. |
| `dnf.packages` | Package names installed into the runtime rootfs with `microdnf --installroot`. |
| `application` | Application artifact source, final binary path, build-context artifact paths, checksums, and verification mode. |
| `runtime` | Non-root user, entrypoint, and forbidden executable baseline. |
| `evidence` | Required release evidence types. |

The manifest is schema v2 (`schema_version: "2.0"`): both `base.builder` and
`base.runtime` are `@sha256:` digest-pinned references, Renovate-managed with
`redhat` versioning. The Chisel-era `builder`, `chisel`, and `ubuntu_series`
fields no longer exist (the schema is `additionalProperties: false`).

`dnf.packages` must include `ca-certificates` for this Vault image so outbound
TLS features such as auto-unseal, OIDC, LDAP, and HTTPS storage or audit
integrations can build a system certificate pool from
`/etc/pki/tls/certs/ca-bundle.crt`. The rootfs is assembled with
`microdnf --installroot`, which preserves the rpm database at `/var/lib/rpm` so
Trivy, Grype, and OpenSCAP enumerate the installed package set.

`application.artifacts[]` is keyed by platform and records the reviewed
build-context path plus the expected SHA256 for that platform's binary. Paths
must be relative, use `/` separators, and stay inside the Docker build context.
This repository's `.dockerignore` allows `dist/**` by default, which holds the
downloaded and verified Vault binaries that the application stage copies into the
image. For the vendor-release-binary source, each artifact additionally records
the official Vault release `url` and the `archive_sha256` of the downloaded zip,
which `tools/build_app.sh` cross-checks against HashiCorp's signed
`SHA256SUMS` before extracting the binary.

## Manifest Modes

| Mode | Use When | How |
| --- | --- | --- |
| Strict | Production. The manifest must contain only real pins. | `python tools/check_image_manifest.py path/to/image-manifest.json` |
| Template | A repository derived from `NWarila/ubi9-application-template` that is still replacing starter pins. Allows `REPLACE_WITH_*` markers to pass validation. | `python tools/check_image_manifest.py --template path/to/image-manifest.json` |

The committed `examples/image-manifest.json` validates in strict mode. The
template-mode acceptance is regression-tested in `tools/verify.py` against an
in-memory manifest containing a `REPLACE_WITH_*` marker.

## From Manifest To docker buildx

`python tools/generate_build_args.py <manifest>` emits the docker buildx flags
derived from the manifest. The default `docker-buildx` format pairs each flag
with its value on adjacent lines for `mapfile -t` consumption; the alternate
`json` format produces a structured object useful in GitHub Actions matrices.
See [`docs/how-to/build-image.md`](../how-to/build-image.md) for the recommended
invocation pattern.

## Verification Modes

| Mode | Use When |
| --- | --- |
| `checksum` | The upstream artifact has a trusted checksum source. |
| `checksum-signature` | The upstream publishes signed checksums. |
| `pgp-signature` | The upstream publishes detached PGP signatures. |
| `sigstore-bundle` | The upstream publishes Sigstore bundle evidence. |
| `none` | Only for internally built artifacts whose SHA256 in the manifest is the contract. |

Prefer signed checksums or Sigstore bundles for vendor release binaries. The
example uses `checksum-signature` because the Vault binaries come from an
official upstream release whose signed SHA256SUMS file is verified before use;
the per-platform SHA256 entries still pin the exact binary the image must
contain.
