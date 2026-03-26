# slurm_alurm — Slurm Array Monitor

Polls `squeue` every 30 seconds and emails you when a Slurm job array finishes.

## Files

| File | Purpose |
|---|---|
| `monitor_array.py` | Python poller — does the actual work |
| `monitor_job.sh` | `sbatch` wrapper that submits the poller as a Slurm job |
| `submit_monitor.sh` | Convenience script: submit your array **and** the monitor together |
| `test_job.sh` | Dummy array job (5-minute sleep) for end-to-end testing |

---

## Quick start

### Option A — Submit your array and monitor together

```bash
./submit_monitor.sh --email you@example.com -- \
    sbatch --array=1-100 --partition=gpu my_job.sh
```

This submits `my_job.sh` as a job array, then immediately submits the monitor
with `--dependency=afterany:<ARRAY_JOB_ID>` so it starts as soon as Slurm
accepts the array.

### Option B — Monitor an already-running array job

```bash
./submit_monitor.sh --email you@example.com --existing-job 987654
```

### Option C — Submit the monitor manually

```bash
sbatch monitor_job.sh <ARRAY_JOB_ID> <EMAIL> [INTERVAL_SECONDS]
# e.g.
sbatch monitor_job.sh 987654 you@example.com 60
```

---

## Testing

`test_job.sh` is a dummy array job where each task sleeps for 5 minutes then
exits cleanly. Use it to verify the monitor works end-to-end.

### Option A — Submit array and monitor together

```bash
./submit_monitor.sh --email you@example.com -- \
    sbatch --array=1-3 test_job.sh
```

### Option B — Submit array first, then monitor with the alias

```bash
sbatch --array=1-3 test_job.sh
alurm <JOB_ID>
```

You'll receive an email once all tasks complete. Output logs are written to
`alurm_test_<ARRAY_ID>_<TASK_ID>.out` in the working directory.

---

## Options

### `submit_monitor.sh`

| Flag | Default | Description |
|---|---|---|
| `--email <addr>` | *(required)* | Notification address |
| `--interval <sec>` | `30` | Poll interval in seconds |
| `--partition <name>` | *(unset)* | Slurm partition for the monitor job |
| `--account <name>` | *(unset)* | Slurm account for the monitor job |
| `--existing-job <id>` | *(unset)* | Skip array submission; watch this ID |

### `monitor_array.py`

```
python3 monitor_array.py --job-id <ID> --email <addr> [--interval 30]
```

---

## How it works

1. `monitor_array.py` reads its own `$SLURM_JOB_ID` from the environment.
2. Every `--interval` seconds it runs:
   ```
   squeue --job <ARRAY_JOB_ID> --noheader --format=%i
   ```
3. It removes its own job ID from the results so it doesn't count itself.
4. When the result is empty, it calls `mail -s "..." <EMAIL>` to send a
   notification and exits cleanly.

---

## Prerequisites

- Python 3.6+ (standard library only — no extra packages needed)
- `mail` / `sendmail` must be configured on the cluster head/compute nodes
  (most HPC clusters have this; check with `which mail`)
- Copy all three files to the same directory on the remote server

## Slurm directives

Edit the `#SBATCH` block in `monitor_job.sh` to match your cluster:

```bash
#SBATCH --time=24:00:00      # must be ≥ expected total array runtime
#SBATCH --partition=<name>
#SBATCH --account=<name>
```

The monitor is very lightweight (1 CPU, 256 MB RAM).
