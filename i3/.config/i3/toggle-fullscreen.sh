#!/usr/bin/env bash
# True fullscreen: covers the whole output and hides the polybar.
# If the window was "maximized" (bar still visible), clear that first.
set -euo pipefail

python3 - <<'PY'
import json
import subprocess
import sys

MARK = "__i3_maximized"
BORDER_NORMAL = "border pixel 4"


def i3_get(msg: str):
    return json.loads(subprocess.check_output(["i3-msg", "-t", msg], text=True))


def i3_cmd(command: str) -> None:
    subprocess.run(
        ["i3-msg", "-t", "command", command],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def find_focused(node):
    if node.get("focused"):
        return node
    for child in node.get("nodes", []) + node.get("floating_nodes", []):
        found = find_focused(child)
        if found is not None:
            return found
    return None


tree = i3_get("get_tree")
focused = find_focused(tree)
if focused is None:
    sys.exit(0)

con_id = int(focused["id"])
marks = focused.get("marks") or []
fullscreen = int(focused.get("fullscreen_mode") or 0)
target = f"[con_id={con_id}]"

# Entering true fullscreen from maximize: drop floating maximize state
if MARK in marks and not fullscreen:
    i3_cmd(f"{target} unmark {MARK}")
    i3_cmd(f"{target} floating disable")
    i3_cmd(f"{target} {BORDER_NORMAL}")

i3_cmd(f"{target} fullscreen toggle")
PY
