#!/usr/bin/env bash
# submit_monitor.sh — Submit your job array AND the monitor in one step.
#
# Usage:
#   ./submit_monitor.sh --email you@example.com [--interval 30] \
#                       [--partition <name>] [--account <name>] \
#                       -- sbatch [your normal sbatch flags] your_array.sh
#
# The script submits your array job, captures its job ID, then immediately
# submits monitor_job.sh with --dependency=afterany:<ARRAY_JOB_ID> so that
# the monitor starts only after Slurm accepts the array job.
#
# Examples:
#   # Submit an array job and monitor it
#   ./submit_monitor.sh --email alice@uni.edu -- \
#       sbatch --array=1-100 --partition=gpu my_job.sh
#
#   # Monitor an already-running array job
#   ./submit_monitor.sh --email alice@uni.edu --existing-job 987654

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Defaults ──────────────────────────────────────────────────────────────────
EMAIL=""
INTERVAL=30
PARTITION=""
ACCOUNT=""
EXISTING_JOB=""

# ── Parse our own flags (everything before --) ────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --email)       EMAIL="$2";       shift 2 ;;
        --interval)    INTERVAL="$2";    shift 2 ;;
        --partition)   PARTITION="$2";   shift 2 ;;
        --account)     ACCOUNT="$2";     shift 2 ;;
        --existing-job) EXISTING_JOB="$2"; shift 2 ;;
        --)            shift; break ;;   # everything after -- is the sbatch command
        *)             echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$EMAIL" ]]; then
    echo "ERROR: --email is required." >&2
    exit 1
fi

# ── Build extra sbatch flags for the monitor job ──────────────────────────────
EXTRA_FLAGS=()
[[ -n "$PARTITION" ]] && EXTRA_FLAGS+=(--partition "$PARTITION")
[[ -n "$ACCOUNT"   ]] && EXTRA_FLAGS+=(--account   "$ACCOUNT")

# ── Either submit a new array job or use an existing job ID ───────────────────
if [[ -n "$EXISTING_JOB" ]]; then
    ARRAY_JOB_ID="$EXISTING_JOB"
    echo "Monitoring existing job array: ${ARRAY_JOB_ID}"
else
    if [[ $# -eq 0 ]]; then
        echo "ERROR: Provide an sbatch command after '--', or use --existing-job <ID>." >&2
        exit 1
    fi

    echo "Submitting array job: $*"
    SUBMIT_OUTPUT=$("$@")          # run the sbatch command the user passed
    echo "$SUBMIT_OUTPUT"

    # Extract job ID from "Submitted batch job 12345"
    ARRAY_JOB_ID=$(echo "$SUBMIT_OUTPUT" | grep -oP '(?<=Submitted batch job )\d+')
    if [[ -z "$ARRAY_JOB_ID" ]]; then
        echo "ERROR: Could not parse job ID from sbatch output." >&2
        exit 1
    fi
    echo "Array job ID: ${ARRAY_JOB_ID}"
fi

# ── Submit the monitor job ────────────────────────────────────────────────────
# Use --dependency=after so the monitor starts once the array job begins executing.
# It will keep polling until all tasks leave the queue.
echo "Submitting monitor job..."
MONITOR_OUTPUT=$(sbatch \
    --dependency="after:${ARRAY_JOB_ID}" \
    "${EXTRA_FLAGS[@]}" \
    "${SCRIPT_DIR}/monitor_job.sh" \
    "$ARRAY_JOB_ID" \
    "$EMAIL" \
    "$INTERVAL")

echo "$MONITOR_OUTPUT"
MONITOR_JOB_ID=$(echo "$MONITOR_OUTPUT" | grep -oP '(?<=Submitted batch job )\d+')

echo ""
echo "Done."
echo "  Array job ID   : ${ARRAY_JOB_ID}"
echo "  Monitor job ID : ${MONITOR_JOB_ID}"
echo "  Notification → : ${EMAIL}"
