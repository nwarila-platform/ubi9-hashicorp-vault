# ADR-0001: Vault CE Ships With FIPS Off, Risk-Accepted

| Field          | Value                                    |
| -------------- | ---------------------------------------- |
| Status         | Accepted                                 |
| Date           | 2026-06-02                               |
| Authors        | Nick Warila (@NWarila)                   |
| Decision-maker | Nick Warila (sole portfolio maintainer)  |
| Consulted      | None.                                    |
| Informed       | None.                                    |
| Reversibility  | Medium                                   |
| Review-by      | N/A (Accepted)                           |

## TL;DR

This image packages the upstream **HashiCorp Vault Community Edition (CE)**
release binary. Vault CE has **no FIPS 140 build**: FIPS-validated cryptography in
Vault is an **Enterprise**, license-gated, amd64-only deliverable
(`+ent.fips1402`), which CE does not ship. Moving the runtime base from Ubuntu
Chisel to Red Hat UBI 9 does **not** confer FIPS on the workload either: the RHEL
OpenSSL CMVP certificate is bound to a RHEL host operating environment, and these
images run on **Talos Linux**, whose own FIPS story is a separate, paid build, so
the "host provides FIPS" premise is void here. We therefore **run with FIPS off
and risk-accept it** for the Vault workload. The Go-native FIPS approach used for
from-source helpers (for example, the AWS signing helper built with
`GOFIPS140` + a CMVP-validated Go cryptographic module) is a property of *that*
binary's build and does **not** extend to the prebuilt Vault CE binary we vendor.

## Context and Problem Statement

The portfolio's compliance narrative assumes a FIPS-validated cryptographic
posture wherever feasible. Two intuitive routes to "FIPS for Vault" turn out to
be false here, and a third applies only to other binaries:

1. **"Use Vault's FIPS build."** Vault's FIPS 140-2/140-3 cryptography is sold
   only with **Vault Enterprise**, gated behind a license, and published as a
   distinct artifact (the `+ent.fips1402` lineage), amd64-only. The
   **Community Edition** release this repository vendors — the official,
   signature- and checksum-verified `vault_<version>_linux_<arch>.zip` from
   `releases.hashicorp.com` — has **no FIPS variant**. There is no CE build flag,
   environment variable, or runtime toggle that turns Vault CE into a
   FIPS-validated module.
2. **"Let the base image / host provide FIPS."** RHEL's FIPS validation (the
   relevant CMVP certificate for RHEL 9 OpenSSL) is **bound to a RHEL host
   operating environment (OE)**. A UBI 9 *container* inherits that validated
   module's behavior **only when it runs on a RHEL host in FIPS mode**. These
   images are deployed on **Talos Linux**, not RHEL. Talos's FIPS capability is a
   separate, **paid** Talos build, not something the UBI 9 base grants. So the
   UBI 9 cutover — valuable for reproducibility, a preserved rpmdb, and a real
   DISA STIG — does **not** make the Vault workload FIPS-validated.
3. **"Build it FIPS-native in Go."** For binaries this portfolio builds *from
   source* (notably the AWS IAM Roles Anywhere signing helper), Go 1.24's
   `GOFIPS140` mechanism with a CMVP-validated Go cryptographic module produces a
   genuinely FIPS-validated runtime crypto story that is **portable across
   operating environments** (it is the binary's own module, not the host's). That
   story is real, but it is a property of **how that specific binary is built**.
   Vault CE is **vendored as a prebuilt binary**; we do not compile it, so we
   cannot apply `GOFIPS140` to it. The helper's FIPS posture therefore does
   **not** extend to Vault.

The problem statement: given that no available path makes the vendored Vault CE
binary FIPS-validated in our deployment context, what is the honest, documented
crypto posture for this image, and how do we keep that decision from being
silently misread as "FIPS-on because it's UBI 9"?

## Decision Drivers

1. **Honesty of the compliance claim.** The image must not imply a FIPS posture
   it does not have. A false "FIPS via UBI 9" claim is worse than an explicit
   "FIPS off, risk-accepted."
2. **Edition reality.** Vault CE has no FIPS build; we will not silently swap to
   license-gated Enterprise to chase a checkbox.
3. **Host reality.** The runtime host is Talos, not a RHEL FIPS-mode OE, so the
   RHEL OpenSSL CMVP certificate does not cover this workload.
4. **Scope clarity.** The Go-native FIPS approach is valid for from-source
   helpers and must not be over-generalized to vendored binaries.
5. **Auditability.** Whatever posture is chosen must be a written, reviewable
   risk-acceptance, traceable from this image's documentation.
6. **Reversibility.** If a CE FIPS build, a FIPS-mode RHEL host, or a Talos FIPS
   deployment becomes available and adopted, the decision must be cheap to
   revisit.

## Considered Options

1. **Risk-accept FIPS-off for the vendored Vault CE binary (chosen).** Document
   the posture explicitly; keep packaging the CE release.
2. **Switch to Vault Enterprise FIPS (`+ent.fips1402`).** Adopt the
   license-gated, amd64-only Enterprise FIPS build.
3. **Claim FIPS by virtue of the UBI 9 base / RHEL crypto.** Assert that running
   on UBI 9 makes the workload FIPS-validated.
4. **Rebuild Vault from source with `GOFIPS140`.** Compile Vault ourselves
   against a CMVP-validated Go cryptographic module.

## Decision Outcome

Chosen option: **Option 1 — run the vendored Vault CE binary with FIPS off and
risk-accept it**, documented here.

Concretely:

- This image continues to package the **official Vault CE release binary**,
  verified by HashiCorp's signed `SHA256SUMS` and the archive/binary SHA256
  pins in [`examples/image-manifest.json`](../../../examples/image-manifest.json)
  (see [`tools/build_app.sh`](../../../tools/build_app.sh)).
- The image makes **no FIPS claim**. Documentation states the crypto posture is
  non-FIPS and that this is an accepted risk for the Vault workload.
- The **UBI 9 base is adopted for its other merits** (digest-pinned bases, a
  preserved rpmdb for scanner legibility, and a published DISA RHEL 9 STIG), not
  as a FIPS mechanism. The host-provides-FIPS premise is explicitly void on
  Talos.
- The **Go-native `GOFIPS140` FIPS story is reserved for from-source binaries**
  (the signing helper) and is **not** asserted for Vault CE.

## Pros and Cons of the Options

### Option 1: Risk-accept FIPS-off for vendored Vault CE (chosen)

- **Good, because** it states the true posture; no false FIPS claim can mislead
  an auditor or operator.
- **Good, because** it keeps the simple, verifiable supply chain: vendor the
  signed CE release, verify, package.
- **Good, because** it is cheaply reversible if a real FIPS path is adopted.
- **Bad, because** the Vault workload's cryptography is not FIPS-validated, which
  some controls may require.
- **Neutral, because** the rest of the hardening posture (non-root, no shell,
  pinned bases, STIG-evaluated runtime) is unaffected.

### Option 2: Switch to Vault Enterprise FIPS (`+ent.fips1402`)

- **Good, because** it would give a genuinely FIPS-validated Vault crypto module.
- **Bad, because** it requires a paid Enterprise license; this portfolio packages
  CE.
- **Bad, because** the FIPS Enterprise build is amd64-only, dropping the arm64
  platform this image supports.
- **Bad, because** it changes the artifact source from the public CE release to a
  license-gated download, complicating the supply chain.

### Option 3: Claim FIPS via the UBI 9 base / RHEL crypto

- **Good, because** it would require no artifact change.
- **Bad, because** it is **false** in this deployment: the RHEL OpenSSL CMVP
  certificate is OE-bound to a RHEL host in FIPS mode, and the host is Talos.
- **Bad, because** asserting an unearned FIPS posture is a compliance
  misstatement, not a control.

### Option 4: Rebuild Vault from source with `GOFIPS140`

- **Good, because** it could in principle yield an OE-portable, FIPS-validated
  Vault crypto runtime.
- **Bad, because** it abandons the "vendor the signed upstream release" model and
  takes on full responsibility for building, patching, and supporting a Vault
  fork.
- **Bad, because** it is a large, ongoing engineering burden disproportionate to
  packaging a leaf image, and HashiCorp's own FIPS support attaches to the
  Enterprise build, not an arbitrary self-compile.

## Confirmation

Adherence is confirmed by the following. `MUST`, `SHOULD`, and `MAY` follow
[RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

1. **CE artifact.** The image MUST package the official Vault **Community
   Edition** release zip; the manifest's `application.artifacts[].url` MUST match
   `https://releases.hashicorp.com/vault/<version>/vault_<version>_linux_<arch>.zip`
   (no `+ent`/`+ent.fips1402` lineage). The manifest contract and
   [`tools/verify.py`](../../../tools/verify.py) `build-tool-pins` assert this.
2. **No FIPS claim.** Repository documentation MUST NOT assert that this image or
   its Vault binary is FIPS-validated.
3. **Base rationale.** The UBI 9 adoption rationale MUST be recorded as
   reproducibility / rpmdb / STIG, not FIPS.
4. **Helper scoping.** Any `GOFIPS140`-based FIPS claim MUST be scoped to the
   relevant from-source helper binary and MUST NOT be generalized to Vault CE.

## Consequences

### Positive

- The crypto posture is stated honestly; no unearned FIPS claim exists to be
  discovered later.
- The supply chain stays simple and auditable (signed CE release, verified,
  packaged), and arm64 support is retained.
- The decision is documented and cheaply reversible.

### Negative

- The Vault workload is not FIPS-validated; deployments with a hard FIPS
  requirement for Vault cannot use this image as-is.

### Neutral

- The non-FIPS posture is orthogonal to the rest of the hardening surface, which
  is unchanged.

## Assumptions

If any of these becomes false, this ADR should be revisited:

1. HashiCorp continues to ship FIPS cryptography only in Vault Enterprise
   (license-gated, amd64-only) and provides no FIPS build of Vault CE.
2. These images are deployed on Talos Linux (not a RHEL host in FIPS mode), so
   the RHEL OpenSSL CMVP certificate does not cover the workload, and Talos FIPS
   remains a separate, unadopted paid build.
3. The Vault binary is vendored as a prebuilt CE release rather than compiled
   from source, so `GOFIPS140` cannot be applied to it.

## Supersedes

None. This is the first repo-scoped ADR for this repository.

## Superseded by

None (current).

## Implementing PRs

Pending. The implementing PR records this risk-acceptance and ensures the
repository documentation makes no FIPS claim for the vendored Vault CE binary.

## Related ADRs

- [org ADR-0001](../org/0001-use-architecture-decision-records.md) — establishes
  the ADR format and the org/template/repo scope structure.
- [org ADR-0005](../org/0005-keep-github-control-planes-namespace-local.md) —
  the platform control-plane namespace this repository's reusables consume.

## Compliance Notes

This ADR is the written risk-acceptance for the Vault workload's non-FIPS crypto
posture. It directly supports the integrity- and accountability-of-decisions
controls below; it does **not** claim a cryptographic-module-validation control,
which is precisely the point.

| Framework              | Control / Practice ID                                  | Potential Evidence Contribution                                                                                          |
| ---------------------- | ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| NIST SP 800-53 Rev. 5  | RA-3 (Risk Assessment) / PM-9 (Risk Management)        | This ADR is the documented, accepted risk for running the Vault workload without FIPS-validated cryptography.            |
| NIST SP 800-53 Rev. 5  | SC-13 (Cryptographic Protection)                       | Records that SC-13's FIPS-validation expectation is **not** met for Vault CE here, with the rationale, rather than implying it. |
| NIST SP 800-218 (SSDF) | PO.3 (Implement Supporting Toolchains) / RV.1 (Identify Vulnerabilities) | Captures an explicit posture decision so downstream evaluation reflects reality instead of an assumed FIPS state.       |
