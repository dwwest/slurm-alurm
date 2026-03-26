#!/usr/bin/env python3
"""
monitor_array.py — Poll squeue for a Slurm job array and email when done.

Usage (normally invoked by monitor_job.sh, not directly):
    python3 monitor_array.py --job-id <ARRAY_JOB_ID> --email <ADDRESS> [--interval 30]
"""

import argparse
import os
import subprocess
import sys
import time
from datetime import datetime


def parse_args():
    parser = argparse.ArgumentParser(description="Monitor a Slurm job array and email on completion.")
    parser.add_argument("--job-id", required=True, help="Slurm job array ID to watch")
    parser.add_argument("--email", required=True, help="Email address to notify on completion")
    parser.add_argument("--interval", type=int, default=30, help="Polling interval in seconds (default: 30)")
    return parser.parse_args()


def get_own_job_id():
    """Return this script's own Slurm job ID (set by Slurm in the environment)."""
    return os.environ.get("SLURM_JOB_ID", "").strip()


def query_squeue(array_job_id, own_job_id):
    """
    Run squeue for the given array job ID.
    Returns a list of job ID strings still in the queue,
    excluding this monitor's own job.
    """
    cmd = [
        "squeue",
        "--job", array_job_id,
        "--noheader",
        "--format=%i",   # print only the job/task ID
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
        # Exclude the monitor's own job ID (exact match on base job ID)
        if own_job_id:
            lines = [j for j in lines if j != own_job_id]
        return lines
    except subprocess.TimeoutExpired:
        print(f"[{timestamp()}] WARNING: squeue timed out, will retry next cycle.", flush=True)
        return None  # None signals a transient error; keep looping
    except FileNotFoundError:
        print("ERROR: 'squeue' not found. Is this running on a Slurm cluster?", file=sys.stderr)
        sys.exit(1)


def send_email(to_address, subject, body):
    cmd = ["mail", "-s", subject, to_address]
    try:
        subprocess.run(cmd, input=body, text=True, timeout=30, check=True)
        print(f"[{timestamp()}] Email sent to {to_address}.", flush=True)
    except subprocess.CalledProcessError as exc:
        print(f"[{timestamp()}] WARNING: mail command failed (exit {exc.returncode}). "
              "Check that sendmail/postfix is configured on this host.", file=sys.stderr)
    except FileNotFoundError:
        print(f"[{timestamp()}] WARNING: 'mail' command not found. "
              "Email not sent. Install mailutils/sendmail on this host.", file=sys.stderr)


def send_completion_email(to_address, array_job_id, start_time):
    elapsed = time.time() - start_time
    hours, rem = divmod(int(elapsed), 3600)
    minutes, seconds = divmod(rem, 60)
    elapsed_str = f"{hours}h {minutes}m {seconds}s"

    subject = f"[SLURM ALURM] Job array {array_job_id} completed"
    body = (
        f"Your Slurm job array {array_job_id} has finished.\n\n"
        f"All tasks left the queue at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
        f"Total monitoring time:       {elapsed_str}\n\n"
        f"This notification was sent by monitor_array.py running on {os.uname().nodename}.\n"
    )
    send_email(to_address, subject, body)


def send_error_email(to_address, array_job_id):
    subject = f"[SLURM ALURM] ERROR: Job array {array_job_id} not found"
    body = (
        f"monitor_array.py could not find job array {array_job_id} in squeue.\n\n"
        f"The job may not exist, may have already finished before monitoring began,\n"
        f"or the job ID may be incorrect.\n\n"
        f"No completion notification will be sent.\n\n"
        f"This error was reported by monitor_array.py running on {os.uname().nodename}.\n"
    )
    send_email(to_address, subject, body)


def timestamp():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def main():
    args = parse_args()
    own_job_id = get_own_job_id()

    print(f"[{timestamp()}] Monitor started.", flush=True)
    print(f"[{timestamp()}] Watching job array : {args.job_id}", flush=True)
    print(f"[{timestamp()}] Notify address      : {args.email}", flush=True)
    print(f"[{timestamp()}] Poll interval        : {args.interval}s", flush=True)
    print(f"[{timestamp()}] Own Slurm job ID     : {own_job_id or '(not running under Slurm)'}", flush=True)

    start_time = time.time()
    ever_seen = False  # becomes True once the job appears in squeue

    while True:
        jobs = query_squeue(args.job_id, own_job_id)

        if jobs is None:
            # Transient squeue error — wait and retry
            time.sleep(args.interval)
            continue

        if jobs:
            ever_seen = True
            print(f"[{timestamp()}] {len(jobs)} task(s) still queued/running: {', '.join(jobs[:10])}"
                  f"{'...' if len(jobs) > 10 else ''}", flush=True)
        elif ever_seen:
            print(f"[{timestamp()}] No tasks remaining. Sending notification.", flush=True)
            send_completion_email(args.email, args.job_id, start_time)
            break
        else:
            print(f"[{timestamp()}] WARNING: job {args.job_id} not found in squeue. "
                  "It may not exist, may have already finished, or the ID may be wrong. "
                  "Sending error notification.", file=sys.stderr, flush=True)
            send_error_email(args.email, args.job_id)
            sys.exit(1)

        time.sleep(args.interval)

    print(f"[{timestamp()}] Monitor finished.", flush=True)


if __name__ == "__main__":
    main()
