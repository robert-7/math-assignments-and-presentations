# Math Assignments and Presentations

![GitHub Workflow Status](https://github.com/robert-7/Math-Assignments-and-Presentations/actions/workflows/main.yaml/badge.svg)

Various papers and presentations done in LaTeX. Links to compiled PDFs can be found in the READMEs.

## Contributing

### Installing dependencies

`scripts/install.sh` detects your OS and installs dependencies accordingly:

- **Ubuntu/Debian:** installs via `apt` and downloads the `gdrive` binary.
- **macOS:** installs via [Homebrew](https://brew.sh). `shellcheck` is a plain formula; `chktex` has
  no standalone formula and only ships bundled in a TeX Live distribution, so `--build` (or the
  default, which includes it) pulls in `mactex-no-gui` (full TeX Live, provides `pdflatex` and
  `chktex`), while `--lint` alone installs the much smaller `basictex` cask plus `chktex` via
  `tlmgr`. `basictex` and `mactex-no-gui` conflict with each other, so only one can be installed at a
  time — if you hit that conflict, follow the script's instructions to uninstall the other first.
  `gdrive` is skipped — uploads run in CI only.

Run it with no flags to install everything, or scope it with `--lint` and/or `--build`:

```bash
scripts/install.sh          # everything
scripts/install.sh --lint   # linting toolchain only
scripts/install.sh --build  # LaTeX build toolchain only
```

### Set up local linting

On Ubuntu, install the Python venv tooling first:

```bash
sudo apt install python3-tk python3-venv
```

Then, on either OS, create and activate a virtual environment:

```bash
python -m venv .venv
source .venv/bin/activate
```

Linting is done with [`pre-commit`](https://pre-commit.com), a multi-language package manager for pre-commit hooks.

Follow the instructions at <https://pre-commit.com/#install> to install it, then run `pre-commit install` in the repo root to install the git hooks locally. They will run **automatically** every time you commit.

If you want to run all the checks manually, use `pre-commit run --all-files`. If you want to run just one of the checks, use `pre-commit run <hook_id>`.

All the hooks are also run automatically via CI when pushing, so installing them locally will save you from **realizing you made a mistake only after pushing**.

### Makefile Usage

Makefile is used to simplify the steps needed to build and clean the repository. See commands below for usage:

```shell
make build
make clean
make upload
```
