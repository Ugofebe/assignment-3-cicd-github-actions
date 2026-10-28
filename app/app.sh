#!/usr/bin/env bash
#
# app.sh - Linux diagnostic CLI.
# Usage: app.sh <command> [args]
#   system-info            show Linux system information
#   check-host <host>      resolve a host and check reachability
#   check-port <host> <p>  validate a port and test a TCP connection
#   help                   show usage
# Exit: 0 success, 1 operational failure, 2 invalid command or input.

set -u

LOG_DIR="logs"
SCRIPT_NAME="app.sh"

log() {
    local msg="$1" ts
    ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
    mkdir -p "$LOG_DIR" 2>/dev/null || return 0
    printf '%s [%s] %s\n' "$ts" "$SCRIPT_NAME" "$msg" >> "$LOG_DIR/app.log" 2>/dev/null || true
}

usage() {
    cat <<'USAGE'
app.sh - Linux diagnostic CLI

Usage:
  app.sh <command> [args]

Commands:
  system-info            Show Linux system information
  check-host <host>      Resolve <host> and check reachability
  check-port <host> <p>  Validate a port and test a TCP connection
  help                   Show this help text

Exit codes:
  0  success
  1  operational failure (unreachable host / closed port)
  2  invalid command, unknown command, or invalid input
USAGE
}

system_info() {
    local host user now os kernel up cpu mem cwd
    host="$(hostname 2>/dev/null || cat /proc/sys/kernel/hostname 2>/dev/null || uname -n)"
    user="$(whoami 2>/dev/null || id -un 2>/dev/null || printf '%s' "${USER:-unknown}")"
    now="$(date)"
    if [[ -r /etc/os-release ]]; then
        # shellcheck source=/dev/null
        os="$( . /etc/os-release && printf '%s' "${PRETTY_NAME:-$(uname -s)}" )"
    else
        os="$(uname -s)"
    fi
    kernel="$(uname -s -r)"
    if uptime >/dev/null 2>&1; then up="$(uptime)"; else up="unavailable"; fi
    if [[ -r /proc/cpuinfo ]]; then
        local model count
        model="$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')"
        count="$(grep -c '^processor' /proc/cpuinfo)"
        cpu="${model:-unknown} (${count} cores)"
    elif command -v nproc >/dev/null 2>&1; then
        cpu="$(nproc) cores"
    else
        cpu="unavailable"
    fi
    if command -v free >/dev/null 2>&1; then
        mem="$(free -h | awk 'NR==2 {print $3 " used / " $2 " total"}')"
    else
        mem="unavailable"
    fi
    cwd="$(pwd)"

    printf 'Hostname: %s\n' "$host"
    printf 'Current User: %s\n' "$user"
    printf 'Date/Time: %s\n' "$now"
    printf 'Operating System: %s\n' "$os"
    printf 'Kernel Version: %s\n' "$kernel"
    printf 'Uptime: %s\n' "$up"
    printf 'CPU: %s\n' "$cpu"
    printf 'Memory: %s\n' "$mem"
    printf 'Working Directory: %s\n' "$cwd"

    log "reported system information"
    exit 0
}

check_host() {
    local host="$1"
    if [[ -z "$host" ]]; then
        echo "Error: 'check-host' requires a host argument" >&2
        usage >&2
        log "check-host called without host"
        exit 2
    fi

    local addr
    addr="$(getent hosts "$host" 2>/dev/null | awk '{print $1; exit}')"
    [[ -z "$addr" ]] && addr="$(host "$host" 2>/dev/null | awk '/has address/{print $NF; exit}')"
    [[ -z "$addr" ]] && addr="$(python3 -c 'import socket,sys; print(socket.gethostbyname(sys.argv[1]))' "$host" 2>/dev/null)"
    [[ -z "$addr" ]] && addr="$(ping -c 1 "$host" 2>/dev/null | sed -n 's/.*(\([0-9.]*\)).*/\1/p' | head -n1)"

    printf 'Host: %s\n' "$host"
    printf 'Resolved address: %s\n' "${addr:-unresolved}"

    local reachable=1 p
    if command -v ping >/dev/null 2>&1 && ping -c 1 -W 1 "$host" >/dev/null 2>&1; then
        reachable=0
    else
        for p in 80 443 22; do
            if timeout 2 bash -c ">/dev/tcp/$host/$p" 2>/dev/null; then
                reachable=0; break
            fi
        done
    fi
    printf 'Connectivity: %s\n' "$([[ $reachable -eq 0 ]] && echo reachable || echo unreachable)"
    log "check-host host=$host addr=${addr:-unresolved} reachable=$reachable"
    exit "$reachable"
}

check_port() {
    local host="$1" port="$2"
    if [[ -z "$host" || -z "$port" ]]; then
        echo "Error: 'check-port' requires <host> and <port>" >&2
        usage >&2
        log "check-port missing host or port"
        exit 2
    fi
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        echo "Error: port '$port' is not a number" >&2
        log "check-port non-numeric port '$port'"
        exit 2
    fi
    if (( port < 1 || port > 65535 )); then
        echo "Error: port '$port' out of range 1-65535" >&2
        log "check-port out-of-range port '$port'"
        exit 2
    fi

    local open=1
    if timeout 2 bash -c ">/dev/tcp/$host/$port" 2>/dev/null; then
        open=0
    elif command -v nc >/dev/null 2>&1 && nc -z -w 2 "$host" "$port" >/dev/null 2>&1; then
        open=0
    fi
    printf 'Host: %s\nPort: %s\nStatus: %s\n' "$host" "$port" "$([[ $open -eq 0 ]] && echo open || echo closed)"
    log "check-port host=$host port=$port open=$open"
    exit "$open"
}

cmd="${1:-}"

if [[ -z "$cmd" ]]; then
    echo "Error: no command given" >&2
    usage >&2
    log "invoked with no command"
    exit 2
fi

case "$cmd" in
    system-info)
        system_info
        ;;
    check-host)
        check_host "${2:-}"
        ;;
    check-port)
        check_port "${2:-}" "${3:-}"
        ;;
    help|-h|--help)
        usage
        exit 0
        ;;
    *)
        echo "Error: unknown command '$cmd'" >&2
        usage >&2
        log "unknown command: '$cmd'"
        exit 2
        ;;
esac
