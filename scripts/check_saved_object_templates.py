#!/usr/bin/env python3
"""Fail when a baseline saved-object template doesn't render to valid NDJSON.

Renders every templates/saved-objects/*.ndjson.tftpl with sample values for
each placeholder dashboards.tf's template_vars declares, then parses every
line as JSON. Catches a broken export or an unescaped `${` before it fails
every workspace's import at apply time. Standard library only.

Usage: check_saved_object_templates.py (from the repo root; no arguments)
"""

import glob
import json
import re
import sys

TEMPLATES = "templates/saved-objects/*.ndjson.tftpl"
VARS_FILE = "dashboards.tf"

PLACEHOLDER = re.compile(r"(?<!\$)\$\{([A-Za-z_][A-Za-z0-9_]*)\}")
DIRECTIVE = re.compile(r"(?<!%)%\{")


def declared_vars():
    text = open(VARS_FILE, encoding="utf-8").read()
    block = re.search(r"template_vars\s*=\s*\{(.*?)\n  \}", text, re.S)
    if not block:
        sys.exit(f"{VARS_FILE}: no template_vars block found")
    return set(re.findall(r"^\s*([a-z_][a-z0-9_]*)\s*=", block.group(1), re.M))


def main():
    names = declared_vars()
    problems = []
    for path in sorted(glob.glob(TEMPLATES)):
        text = open(path, encoding="utf-8").read()
        if DIRECTIVE.search(text):
            problems.append(f"{path}: unescaped %{{ (templatefile directive); write %%{{")
        used = set(PLACEHOLDER.findall(text))
        for name in sorted(used - names):
            problems.append(f"{path}: ${{{name}}} isn't in {VARS_FILE}'s template_vars")
        rendered = PLACEHOLDER.sub(lambda m: f"sample-{m.group(1)}", text)
        rendered = rendered.replace("$${", "${").replace("%%{", "%{")
        for n, line in enumerate(rendered.splitlines(), 1):
            if not line.strip():
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError as e:
                problems.append(f"{path}:{n}: not valid JSON after rendering ({e.msg})")
                continue
            if "type" not in obj or "id" not in obj:
                problems.append(f"{path}:{n}: a saved object needs a type and an id")
    for p in problems:
        print(p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
