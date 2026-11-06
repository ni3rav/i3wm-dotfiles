#!/usr/bin/env bash
# Toggle maximize: fill the current workspace area (bar stays visible).
# This is not i3 fullscreen — use Super+Ctrl+f for that.
set -euo pipefail

MARK="__i3_maximized"

python3 - <<'PY'
import json
import subprocess
import sys

MARK = "__i3_maximized"


def i3_get(msg: str):
    return json.loads(subprocess.check_output(["i3-msg", "-t", msg], text=True))


def i3_cmd(command: str) -> None:
    subprocess.run(
        ["i3-msg", "-t", "command", command],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def find_focused(node, workspace=None):
    if node.get("type") == "workspace":
        workspace = node
    if node.get("focused"):
        return node, workspace
    for child in node.get("nodes", []) + node.get("floating_nodes", []):
        found, ws = find_focused(child, workspace)
        if found is not None:
            return found, ws
    return None, workspace


tree = i3_get("get_tree")
focused, workspace = find_focused(tree)
if focused is None or workspace is None:
    sys.exit(0)

marks = focused.get("marks") or []
fullscreen = int(focused.get("fullscreen_mode") or 0)

# Leave i3 fullscreen before applying workspace maximize
if fullscreen:
    i3_cmd("fullscreen disable")

if MARK in marks:
    i3_cmd(f"unmark {MARK}")
    i3_cmd("floating disable")
    sys.exit(0)

rect = workspace.get("rect") or {}
x = int(rect.get("x") or 0)
y = int(rect.get("y") or 0)
w = int(rect.get("width") or 0)
h = int(rect.get("height") or 0)
if w <= 0 or h <= 0:
    sys.exit(0)

i3_cmd(f"mark --add {MARK}")
i3_cmd("floating enable")
i3_cmd(f"resize set {w} px {h} px")
i3_cmd(f"move position {x} px {y} px")
PY
