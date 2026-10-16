#!/usr/bin/env python3
"""Turn a Kibana saved-objects export from one workspace's space into a
template the module renders for every workspace
(templates/saved-objects/*.ndjson.tftpl, docs/BASELINE-CONTENT.md).

- drops the export summary line and data views (index-pattern): the module
  owns the data views, and importing one would overwrite it;
- drops what Kibana sets on save (version, created_at, updated_at,
  created_by, updated_by);
- replaces the workspace id in ids, references and nested JSON
  (`"<id>-...`, `-*-<id>"`) with ${workspace_id};
- escapes anything else templatefile() would read as a template sequence.

Standard library only.

Usage: templatize-saved-objects.py EXPORT.ndjson --workspace ID [-o OUT]
       (OUT defaults to stdout)
"""

import argparse
import json
import re
import sys

VOLATILE = ("version", "created_at", "updated_at", "created_by", "updated_by")
PLACEHOLDER = "\x00WORKSPACE_ID\x00"


def templatize(line, workspace):
    obj = json.loads(line)
    if "type" not in obj or obj["type"] == "index-pattern":
        return None
    for key in VOLATILE:
        obj.pop(key, None)
    text = json.dumps(obj, sort_keys=True, separators=(",", ":"))
    ws = re.escape(workspace)
    # A quote (or an escaped quote, inside nested JSON) before the id: an
    # object or data view id `<id>-...`. After it: an index pattern
    # `<type>-*-<id>`.
    text = re.sub(r'(\\*")' + ws + "-", lambda m: m.group(1) + PLACEHOLDER + "-", text)
    text = re.sub(r"-\*-" + ws + r'(\\*")', lambda m: "-*-" + PLACEHOLDER + m.group(1), text)
    # templatefile() reads ${ and %{; anything Kibana wrote stays literal.
    text = text.replace("${", "$${").replace("%{", "%%{")
    return text.replace(PLACEHOLDER, "${workspace_id}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("export", help="the .ndjson Kibana exported")
    parser.add_argument("--workspace", required=True, help="the id of the workspace it was exported from")
    parser.add_argument("-o", "--output", help="the .ndjson.tftpl to write (default: stdout)")
    args = parser.parse_args()

    if not re.fullmatch(r"[a-z0-9_]{1,64}", args.workspace) or args.workspace == "default":
        sys.exit("--workspace must be a workspace id: ^[a-z0-9_]{1,64}$, not default")

    with open(args.export, encoding="utf-8") as f:
        lines = [templatize(l, args.workspace) for l in f if l.strip()]
    lines = [l for l in lines if l is not None]
    if not lines:
        sys.exit("no saved objects left (only data views or the summary?)")
    if not any("${workspace_id}" in l for l in lines):
        print(f"warning: '{args.workspace}' appears nowhere: is it the right workspace?", file=sys.stderr)

    out = open(args.output, "w", encoding="utf-8") if args.output else sys.stdout
    with out:
        out.write("\n".join(lines) + "\n")
    print(f"{len(lines)} saved objects", file=sys.stderr)


if __name__ == "__main__":
    main()
