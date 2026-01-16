#!/usr/bin/env python3
"""Append hook event payloads to reports/trace.jsonl."""
from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--event", required=True)
    ap.add_argument("--log", default="reports/trace.jsonl")
    args = ap.parse_args()

    ts = datetime.utcnow().isoformat(timespec="seconds") + "Z"
    stdin = sys.stdin.read()
    record = {
        "ts": ts,
        "event": args.event,
        "cwd": os.getcwd(),
        "stdin": stdin.strip(),
    }

    log_path = Path(args.log)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(record) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
