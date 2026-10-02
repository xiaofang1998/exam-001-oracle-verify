#!/bin/bash
# Oracle solution for exam_001.
#
# Reads the access log at /data/access.log and writes the report to
# /output/report.txt in exactly the format required by instruction.md.

set -euo pipefail

LOG_FILE="${LOG_FILE:-/data/access.log}"
REPORT_FILE="${REPORT_FILE:-/output/report.txt}"

if [ ! -r "$LOG_FILE" ]; then
    echo "ERROR: access log not found or not readable: $LOG_FILE" >&2
    exit 1
fi

mkdir -p "$(dirname "$REPORT_FILE")"

SOLUTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Preferred path: the Python helper shipped next to this script. Harbor copies
# the whole solution/ directory to /solution, so the helper is always there.
# (LOG_FILE/REPORT_FILE overrides exist only for local testing; the graded run
# uses the defaults above.)
if command -v python3 >/dev/null 2>&1 && [ -r "$SOLUTION_DIR/oracle_convert.py" ]; then
    python3 "$SOLUTION_DIR/oracle_convert.py" "$LOG_FILE" "$REPORT_FILE"
    exit 0
fi

# Fallback for images without Python: pure Bash, no external tools beyond the
# shell that is already running this script. It produces the same report.
declare -A ip_count=()
declare -A status_count=()

line_re='"[^"]*"[[:space:]]+([1-5][0-9][0-9])'
while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ $line_re ]]; then
        ip="${line%%[[:space:]]*}"
        status="${BASH_REMATCH[1]}"
        ip_count["$ip"]=$(( ${ip_count["$ip"]:-0} + 1 ))
        status_count["$status"]=$(( ${status_count["$status"]:-0} + 1 ))
    fi
done < "$LOG_FILE"

# Most requests first; ties are broken by IP so output is deterministic.
best_ip=""
best_count=-1
for ip in "${!ip_count[@]}"; do
    count="${ip_count[$ip]}"
    if (( count > best_count )) || { (( count == best_count )) && [[ "$ip" < "$best_ip" ]]; }; then
        best_ip="$ip"
        best_count="$count"
    fi
done

{
    printf '=== Top IP ===\n'
    if [ -n "$best_ip" ]; then
        printf '%s: %d requests\n' "$best_ip" "$best_count"
    fi
    printf '\n=== Status Code Distribution ===\n'
    for ((code = 100; code <= 599; code++)); do
        if [ -n "${status_count[$code]:-}" ]; then
            printf '%s: %d\n' "$code" "${status_count[$code]}"
        fi
    done
} > "$REPORT_FILE"
