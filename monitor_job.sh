#!/usr/bin/env bash
# monitor_job.sh — Slurm batch script that runs monitor_array.py.
# Submit with: sbatch monitor_job.sh <ARRAY_JOB_ID> <EMAIL> [INTERVAL_SECONDS]
#
# Slurm directives — adjust partition/account/time to match your cluster.
#SBATCH --job-name=array_monitor
#SBATCH --output=logs/monitor_%j.out
#SBATCH --error=logs/monitor_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64M
#SBATCH --time=24:00:00          # extend if your array may run longer than 24 h
# --partition and --account are intentionally left unset; pass them via sbatch flags
# or uncomment and fill in:
# #SBATCH --partition=your_partition
# #SBATCH --account=your_account

set -euo pipefail

# ── Conda initialisation ───────────────────────────────────────────────────────
# shellcheck source=/dev/null
source ~/miniforge3/etc/profile.d/conda.sh
conda activate slurm_alurm

# ── Argument handling ──────────────────────────────────────────────────────────
if [[ $# -lt 2 ]]; then
    echo "Usage: sbatch monitor_job.sh <ARRAY_JOB_ID> <EMAIL> [INTERVAL_SECONDS]"
    exit 1
fi

ARRAY_JOB_ID="$1"
EMAIL="$2"
INTERVAL="${3:-30}"

# ── Locate monitor_array.py (use env var when Slurm copies script to spool dir) ─
SCRIPT_DIR="${SLURM_ALURM_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
MONITOR_PY="${SCRIPT_DIR}/monitor_array.py"

if [[ ! -f "$MONITOR_PY" ]]; then
    echo "ERROR: monitor_array.py not found at $MONITOR_PY" >&2
    exit 1
fi

echo "Starting monitor for job array: ${ARRAY_JOB_ID}"
echo "Notification will be sent to:  ${EMAIL}"
echo "Poll interval:                 ${INTERVAL}s"

python "$MONITOR_PY" \
    --job-id   "$ARRAY_JOB_ID" \
    --email    "$EMAIL" \
    --interval "$INTERVAL"
