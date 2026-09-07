#!/usr/bin/env bash
# Regenerates the GDRIVE_ACCOUNT_EXPORT_BASE64 GitHub secret from a gdrive CLI
# account credential on this machine.
#
# Run this after completing the `gdrive account add` browser OAuth flow (see
# scripts/README.md) — typically when rotating an expired/revoked token.
#
# Requires: gdrive (glotlabs/gdrive), gh (authenticated with secret-write
# access), and must be run from inside a checkout of this repo so `gh` can
# infer the target repo from the git remote.
set -eo pipefail

usage() {
  echo "Usage: $0 <gdrive-account-email>" >&2
  echo "  e.g. $0 robert.lech123@gmail.com" >&2
  echo "  Run 'gdrive account list' first if you're unsure of the exact name." >&2
}

if [ "$#" -eq 1 ] && { [ "$1" = "-h" ] || [ "$1" = "--help" ]; }; then
  usage
  exit 0
fi

if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi

account="$1"

for bin in gdrive gh; do
  if ! command -v "${bin}" >/dev/null 2>&1; then
    echo "ERROR: '${bin}' is not installed or not on PATH." >&2
    exit 1
  fi
done

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

echo "Exporting gdrive account '${account}'..."
# gdrive names the archive "gdrive_export-<normalized-account>.tar" (non-alnum
# chars become '_') in the working directory, so run it in the empty temp dir
# and then discover whatever .tar it produced rather than hardcoding the name.
(cd "${tmp_dir}" && gdrive account export "${account}")

echo "Export directory contents:"
ls -la "${tmp_dir}" >&2

tar_files=("${tmp_dir}"/*.tar)
if [ ! -e "${tar_files[0]}" ]; then
  echo "ERROR: no .tar file was produced by 'gdrive account export ${account}'." >&2
  echo "Check that '${account}' matches an entry in 'gdrive account list'." >&2
  exit 1
fi
if [ "${#tar_files[@]}" -ne 1 ]; then
  echo "ERROR: expected exactly one .tar file, found ${#tar_files[@]}:" >&2
  printf '  %s\n' "${tar_files[@]}" >&2
  exit 1
fi
tar_file="${tar_files[0]}"
echo "Using export archive: $(basename "${tar_file}")"

echo "Base64-encoding the export..."
base64_file="${tmp_dir}/export.b64"
if base64 --help 2>&1 | grep -q -- '-w'; then
  base64 -w0 "${tar_file}" >"${base64_file}"      # GNU coreutils (Linux)
else
  base64 -i "${tar_file}" >"${base64_file}"       # BSD/macOS
fi

echo "Updating the GDRIVE_ACCOUNT_EXPORT_BASE64 secret..."
# `gh secret set` has no --body-file flag; it reads the value from stdin when
# --body is omitted, so feed the base64 payload in via redirection.
gh secret set GDRIVE_ACCOUNT_EXPORT_BASE64 <"${base64_file}"

echo "Done. Secret updated for $(gh repo view --json nameWithOwner -q .nameWithOwner)."
