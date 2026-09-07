#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -a topics
# shellcheck source=SCRIPTDIR/topics.sh
source "${SCRIPT_DIR}/topics.sh"

# Only emit terminal control codes when running interactively. CI logs and
# other non-tty output have no $TERM, which makes tput fail noisily. This is
# checked once here, rather than inside color() itself, because color() is
# invoked via $(...) command substitution, which always redirects stdout to
# a pipe to capture it -- so `[[ -t 1 ]]` inside color() would always be false.
if [[ -t 1 ]]; then
    is_tty=true
else
    is_tty=false
fi

color() {
    if $is_tty; then
        tput "$@" 2>/dev/null
    fi
    return 0
}

run_pdflatex() {
    local tex_directory=$1
    local tex_file=$2
    local tex_path="${tex_directory}/${tex_file}"
    local log_file="${tex_file%.tex}.log"

    # In an interactive terminal, print the "Building" line without a newline
    # and overwrite it in place once the result is known. Outside a terminal
    # (CI logs, `| tee`, etc.) keep both lines so the log stays readable.
    if $is_tty; then
        printf "Building '%s'..." "${tex_path}"
    else
        echo "Building '${tex_path}'..."
    fi

    pushd "${tex_directory}" >/dev/null || return 1

    if pdflatex -halt-on-error -interaction=nonstopmode "${tex_file}" >/dev/null 2>&1; then
        if $is_tty; then
            printf '\r%s' "$(color el)"
        fi
        echo -e "$(color setaf 2)Compiling '${tex_path}' was successful!$(color sgr0)"
        popd >/dev/null
        return 0
    else
        if $is_tty; then
            printf '\r%s\n' "$(color el)"
        fi
        echo -e "$(color setaf 1)There was an error compiling '${tex_path}'. See ${tex_directory}/${log_file} for details.$(color sgr0)"
        if [[ -f "${log_file}" ]]; then
            echo "Last 20 lines of '${tex_directory}/${log_file}':"
            tail -n 20 "${log_file}"
        fi
        popd >/dev/null
        return 1
    fi
}

# Print all items in the array, just to demonstrate
build_failed=0
for topic in "${topics[@]}"; do
    if [ -f "${topic}/paper.tex" ]; then
        if ! run_pdflatex "${topic}" "paper.tex"; then
            build_failed=1
        fi
    elif [ -f "${topic}/presentation.tex" ]; then
        if ! run_pdflatex "${topic}" "presentation.tex"; then
            build_failed=1
        fi
    else
        echo "Couldn't find ${topic}/paper.tex nor ${topic}/presentation.tex. Exiting..."
        exit 1
    fi
done

if ((build_failed == 0)); then
    echo -e "$(color setaf 2)All files were built successfully!$(color sgr0)"
fi

exit ${build_failed}
