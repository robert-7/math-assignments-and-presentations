#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -a topics
# shellcheck source=SCRIPTDIR/topics.sh
source "${SCRIPT_DIR}/topics.sh"

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
  check=$(gdrive files list --query "name = '${destination_path}'" --skip-header | wc -l)
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
    samefileID=$(gdrive files list --query "name = '${destination_path}'" --skip-header | sed 's/|/ /' | awk '{print $1}' | head -n 1)
    echo "Fetched the file ID. It's ${samefileID}."
    gdrive files update "${samefileID}" "${source_path_to_upload}"
    echo "Done updating."
  else
    echo "It doesn't exist. We'll upload the file."
    gdrive files upload --parent "${GDRIVE_DIRECTORY_ID}" "${source_path_to_upload}"
    echo "Done uploading."
  fi

  rm -f "${source_path_to_upload}"
  echo
}

# NOTE: This is the ID of the "Math Assignments and Presentations" directory. Verified below before continuing.
GDRIVE_DIRECTORY_ID="1hHjYI4HzHuml5mo9G2RKdZnM2xv3s9mu"
if gdrive files info "${GDRIVE_DIRECTORY_ID}" | grep "Math Assignments and Presentations"; then
  for topic in "${topics[@]}"; do
    push_to_gdrive "${topic}"
  done
else
  echo "Can't verify that ${GDRIVE_DIRECTORY_ID} is the correct ID for our upload path. Exiting early..."
fi
