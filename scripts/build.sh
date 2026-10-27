#!/usr/bin/env bash
#
# build.sh - build the Docker image and smoke-test the container.

set -u

fail=0

echo "==> docker build -t devops-tool ."
if ! docker build -t devops-tool .; then
    echo "build failed" >&2
    exit 1
fi

check() {
    local desc="$1" expect="$2"; shift 2
    docker run --rm devops-tool "$@" >/dev/null 2>&1
    local rc=$?
    if [[ "$expect" == "zero" && $rc -ne 0 ]]; then
        echo "SMOKE FAIL: $desc expected 0 got $rc" >&2; fail=$((fail+1))
    elif [[ "$expect" == "nonzero" && $rc -eq 0 ]]; then
        echo "SMOKE FAIL: $desc expected non-zero got 0" >&2; fail=$((fail+1))
    else
        echo "SMOKE OK:   $desc (rc=$rc)"
    fi
}

check "help"            zero    help
check "system-info"     zero    system-info
check "invalid command" nonzero not-a-real-command

if (( fail > 0 )); then
    echo "smoke tests failed ($fail)" >&2
    exit 1
fi
echo "build + smoke tests passed"
exit 0
