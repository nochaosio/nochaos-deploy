#!/usr/bin/env python3
"""Checks tools/catalog.yaml: every tool has what the catalog promises, ids
are unique, and TOOLS.md is the table generated from it (run with --write
to regenerate it). Needs PyYAML."""
import pathlib
import re
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
PROFILES = {"single", "ha", "cloud"}
REQUIRED = ("id", "name", "role", "license", "homepage", "profiles", "used_by")


def table(tools):
    lines = ["| Tool | What it does for nochaos | License | Version | Profiles | Used by |", "|---|---|---|---|---|---|"]
    for t in tools:
        lines.append(f"| [{t['name']}]({t['homepage']}) | {t['role']} | {t['license']} | {t.get('version', '')} | "
                     f"{', '.join(t['profiles'])} | {', '.join(t['used_by'])} |")
    return "\n".join(lines) + "\n"


def main():
    tools = yaml.safe_load((ROOT / "tools/catalog.yaml").read_text())["tools"]
    errors, seen = [], set()
    for t in tools:
        tid = t.get("id", "?")
        for key in REQUIRED:
            if not t.get(key):
                errors.append(f"{tid}: {key} is missing")
        if not re.fullmatch(r"[a-z][a-z0-9]*(-[a-z0-9]+)*", str(tid)):
            errors.append(f"{tid}: id must be lowercase with dashes")
        if tid in seen:
            errors.append(f"{tid}: listed twice")
        seen.add(tid)
        for p in t.get("profiles") or []:
            if p not in PROFILES:
                errors.append(f"{tid}: unknown profile {p}")
    doc = ROOT / "TOOLS.md"
    head = ("# Tools\n\nThe open-source software nochaos is built on. nochaos is a layer above these\n"
            "tools. This table is generated from [tools/catalog.yaml](tools/catalog.yaml):\n"
            "edit the catalog and run `scripts/check.py --write`.\n\n")
    want = head + table(tools)
    if "--write" in sys.argv:
        doc.write_text(want)
    elif not doc.exists() or doc.read_text() != want:
        errors.append("TOOLS.md is out of date: run scripts/check.py --write")
    for e in errors:
        print("ERROR", e)
    print(f"{len(tools)} tools, {len(errors)} errors")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
