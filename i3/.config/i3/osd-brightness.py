#!/usr/bin/env python3
"""Compat shim — brightness OSD lives in osd-hud.py."""
from __future__ import annotations

import runpy
import sys
from pathlib import Path

sys.argv = [sys.argv[0], "brightness", *sys.argv[1:]]
runpy.run_path(str(Path(__file__).resolve().parent / "osd-hud.py"), run_name="__main__")
