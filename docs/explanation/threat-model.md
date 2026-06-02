# Threat Model

This image repository focuses on supply-chain and runtime-surface risks for
custom application images.

## Primary Risks

| Risk | Repository Mitigation |
| --- | --- |
| Mutable base image drift | The UBI 9 `ubi-minimal` builder and `ubi-micro` runtime images are pinned by `@sha256:` digest rather than consuming a mutable shared base. |
| Unreviewed package set | The manifest records the exact `dnf.packages` installed into the runtime rootfs, and the preserved rpm database lets scanners enumerate the resolved NVRs. |
| Scanner blindness | The rootfs is assembled with `microdnf --installroot`, preserving `/var/lib/rpm` so Trivy, Grype, and OpenSCAP see the real package set instead of a false "zero packages". |
| Tampered application artifact | `tools/build_app.sh` verifies HashiCorp's signed checksum file, then checks the Vault archive and extracted binary hashes recorded in the manifest. |
| Excess runtime tooling | Runtime checks assert no shell, `dnf`/`microdnf`/`rpm`/`yum`, `curl`, or `wget` in the final image. |
| Root runtime | The image runs as UID/GID `65532:65532` with matching passwd and group entries. |
| Missing release evidence | The publish workflow emits SBOM, provenance, GitHub attestation, Cosign signature, and runtime-hardening evidence for the pushed digest. |

## Out Of Scope

- Registry compromise response.
- Admission-controller policy.
- Application-level vulnerability management.
- Runtime sandbox configuration in Kubernetes or another orchestrator.
- Secrets handling inside applications.

Those belong in the deployment platform consuming this image.
