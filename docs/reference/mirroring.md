# Mirroring And Consumer Baseline

This repository is split into a shared repo-quality baseline, the
manifest-driven build tooling, and Vault-specific artifact/runtime wiring.

## Required Shared Baseline

This repository keeps these files close to its source template
`NWarila/ubi9-application-template` unless there is a documented reason to
diverge:

- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/renovate.json5`
- `.markdownlint-cli2.jsonc`
- `contracts/image-manifest.schema.json`
- `tests/runtime-hardening.sh`
- `tools/check_image_manifest.py`
- `tools/generate_build_args.py`
- `tools/build_image.sh`
- `tools/verify_app_shas.py`
- `tools/verify.py`
- `docs/reference/image-manifest.md`
- `docs/reference/runtime-hardening.md`
- `docs/reference/supply-chain-evidence.md`

## Vault-Specific Layer

These files define the Vault image behavior and should change only with a
reviewed Vault, UBI 9 base, or runtime-policy update:

- `README.md`
- `examples/image-manifest.json`
- `examples/vault-server.hcl`
- `tools/build_app.sh`
- `containers/Dockerfile`
- `docs/explanation/*`
- `docs/how-to/*`
- `docs/decision-records/repo/*`

## Update Checklist

1. Update Vault release URLs and archive SHA256 values from HashiCorp's signed
   SHA256SUMS file.
2. Re-run `tools/build_app.sh` and record any extracted-binary SHA256 changes.
3. Confirm the `dnf.packages` set is still the minimum needed runtime surface.
4. Run `python tools/verify.py ci` and `make image` locally.
5. Confirm CI's `image build + hardening` job passes for the image.
