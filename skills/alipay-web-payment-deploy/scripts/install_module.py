#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path


SKILL_ROOT = Path(__file__).resolve().parents[1]
MODULE_ROOT = SKILL_ROOT / "assets" / "module"


def destination_plan(project_root: Path, backend_dir: str, frontend_dir: str, env_file: str):
    return {
        "backend": project_root / backend_dir / "alipay_web_payment",
        "frontend": project_root / frontend_dir / "alipay-checkout.js",
        "env": project_root / env_file,
        "manifest": project_root / ".alipay-web-payment-module.json",
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Install the reusable Alipay website payment module without copying secrets"
    )
    parser.add_argument("--project-root", required=True)
    parser.add_argument("--backend-dir", default="vendor")
    parser.add_argument("--frontend-dir", default="public/assets")
    parser.add_argument("--env-file", default=".env.alipay.example")
    parser.add_argument("--apply", action="store_true", help="Apply the plan; default is dry-run")
    args = parser.parse_args()

    project_root = Path(args.project_root).expanduser().resolve()
    if not project_root.is_dir():
        raise SystemExit("project root does not exist")
    if not MODULE_ROOT.is_dir():
        raise SystemExit("skill module asset is missing")

    plan = destination_plan(project_root, args.backend_dir, args.frontend_dir, args.env_file)
    collisions = [str(path) for path in plan.values() if path.exists()]
    output = {
        "mode": "apply" if args.apply else "dry-run",
        "module_version": (MODULE_ROOT / "VERSION").read_text(encoding="utf-8").strip(),
        "destinations": {key: str(value) for key, value in plan.items()},
        "collisions": collisions,
    }
    print(json.dumps(output, ensure_ascii=False, indent=2))
    if not args.apply:
        return 0
    if collisions:
        raise SystemExit("refusing to overwrite existing paths; integrate the diff manually")

    plan["backend"].parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(MODULE_ROOT / "src" / "alipay_web_payment", plan["backend"])
    plan["frontend"].parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(MODULE_ROOT / "frontend" / "alipay-checkout.js", plan["frontend"])
    shutil.copy2(MODULE_ROOT / ".env.example", plan["env"])
    plan["manifest"].write_text(
        json.dumps(output, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print("installed=true")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
