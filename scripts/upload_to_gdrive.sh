#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -a topics
# shellcheck source=SCRIPTDIR/topics.sh
source "${SCRIPT_DIR}/topics.sh"

# Per-call timeout (seconds) for every gdrive invocation. An expired/revoked
# OAuth credential makes gdrive hang indefinitely instead of erroring out, which
# previously let this step run until GitHub's 2-hour job limit killed it. Bound
# each call so we fail fast with a useful message instead.
GDRIVE_TIMEOUT="${GDRIVE_TIMEOUT:-120}"

# Wrapper around the gdrive CLI. On a timeout (exit code 124 from `timeout`),
# print an explicit diagnostic and abort; other failures propagate as-is.
gdrive_cmd() {
  local rc=0
  timeout "${GDRIVE_TIMEOUT}" gdrive "$@" || rc=$?
  if [ "${rc}" -eq 124 ]; then
    echo "ERROR: 'gdrive $*' timed out after ${GDRIVE_TIMEOUT}s." >&2
    echo "The gdrive OAuth token has most likely expired or been revoked (Google" >&2
    echo "expires refresh tokens after 7 days for OAuth apps in 'Testing' status)." >&2
    echo "Regenerate the credential and update the GDRIVE_ACCOUNT_EXPORT_BASE64" >&2
    echo "GitHub secret (see the upload flow notes in CLAUDE.md)." >&2
    exit 1
  fi
  return "${rc}"
}

push_to_gdrive() {
  local topic="$1"
  local pdf_filename

  if [ -f "${topic}/paper.pdf" ]; then
    pdf_filename="paper.pdf"
  elif [ -f "${topic}/presentation.pdf" ]; then
    pdf_filename="presentation.pdf"
  else
    echo "Couldn't find ${topic}/paper.pdf nor ${topic}/presentation.pdf. Exiting..."
    return 1
  fi

  local source_path="${topic}/${pdf_filename}"
  local destination_path
  destination_path="$(echo "${source_path}" | tr '/' ' ' | tr -d "'" | sed 's/paper.pdf/Paper.pdf/' | sed 's/presentation.pdf/Presentation.pdf/')"

  echo "Checking if the file ${destination_path} exists in Google Drive..."
  local check
  check=$(gdrive_cmd files list --query "name = '${destination_path}'" --skip-header | wc -l)
  echo "Found ${check} instance(s) of the file named ${destination_path}."

  if [ "${check}" -gt 1 ]; then
    echo "Too many instances. Exiting early..."
    return
  fi

  local source_dir
  source_dir="$(dirname "${source_path}")"
  local source_path_to_upload
  source_path_to_upload="${source_dir}/${destination_path}"
  cp "${source_path}" "${source_path_to_upload}"

  if [ "${check}" -eq 1 ]; then
    echo -n "It exists. Attempting to fetch the file ID... "
    local samefileID
    samefileID=$(gdrive_cmd files list --query "name = '${destination_path}'" --skip-header | sed 's/|/ /' | awk '{print $1}' | head -n 1)
    echo "Fetched the file ID. It's ${samefileID}."
    gdrive_cmd files update "${samefileID}" "${source_path_to_upload}"
    echo "Done updating."
  else
    echo "It doesn't exist. We'll upload the file."
    gdrive_cmd files upload --parent "${GDRIVE_DIRECTORY_ID}" "${source_path_to_upload}"
    echo "Done uploading."
  fi

  rm -f "${source_path_to_upload}"
  echo
}

# NOTE: This is the ID of the "Math Assignments and Presentations" directory. Verified below before continuing.
GDRIVE_DIRECTORY_ID="1hHjYI4HzHuml5mo9G2RKdZnM2xv3s9mu"

# First real gdrive API call: a timeout here (expired token) aborts via gdrive_cmd
# with a clear message before we reach the grep, so the else branch only fires on
# a genuine "wrong directory ID" mismatch.
directory_info="$(gdrive_cmd files info "${GDRIVE_DIRECTORY_ID}")"
if echo "${directory_info}" | grep -q "Math Assignments and Presentations"; then
  for topic in "${topics[@]}"; do
    push_to_gdrive "${topic}"
  done
else
  echo "Can't verify that ${GDRIVE_DIRECTORY_ID} is the correct ID for our upload path. Exiting early..." >&2
  exit 1
fi
