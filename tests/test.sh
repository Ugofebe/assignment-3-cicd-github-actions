#!/usr/bin/env bash
#
# test.sh - assert the app CLI's exit-code contract.

set -u

APP="app/app.sh"
pass=0
fail=0

run_rc() { "$@" >/dev/null 2>&1; echo $?; }

assert_exit() {
    local desc="$1" expect="$2"; shift 2
    local rc; rc="$(run_rc "$@")"
    if [[ "$rc" == "$expect" ]]; then
        echo "PASS: $desc (rc=$rc)"; pass=$((pass+1))
    else
        echo "FAIL: $desc expected $expect got $rc" >&2; fail=$((fail+1))
    fi
}

assert_in_set() {
    local desc="$1" set="$2"; shift 2
    local rc; rc="$(run_rc "$@")"
    if [[ ",$set," == *",$rc,"* ]]; then
        echo "PASS: $desc (rc=$rc in {$set})"; pass=$((pass+1))
    else
        echo "FAIL: $desc expected one of {$set} got $rc" >&2; fail=$((fail+1))
    fi
}

assert_exit    "help exits 0"             0   bash "$APP" help
assert_exit    "system-info exits 0"      0   bash "$APP" system-info
assert_exit    "invalid command exits 2"  2   bash "$APP" bogus-cmd
assert_exit    "check-host missing host"  2   bash "$APP" check-host
assert_in_set  "check-host localhost 0|1" 0,1 bash "$APP" check-host localhost
assert_exit    "check-port missing port"  2   bash "$APP" check-port localhost
assert_exit    "check-port non-numeric"   2   bash "$APP" check-port localhost abc
assert_exit    "check-port port 0"        2   bash "$APP" check-port localhost 0
assert_exit    "check-port port 65536"    2   bash "$APP" check-port localhost 65536

echo "-------- $pass passed, $fail failed --------"
(( fail == 0 )) && exit 0 || exit 1
