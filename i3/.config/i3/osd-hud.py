#!/usr/bin/env python3
"""Brightness/volume OSD: icon + bar + % — system GTK theme, no focus steal."""
from __future__ import annotations

import os
import re
import socket
import subprocess
import sys
import time
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("Pango", "1.0")
gi.require_version("PangoCairo", "1.0")
from gi.repository import Gdk, GLib, Gtk, Pango, PangoCairo  # noqa: E402

HIDE_MS = 1600
WIDTH = 220
HEIGHT = 36
MARGIN_BOTTOM = 56
PAD_X = 12
GAP = 10
BAR_H = 3
ICON_PX = 13
PCT_PX = 11
NERD = "JetBrainsMono Nerd Font"

KINDS = ("brightness", "volume")


def sock_path(kind: str) -> Path:
    return Path(os.environ.get("XDG_RUNTIME_DIR", f"/tmp/{os.getuid()}")) / f"look-osd-{kind}.sock"


def brightness_pct() -> int:
    try:
        cur = int(subprocess.check_output(["brightnessctl", "g"], text=True).strip())
        mx = int(subprocess.check_output(["brightnessctl", "m"], text=True).strip()) or 1
        return max(0, min(100, cur * 100 // mx))
    except Exception:
        return 0


def set_brightness(action: str) -> tuple[int, bool]:
    if action == "up":
        subprocess.run(["brightnessctl", "set", "+5%"], check=False, stdout=subprocess.DEVNULL)
    elif action == "down":
        subprocess.run(["brightnessctl", "set", "5%-"], check=False, stdout=subprocess.DEVNULL)
    return brightness_pct(), False


def volume_state() -> tuple[int, bool]:
    try:
        mute_out = subprocess.check_output(
            ["pactl", "get-sink-mute", "@DEFAULT_SINK@"], text=True
        )
        muted = "yes" in mute_out.lower()
        vol_out = subprocess.check_output(
            ["pactl", "get-sink-volume", "@DEFAULT_SINK@"], text=True
        )
        pcts = [int(x) for x in re.findall(r"(\d+)%", vol_out)]
        # Allow >100% (PipeWire/Pulse); bar fill is capped separately
        pct = max(0, sum(pcts) // len(pcts)) if pcts else 0
        return pct, muted
    except Exception:
        return 0, False


VOLUME_MAX_PCT = 150


def set_volume(action: str) -> tuple[int, bool]:
    if action in ("up", "down"):
        # Volume keys unmute (same as most desktop OSDs); otherwise bar stays empty
        subprocess.run(
            ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "0"],
            check=False,
            stdout=subprocess.DEVNULL,
        )
        delta = "+5%" if action == "up" else "-5%"
        subprocess.run(
            ["pactl", "set-sink-volume", "@DEFAULT_SINK@", delta],
            check=False,
            stdout=subprocess.DEVNULL,
        )
        pct, muted = volume_state()
        if pct > VOLUME_MAX_PCT:
            subprocess.run(
                ["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{VOLUME_MAX_PCT}%"],
                check=False,
                stdout=subprocess.DEVNULL,
            )
            return VOLUME_MAX_PCT, muted
        return pct, muted
    elif action == "mute":
        subprocess.run(
            ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"],
            check=False,
            stdout=subprocess.DEVNULL,
        )
    return volume_state()


def primary_geometry() -> tuple[int, int, int, int]:
    try:
        out = subprocess.check_output(["xrandr", "--current"], text=True)
    except Exception:
        return 0, 0, 1920, 1080
    primary = fallback = None
    for line in out.splitlines():
        if " connected" not in line:
            continue
        parts = line.split()
        geom = next((p for p in parts if "x" in p and "+" in p), None)
        if not geom:
            continue
        wh, _, rest = geom.partition("+")
        w_s, _, h_s = wh.partition("x")
        x_s, _, y_s = rest.partition("+")
        try:
            box = (int(x_s), int(y_s), int(w_s), int(h_s))
        except ValueError:
            continue
        if "primary" in parts:
            primary = box
        elif fallback is None:
            fallback = box
    return primary or fallback or (0, 0, 1920, 1080)


def icon_for(kind: str, pct: int, muted: bool) -> str:
    if kind == "volume":
        if muted:
            return "\U000f075f"  # nf-md-volume_mute (󰝟) — same as waybar
        if pct == 0:
            return "\uf026"  # nf-fa-volume_off
        if pct <= 30:
            return "\uf026"
        if pct <= 70:
            return "\uf027"  # nf-fa-volume_down
        return "\uf028"  # nf-fa-volume_up
    return "\uf185"  # nf-fa-sun_o


class LookOsd(Gtk.Window):
    def __init__(self, kind: str) -> None:
        super().__init__(type=Gtk.WindowType.POPUP)
        self.kind = kind
        self.set_decorated(False)
        self.set_accept_focus(False)
        self.set_focus_on_map(False)
        self.set_keep_above(True)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_resizable(False)
        self.set_size_request(WIDTH, HEIGHT)
        self.set_type_hint(Gdk.WindowTypeHint.NOTIFICATION)
        GLib.set_prgname("look-osd")
        self.stick()

        css = Gtk.CssProvider()
        css.load_from_data(
            b"""
            window.look-osd {
              background-color: @theme_bg_color;
              color: @theme_fg_color;
              border: 1px solid mix(@theme_fg_color, @theme_bg_color, 0.7);
              border-radius: 0;
            }
            """
        )
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css,
            Gtk.STYLE_PROVIDER_PRIORITY_USER,
        )
        self.get_style_context().add_class("look-osd")

        self._pct = 0
        self._muted = False
        self._hide_id = None
        self.canvas = Gtk.DrawingArea()
        self.canvas.set_size_request(WIDTH, HEIGHT)
        self.canvas.connect("draw", self._on_draw)
        self.add(self.canvas)
        self.connect("map-event", lambda *_: self._place() or False)

    def _theme_rgba(self, name: str) -> Gdk.RGBA:
        ok, color = self.get_style_context().lookup_color(name)
        if ok:
            return color
        fallback = Gdk.RGBA()
        fallback.parse("#ffffff" if "fg" in name else "#1a1b26")
        return fallback

    def _mix(self, a: Gdk.RGBA, b: Gdk.RGBA, t: float) -> tuple[float, float, float]:
        return (
            a.red * (1 - t) + b.red * t,
            a.green * (1 - t) + b.green * t,
            a.blue * (1 - t) + b.blue * t,
        )

    def _on_draw(self, widget, cr) -> bool:
        fg = self._theme_rgba("theme_fg_color")
        bg = self._theme_rgba("theme_bg_color")
        sel = self._theme_rgba("theme_selected_bg_color")
        trough = self._mix(fg, bg, 0.85)

        width = max(1, widget.get_allocated_width())
        height = max(1, widget.get_allocated_height())

        pct_layout = PangoCairo.create_layout(cr)
        pct_layout.set_font_description(Pango.FontDescription.from_string(f"{NERD} {PCT_PX}"))
        pct_layout.set_text(f"{self._pct}%", -1)
        pct_ink, _pct_log = pct_layout.get_pixel_extents()
        pct_ink_w = max(1, pct_ink.width)
        pct_ink_x = pct_ink.x
        _pct_w, pct_h = pct_layout.get_pixel_size()

        icon_layout = PangoCairo.create_layout(cr)
        icon_layout.set_font_description(Pango.FontDescription.from_string(f"{NERD} {ICON_PX}"))
        icon_layout.set_text(icon_for(self.kind, self._pct, self._muted), -1)
        icon_ink, _icon_log = icon_layout.get_pixel_extents()
        icon_ink_w = max(1, icon_ink.width)
        icon_ink_x = icon_ink.x
        _icon_w, icon_h = icon_layout.get_pixel_size()

        bar_x = PAD_X + icon_ink_w + GAP
        bar_w = max(1, width - bar_x - GAP - pct_ink_w - PAD_X)
        bar_y = (height - BAR_H) // 2
        # Bar saturates at 100%; number can read >100 like waybar
        fill_w = int(bar_w * min(100, self._pct) / 100.0)

        cr.set_source_rgb(*trough)
        cr.rectangle(bar_x, bar_y, bar_w, BAR_H)
        cr.fill()
        cr.set_source_rgb(sel.red, sel.green, sel.blue)
        cr.rectangle(bar_x, bar_y, fill_w, BAR_H)
        cr.fill()

        cr.set_source_rgb(fg.red, fg.green, fg.blue)
        cr.save()
        cr.translate(PAD_X - icon_ink_x, (height - icon_h) // 2)
        PangoCairo.show_layout(cr, icon_layout)
        cr.restore()

        cr.save()
        cr.translate(width - PAD_X - pct_ink_x - pct_ink_w, (height - pct_h) // 2)
        PangoCairo.show_layout(cr, pct_layout)
        cr.restore()
        return False

    def _place(self) -> None:
        mx, my, mw, mh = primary_geometry()
        x = mx + (mw - WIDTH) // 2
        y = my + mh - HEIGHT - MARGIN_BOTTOM
        self.move(max(mx, x), max(my, y))

    def show_state(self, pct: int, muted: bool = False) -> None:
        pct = max(0, int(pct))
        if self.kind == "brightness":
            pct = min(100, pct)
        self._pct = pct
        self._muted = bool(muted)
        self._place()
        self.show_all()
        self.canvas.queue_draw()
        self.set_keep_above(True)
        if self._hide_id is not None:
            GLib.source_remove(self._hide_id)
        self._hide_id = GLib.timeout_add(HIDE_MS, self._hide)

    def _hide(self) -> bool:
        self._hide_id = None
        self.hide()
        return False


def try_send(kind: str, pct: int, muted: bool = False) -> bool:
    path = sock_path(kind)
    if not path.exists():
        return False
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as s:
            # uint16 pct (supports >100%) + mute flag
            p = max(0, min(65535, int(pct)))
            s.sendto(bytes([(p >> 8) & 0xFF, p & 0xFF, 1 if muted else 0]), str(path))
        return True
    except OSError:
        return False


def run_server(kind: str, initial: tuple[int, bool] | None = None) -> None:
    path = sock_path(kind)
    if path.exists():
        try:
            path.unlink()
        except OSError:
            pass

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    sock.bind(str(path))
    sock.setblocking(False)

    win = LookOsd(kind)

    def on_socket(_fd, _cond):
        try:
            data, _ = sock.recvfrom(8)
            if not data:
                return True
            if len(data) >= 3:
                pct = (data[0] << 8) | data[1]
                muted = data[2] != 0
            else:
                # legacy: [pct, muted]
                pct = data[0]
                muted = len(data) > 1 and data[1] != 0
            win.show_state(pct, muted)
        except BlockingIOError:
            pass
        return True

    GLib.io_add_watch(sock.fileno(), GLib.IO_IN, on_socket)
    if initial is not None:
        pct, muted = initial
        GLib.idle_add(lambda: win.show_state(pct, muted) or False)
    Gtk.main()


def read_state(kind: str) -> tuple[int, bool]:
    return volume_state() if kind == "volume" else (brightness_pct(), False)


def apply_action(kind: str, action: str) -> tuple[int, bool]:
    if kind == "volume":
        return set_volume(action)
    return set_brightness(action)


def spawn_server(kind: str, pct: int, muted: bool) -> None:
    path = sock_path(kind)
    if path.exists():
        try:
            path.unlink()
        except OSError:
            pass

    env = os.environ.copy()
    look_env = Path.home() / ".config/i3/look.env"
    if look_env.is_file():
        for line in look_env.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            env.setdefault(k.strip(), v.strip())
    theme = env.get("GTK_THEME", "")
    if theme and ":dark" not in theme:
        env["GTK_THEME"] = f"{theme}:dark"

    subprocess.Popen(
        [
            sys.executable,
            str(Path(__file__).resolve()),
            kind,
            "--server",
            str(pct),
            "1" if muted else "0",
        ],
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        env=env,
    )
    for _ in range(40):
        time.sleep(0.05)
        if try_send(kind, pct, muted):
            return


def main() -> None:
    kind = sys.argv[1] if len(sys.argv) > 1 else ""
    if kind not in KINDS:
        print("usage: osd-hud.py brightness|volume up|down|mute|show|--server", file=sys.stderr)
        sys.exit(1)

    action = sys.argv[2] if len(sys.argv) > 2 else ""
    if action == "--server":
        pct = int(sys.argv[3]) if len(sys.argv) > 3 else read_state(kind)[0]
        muted = (sys.argv[4] == "1") if len(sys.argv) > 4 else False
        run_server(kind, (pct, muted))
        return

    allowed = ("up", "down", "show", "mute") if kind == "volume" else ("up", "down", "show")
    if action not in allowed:
        print(f"usage: osd-hud.py {kind} {'|'.join(allowed)}|--server", file=sys.stderr)
        sys.exit(1)

    pct, muted = apply_action(kind, action) if action != "show" else read_state(kind)
    if try_send(kind, pct, muted):
        return
    spawn_server(kind, pct, muted)


if __name__ == "__main__":
    main()
