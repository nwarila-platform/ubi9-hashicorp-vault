#!/usr/bin/env bash
# Download HashiCorp Vault release artifacts, verify the signed checksum file,
# verify each archive checksum, and extract the per-platform vault binaries
# into dist/ for the Docker build context.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${MANIFEST:-examples/image-manifest.json}"

cd "${ROOT}"
mkdir -p dist

if [[ -n "${TMPDIR:-}" ]]; then
  tmp_base="${TMPDIR}"
elif [[ -d /c/tmp && -w /c/tmp ]]; then
  tmp_base="/c/tmp"
else
  tmp_base="${ROOT}/.tmp"
fi
mkdir -p "${tmp_base}"
tmp_dir="$(mktemp -d "${tmp_base%/}/vault-artifacts.XXXXXX")"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

metadata="${tmp_dir}/manifest.tsv"
python - "${MANIFEST}" > "${metadata}" <<'PY'
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
application = manifest["application"]
verification = application["verification"]

rows = [
    "\t".join(
        [
            "META",
            application["version"],
            verification["checksum_url"],
            verification["signature_url"],
            verification["public_key_url"],
        ]
    )
]
for artifact in application["artifacts"]:
    rows.append(
        "\t".join(
            [
                "ARTIFACT",
                artifact["platform"],
                artifact["path"],
                artifact["sha256"],
                artifact["archive_sha256"],
                artifact["url"],
            ]
        )
    )
sys.stdout.buffer.write(("\n".join(rows) + "\n").encode("utf-8"))
PY

version=""
checksum_url=""
signature_url=""
public_key_url=""
declare -a artifacts=()
while IFS=$'\t' read -r kind first second third fourth; do
  case "${kind}" in
    META)
      version="${first}"
      checksum_url="${second}"
      signature_url="${third}"
      public_key_url="${fourth}"
      ;;
    ARTIFACT)
      artifacts+=("${first}"$'\t'"${second}"$'\t'"${third}"$'\t'"${fourth}")
      ;;
    *)
      echo "unknown manifest metadata row kind: ${kind}" >&2
      exit 1
      ;;
  esac
done < "${metadata}"

test -n "${version}"
test -n "${checksum_url}"
test -n "${signature_url}"
test -n "${public_key_url}"
test "${#artifacts[@]}" -gt 0

checksums="${tmp_dir}/vault_${version}_SHA256SUMS"
signature="${checksums}.sig"
public_key="${tmp_dir}/hashicorp.asc"
expected_hashicorp_fingerprint="C874011F0AB405110D02105534365D9472D7468F"

curl -fsSLo "${checksums}" "${checksum_url}"
curl -fsSLo "${signature}" "${signature_url}"
curl -fsSLo "${public_key}" "${public_key_url}"

export GNUPGHOME="${tmp_dir}/gnupg"
mkdir -p "${GNUPGHOME}"
chmod 700 "${GNUPGHOME}"
actual_fingerprints="$(gpg --batch --show-keys --with-colons --fingerprint "${public_key}" \
  | awk -F: '$1 == "fpr" { print $10 }')"
if ! printf '%s\n' "${actual_fingerprints}" | grep -Fxq "${expected_hashicorp_fingerprint}"; then
  echo "HashiCorp PGP key fingerprint did not match ${expected_hashicorp_fingerprint}" >&2
  exit 1
fi
gpg --batch --import "${public_key}" >/dev/null
gpg --batch --verify "${signature}" "${checksums}"

for row in "${artifacts[@]}"; do
  IFS=$'\t' read -r platform rel_path expected_binary_sha256 expected_archive_sha256 url <<< "${row}"
  archive="${tmp_dir}/$(basename "${url}")"
  filename="$(basename "${url}")"

  curl -fsSLo "${archive}" "${url}"
  awk -v sha="${expected_archive_sha256}" -v file="${filename}" \
    '$1 == sha && $2 == file { found = 1 } END { exit found ? 0 : 1 }' \
    "${checksums}" || {
      echo "${filename} with expected SHA256 was not present in signed checksum file" >&2
      exit 1
    }
  printf '%s  %s\n' "${expected_archive_sha256}" "${archive}" | sha256sum -c -

  mkdir -p "$(dirname "${ROOT}/${rel_path}")"
  chmod u+w "${ROOT}/${rel_path}" 2>/dev/null || true
  rm -f "${ROOT}/${rel_path}"
  unzip -p "${archive}" vault > "${ROOT}/${rel_path}"
  chmod 0555 "${ROOT}/${rel_path}"
  printf '%s  %s\n' "${expected_binary_sha256}" "${ROOT}/${rel_path}" | sha256sum -c -
  echo "${platform}: extracted ${rel_path}"
done

sha256sum dist/vault-amd64 dist/vault-arm64
