#!/usr/bin/env bash
#
# lint.sh - verify required files exist and all shell scripts parse.

set -u

fail=0

required=(
    README.md app/app.sh scripts/lint.sh scripts/build.sh
    tests/test.sh Dockerfile compose.yaml .dockerignore
    .github/workflows/ci.yml grade.sh
)
for f in "${required[@]}"; do
    if [[ ! -e "$f" ]]; then
        echo "MISSING: $f" >&2
        fail=$((fail + 1))
    fi
done

for s in app/*.sh scripts/*.sh tests/*.sh; do
    [[ -e "$s" ]] || continue
    if bash -n "$s" 2>/dev/null; then
        echo "OK syntax: $s"
    else
        echo "SYNTAX ERROR: $s" >&2
        fail=$((fail + 1))
    fi
done

if command -v shellcheck >/dev/null 2>&1; then
    for s in app/*.sh scripts/*.sh tests/*.sh; do
        [[ -e "$s" ]] || continue
        shellcheck "$s" || fail=$((fail + 1))
    done
else
    echo "shellcheck not found; skipping static analysis"
fi

if (( fail > 0 )); then
    echo "lint failed with $fail problem(s)" >&2
    exit 1
fi
echo "lint passed"
exit 0
