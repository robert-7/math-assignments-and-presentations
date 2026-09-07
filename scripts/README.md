# Scripts

* [build.sh](build.sh) can be run from the root directory to build all LaTeX files.
  * Needs [install.sh](install.sh) to have run to install packages locally.
* [install.sh](install.sh) installs all dependencies for the repo.
* [topics.sh](topics.sh) defines the shared list of LaTeX project topics.
* [upload_to_gdrive.sh](upload_to_gdrive.sh) uploads all PDFs to Google Drive.
  * Needs [install.sh](install.sh) to have run to install packages locally.
  * Needs [build.sh](build.sh) to have run for the PDFs to exist.
  * Once everything else is set up, run `gdrive account add` to add the API credentials to your Google Drive.
    Here's a [YouTube link](https://www.youtube.com/watch?v=TH8BdDUbvck) to help get that set up if you haven't already.
* [rotate_gdrive_secret.sh](rotate_gdrive_secret.sh) exports a local `gdrive` account credential and pushes it to
  the `GDRIVE_ACCOUNT_EXPORT_BASE64` GitHub secret used by CI. Run this after `gdrive account add` when the CI
  upload starts hanging/failing due to an expired or revoked token.
