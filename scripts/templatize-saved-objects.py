#!/usr/bin/env python3
"""Turn a Kibana saved-objects export into a module template.

Usage:
  scripts/templatize-saved-objects.py export.ndjson \
      --data-view-id <id-of-the-logs-data-view-in-the-sandbox-space>=logs_data_view_id \
      --workspace <sandbox-workspace-id> \
      > templates/saved-objects/<name>.ndjson.tftpl

- Escapes any existing ${ and %{ so templatefile() leaves them alone.
- Replaces each data view id with its ${placeholder} (see template_vars in
  dashboards.tf for the names a template may use).
- Replaces the sandbox workspace id with ${workspace}.
- Drops the export summary line Kibana appends.
"""
import argparse
import json
import sys


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("export")
    p.add_argument("--data-view-id", action="append", default=[], metavar="ID=PLACEHOLDER")
    p.add_argument("--workspace", required=True, help="workspace id used in the sandbox space")
    args = p.parse_args()

    mapping = []
    for item in args.data_view_id:
        old, _, new = item.partition("=")
        if not old or not new:
            p.error(f"--data-view-id must be ID=PLACEHOLDER, got {item!r}")
        mapping.append((old, "${" + new + "}"))

    out = []
    with open(args.export, encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            obj = json.loads(line)
            if "exportedCount" in obj:  # trailing summary line
                continue
            for k in ("updated_at", "created_at", "version", "namespaces"):
                obj.pop(k, None)
            text = json.dumps(obj, separators=(",", ":"), ensure_ascii=False)
            text = text.replace("${", "$${").replace("%{", "%%{")
            for old, new in mapping:
                text = text.replace(old, new)
            text = text.replace(args.workspace, "${workspace}")
            out.append(text)

    if not out:
        print("no saved objects found", file=sys.stderr)
        return 1
    sys.stdout.write("\n".join(out) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
