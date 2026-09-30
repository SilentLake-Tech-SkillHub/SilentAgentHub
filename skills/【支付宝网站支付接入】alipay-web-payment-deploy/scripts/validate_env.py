#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from urllib.parse import urlparse


SKILL_ROOT = Path(__file__).resolve().parents[1]
MODULE_SRC = SKILL_ROOT / "assets" / "module" / "src"
sys.path.insert(0, str(MODULE_SRC))

from alipay_web_payment import AlipayConfig, ConfigError  # noqa: E402


def load_env_file(path: Path) -> None:
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ[key.strip()] = value.strip()


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Alipay env without printing secrets")
    parser.add_argument("--env-file", help="Optional KEY=VALUE file to load before validation")
    args = parser.parse_args()
    if args.env_file:
        path = Path(args.env_file).expanduser()
        if not path.is_file():
            raise SystemExit("env file not found")
        load_env_file(path)
    try:
        config = AlipayConfig.from_env()
    except ConfigError as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False, indent=2))
        return 1
    summary = {
        "ok": True,
        "environment": config.environment,
        "gateway_host": urlparse(config.gateway_url).hostname,
        "return_host": urlparse(config.return_url).hostname,
        "notify_host": urlparse(config.notify_url).hostname,
        "app_id_present": bool(config.app_id),
        "seller_id_present": bool(config.seller_id),
        "private_key_present": bool(config.app_private_key),
        "alipay_public_key_present": bool(config.alipay_public_key),
        "amount_cny_cents": config.order_amount_cny_cents,
        "credit_units": config.credit_units,
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
