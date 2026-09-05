# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of math papers and presentations written in LaTeX. Each top-level directory is one
self-contained "topic" (a paper or a Beamer presentation). Two topics also carry supporting code
(Python and Java) used to validate claims made in the corresponding paper. Compiled PDFs are **not**
committed — CI builds them and uploads them to a shared Google Drive folder.

## Environment note (read first)

- The primary dev machine here is **macOS**, but `scripts/install.sh` is **Ubuntu/apt-only** and will
  not run on macOS. On this machine `pre-commit`, `python3`, and `java` are available, but `pdflatex`
  and `chktex` are **not installed**.
- To build or LaTeX-lint locally on macOS, install a TeX distribution first, e.g.
  `brew install --cask mactex-no-gui` (provides `pdflatex`) and `brew install chktex`.
- CI (Ubuntu) is the source of truth for builds and linting. Prefer verifying changes via CI or
  `pre-commit` over assuming a local TeX toolchain exists.

## Common commands

```bash
make build      # scripts/build.sh — compiles every topic's paper.tex/presentation.tex
make clean      # deletes intermediary files (*.aux *.log *.nav *.out *.snm *.toc)
make upload     # scripts/upload_to_gdrive.sh — pushes built PDFs to Google Drive (needs auth + built PDFs)

pre-commit run --all-files    # run every linter
pre-commit run <hook_id>      # run one linter (e.g. chktex, pylint, flake8, shellcheck, markdownlint)
pre-commit install            # install git hooks so linters run on every commit
```

Build/lint a **single** paper (there is no per-topic make target):

```bash
# one topic only — cd into it and run pdflatex the way build.sh does (twice for cross-refs/TOC/labels):
cd "Proof on the Uniqueness of the Sicherman Dice"
pdflatex -halt-on-error -interaction=nonstopmode paper.tex && pdflatex -halt-on-error -interaction=nonstopmode paper.tex

# LaTeX-lint one file:
chktex -l .chktexrc "Proof on the Uniqueness of the Sicherman Dice/paper.tex"
```

Run the Python validation (Solving Linear Relations using Linear Algebra):

```bash
cd "Solving Linear Relations using Linear Algebra/code"
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python validate.py     # NOTE: code/README.md wrongly says `python test_results.py`
```

## Architecture / big picture

**Per-topic directory convention.** Each topic dir contains exactly one of `paper.tex` **or**
`presentation.tex` (Beamer), plus an `images/` dir and usually a `README.md`. The build and upload
scripts key off this: they look for `paper.tex` first, then `presentation.tex`. A topic with neither
causes the build to hard-fail.

**`scripts/topics.sh` is the central registry.** It defines a `topics=(...)` bash array that
`build.sh` and `upload_to_gdrive.sh` both `source`. **A new paper directory is invisible to build and
upload until its name is added to this array.** This is the single most important gotcha in the repo.

**Build flow** (`scripts/build.sh`): iterates `topics`, runs `pdflatex -halt-on-error
-interaction=nonstopmode` in each dir, collects failures, and exits non-zero if any failed. CI runs
`make build && make build` — **the double build is intentional**: the first pass populates
`.aux`/`.toc` so the second pass resolves cross-references, the table of contents, and labels.

**Upload flow** (`scripts/upload_to_gdrive.sh`): requires the `gdrive` CLI (glotlabs/gdrive, installed
by `install.sh`) authenticated to the target account. It renames `paper.pdf`→`<Topic> Paper.pdf` /
`presentation.pdf`→`<Topic> Presentation.pdf`, then updates the file in Google Drive if it already
exists or uploads it under a fixed parent folder ID (`GDRIVE_DIRECTORY_ID`, verified by name before
any upload). Compiled PDFs are gitignored, so Drive is the canonical published location. (The `.pdf`
files that *are* tracked in git are figure assets under `images/` and `Feathergraphics/`, not compiled
outputs.)

**CI** (`.github/workflows/main.yaml`), two jobs:
- `pre-commit` — runs on every PR and push; installs LaTeX lint deps via `install.sh --lint` then runs all hooks.
- `build-and-upload` — runs **only on push to `main`**; installs `texlive-full` via `install.sh --build`,
  builds twice, restores the `gdrive` account from the base64 secret `GDRIVE_ACCOUNT_EXPORT_BASE64`, and uploads.

**Linting stack** (`.pre-commit-config.yaml`) — LaTeX (`chktex`, config `.chktexrc`), Python
(`pylint` + `flake8`, max line 120), Markdown (`markdownlint`, `.markdownlint.rb`), YAML (`yamllint`),
Bash (`shellcheck`), Makefile (`checkmake`), plus generic hygiene hooks. `.chktexrc` intentionally
suppresses chktex warnings 3, 8, and 24 (each documented inline with a rationale link).

**Supporting code.** Two topics carry code that validates the math:
- `Solving Linear Relations using Linear Algebra/code/validate.py` — numpy; checked by pylint/flake8.
- `Extending Conditional Recurrences over Finite Fields/code/src/Recursion.java` — Java (Eclipse
  project; no committed build config).

## Adding a new paper (checklist)

1. Create the topic directory with `paper.tex` **or** `presentation.tex` and an `images/` dir.
2. Add the exact directory name to the `topics=(...)` array in `scripts/topics.sh` (keep it sorted).
3. Add a `README.md` describing the paper (and, ideally, linking its published PDF).
4. Run `pre-commit run --all-files` and build locally (twice) before opening a PR.

## Known broken / stale config (verify before relying on these)

- **`.pre-commit-config.yaml` `file-contents-sorter`** points at
  `Solving Linear Relations using Linear Algebra/test_results/requirements.txt`, which does **not
  exist** (the real file is `.../code/requirements.txt`). The hook is currently a silent no-op.
- **numpy version mismatch:** `code/requirements.txt` pins `numpy==1.26.1`, but the pylint hook's
  `additional_dependencies` pins `numpy==2.3.4`. Keep them in sync when touching either.
- **`code/README.md`** tells you to run `python test_results.py`; the actual script is `validate.py`.
- **`Constructing New Families of Nested Recursions with Slow Solutions/paper.tex`** is excluded from
  chktex in the pre-commit config (it emits many warnings) and the dir has no README (see issue #53).
