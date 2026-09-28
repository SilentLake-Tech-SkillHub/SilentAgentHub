#!/usr/bin/env python3
"""Evaluate whether newest-wins is safe for two knowledge artifact records."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone


def parse_time(value: str) -> datetime:
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("left", help="JSON metadata for the project copy")
    parser.add_argument("right", help="JSON metadata for the hub copy")
    parser.add_argument("--hours", type=float, default=24.0)
    args = parser.parse_args()

    left = json.loads(args.left)
    right = json.loads(args.right)
    same_lineage = left.get("artifact_id") == right.get("artifact_id") and bool(left.get("artifact_id"))
    delta_hours = abs((parse_time(left["modified_at"]) - parse_time(right["modified_at"])).total_seconds()) / 3600
    protected = bool(left.get("protected") or right.get("protected"))
    both_changed = bool(left.get("changed_since_base") and right.get("changed_since_base"))
    eligible = same_lineage and delta_hours <= args.hours and not protected and not both_changed
    winner = None
    if eligible and left.get("sha256") != right.get("sha256"):
        winner = "left" if parse_time(left["modified_at"]) > parse_time(right["modified_at"]) else "right"

    print(json.dumps({
        "eligible": eligible,
        "winner": winner,
        "same_lineage": same_lineage,
        "delta_hours": delta_hours,
        "protected": protected,
        "both_changed": both_changed,
    }, ensure_ascii=False, indent=2))
    return 0 if eligible else 2


if __name__ == "__main__":
    raise SystemExit(main())
