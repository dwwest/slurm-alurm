#!/usr/bin/env bash
# test_job.sh — Dummy array job for testing slurm_alurm.
# Each task sleeps for 5 minutes then exits cleanly.
#
# Submit and monitor in one step:
#   ./submit_monitor.sh --email devany.west@omsf.io -- \
#       sbatch --array=1-3 test_job.sh
#
# Or submit the array first, then monitor manually:
#   sbatch --array=1-3 test_job.sh
#   alurm <JOB_ID>
#
#SBATCH --job-name=alurm_test
#SBATCH --output=alurm_test_%A_%a.out
#SBATCH --error=alurm_test_%A_%a.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64M
#SBATCH --time=00:10:00
# --partition and --account are intentionally left unset; pass via sbatch flags
# or uncomment and fill in:
# #SBATCH --partition=your_partition
# #SBATCH --account=your_account

set -euo pipefail

echo "Task ${SLURM_ARRAY_TASK_ID} of job ${SLURM_ARRAY_JOB_ID} starting on $(hostname)"
echo "Sleeping for 5 minutes..."

sleep 300

echo "Task ${SLURM_ARRAY_TASK_ID} done."
