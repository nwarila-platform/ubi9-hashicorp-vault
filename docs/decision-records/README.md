# Architecture Decision Records

This directory holds the Architecture Decision Records (ADRs) governing this
repository. Per [org ADR-0001](org/0001-use-architecture-decision-records.md),
ADRs are organized into three scopes:

- `org/` - mirrored org-baseline ADRs from `nwarila-platform/.github`.
- `template/` - mirrored type-template ADRs that would apply to this repository
  if the upstream image template owns any.
- `repo/` - decisions made by this repository only.

`python tools/verify.py ci` checks that the expected org ADR filenames are
present. It does not compare the mirrored files byte-for-byte against
`nwarila-platform/.github`; mirror refreshes remain an explicit review task unless a
separate drift gate is added.

## Repo ADRs

The `repo/` scope holds decisions made by this repository only.

| ADR | Status | Decision |
| --- | --- | --- |
| [ADR-0001](repo/0001-vault-ce-fips-off-risk-accept.md) | Accepted | Vault CE ships with FIPS off; risk-accepted for this image. |

## Template ADRs

No template-scoped ADRs are mirrored into this repository yet. The Red Hat UBI 9
direction is documented in the README and reference material; if the upstream
UBI 9 application template later owns type-scoped ADRs, they are mirrored under
`template/`.

## Org ADRs

The `org/` scope is mirrored from `nwarila-platform/.github`.

| ADR | Status | Decision |
| --- | --- | --- |
| [ADR-0001](org/0001-use-architecture-decision-records.md) | Accepted | Use ADRs to document design rationale. |
| [ADR-0002](org/0002-adopt-diataxis-documentation-framework.md) | Accepted | Use Diataxis for non-ADR documentation. |
| [ADR-0003](org/0003-use-deny-all-gitignore-strategy.md) | Accepted | Use deny-all `.gitignore` allowlists. |
| [ADR-0004](org/0004-use-renovate-for-dependency-updates.md) | Accepted | Use Renovate for dependency updates. |
| [ADR-0005](org/0005-keep-github-control-planes-namespace-local.md) | Accepted | Keep GitHub control planes namespace-local. |

The `.gitkeep` placeholders keep the directory skeleton complete until each
scope has tracked ADRs.
