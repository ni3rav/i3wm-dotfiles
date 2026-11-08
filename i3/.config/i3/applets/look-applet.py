#!/usr/bin/env python3
"""Compact themed popups for WiFi, Bluetooth, brightness, volume, performance."""
from __future__ import annotations

import os
import re
import socket
import subprocess
import sys
import threading
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

# Must run before windows map or i3 rules won't match (class becomes Look-applet.py)
GLib.set_prgname("look-applet")
Gdk.set_program_class("look-applet")

WIDTH = 340
HEIGHT_TALL = 420
HEIGHT_COMPACT = 220
BAR_H = 34
MARGIN = 8
KINDS = ("network", "bluetooth", "brightness", "volume", "performance")
TITLES = {
    "network": "Wi‑Fi",
    "bluetooth": "Bluetooth",
    "brightness": "Brightness",
    "volume": "Volume",
    "performance": "Performance",
}
NERD = "JetBrainsMono Nerd Font"
PERF_PROFILES = (
    ("power-saver", "Power saver"),
    ("balanced", "Balanced"),
    ("performance", "Performance"),
)


def runtime_dir() -> Path:
    return Path(os.environ.get("XDG_RUNTIME_DIR", f"/tmp/{os.getuid()}"))


def sock_path(kind: str) -> Path:
    return runtime_dir() / f"look-applet-{kind}.sock"


def run(cmd: list[str], timeout: float = 12.0) -> tuple[int, str]:
    try:
        p = subprocess.run(
            cmd,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return p.returncode, (p.stdout or "") + (p.stderr or "")
    except (OSError, subprocess.TimeoutExpired) as e:
        return 1, str(e)


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


def load_look_env() -> None:
    look_env = Path.home() / ".config/i3/look.env"
    if not look_env.is_file():
        return
    for line in look_env.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        os.environ.setdefault(k.strip(), v.strip())
    theme = os.environ.get("GTK_THEME", "")
    if theme and ":dark" not in theme:
        os.environ["GTK_THEME"] = f"{theme}:dark"


# --- WiFi -------------------------------------------------------------------

def wifi_radio() -> bool:
    rc, out = run(["nmcli", "-t", "radio", "wifi"])
    return rc == 0 and "enabled" in out.lower()


def set_wifi_radio(on: bool) -> None:
    run(["nmcli", "radio", "wifi", "on" if on else "off"])


def wifi_networks() -> list[dict]:
    run(["nmcli", "device", "wifi", "rescan"], timeout=8.0)
    rc, out = run(
        ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]
    )
    if rc != 0:
        return []
    seen: set[str] = set()
    rows: list[dict] = []
    for line in out.splitlines():
        if not line or line.count(":") < 3:
            continue
        in_use, ssid, signal, security = line.split(":", 3)
        ssid = ssid.strip()
        if not ssid or ssid in seen:
            continue
        seen.add(ssid)
        try:
            sig = int(signal)
        except ValueError:
            sig = 0
        rows.append(
            {
                "ssid": ssid,
                "signal": sig,
                "security": security.strip(),
                "active": in_use.strip() == "*",
            }
        )
    rows.sort(key=lambda r: (-r["active"], -r["signal"], r["ssid"].lower()))
    return rows


def wifi_known(ssid: str) -> bool:
    rc, out = run(["nmcli", "-t", "-f", "NAME", "connection", "show"])
    if rc != 0:
        return False
    return any(line.strip() == ssid for line in out.splitlines())


def wifi_connect(ssid: str, password: str | None) -> tuple[bool, str]:
    if wifi_known(ssid) and not password:
        rc, out = run(["nmcli", "connection", "up", "id", ssid], timeout=45.0)
        if rc == 0:
            return True, out.strip() or "Connected"
    cmd = ["nmcli", "device", "wifi", "connect", ssid]
    if password:
        cmd.extend(["password", password])
    rc, out = run(cmd, timeout=45.0)
    return rc == 0, out.strip() or ("Connected" if rc == 0 else "Connect failed")


def wifi_disconnect() -> None:
    rc, out = run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device", "status"])
    for line in out.splitlines():
        parts = line.split(":")
        if len(parts) >= 3 and parts[1] == "wifi" and parts[2].startswith("connected"):
            run(["nmcli", "device", "disconnect", parts[0]])
            return


def wifi_active_from(nets: list[dict]) -> dict | None:
    return next((n for n in nets if n["active"]), None)


def wifi_active_connection() -> dict | None:
    """Active Wi‑Fi profile: connection id, SSID, PSK, security key-mgmt."""
    rc, out = run(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active"])
    if rc != 0:
        return None
    conn = None
    for line in out.splitlines():
        if ":" not in line:
            continue
        name, typ = line.rsplit(":", 1)
        if typ.strip() in ("802-11-wireless", "wifi", "802-11-wireless-security"):
            conn = name
            break
    if not conn:
        return None
    rc, fields = run(
        [
            "nmcli",
            "-s",
            "-g",
            "802-11-wireless.ssid,802-11-wireless-security.psk,802-11-wireless-security.key-mgmt",
            "connection",
            "show",
            "id",
            conn,
        ]
    )
    if rc != 0:
        return None
    parts = fields.splitlines()
    ssid = parts[0] if parts else conn
    psk = parts[1] if len(parts) > 1 else ""
    key_mgmt = parts[2] if len(parts) > 2 else ""
    return {"id": conn, "ssid": ssid, "password": psk, "key_mgmt": key_mgmt}


def _wifi_qr_escape(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace(";", "\\;")
        .replace(",", "\\,")
        .replace('"', '\\"')
        .replace(":", "\\:")
    )


def wifi_share_payload(ssid: str, security: str, password: str) -> str:
    sec = (security or "").upper()
    if not sec or sec in ("--", "NONE", "OPEN"):
        t = "nopass"
        password = ""
    elif "WEP" in sec:
        t = "WEP"
    else:
        t = "WPA"
    return f"WIFI:T:{t};S:{_wifi_qr_escape(ssid)};P:{_wifi_qr_escape(password)};;"


def wifi_qr_png(payload: str) -> Path | None:
    from shutil import which

    if not which("qrencode"):
        return None
    out = runtime_dir() / "look-wifi-qr.png"
    rc, _ = run(["qrencode", "-o", str(out), "-s", "5", "-m", "1", payload])
    return out if rc == 0 and out.is_file() else None


def clipboard_set(text: str) -> None:
    clip = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
    clip.set_text(text, -1)
    clip.store()


def night_light_state_path() -> Path:
    return runtime_dir() / "look-night-light.on"


def night_light_enabled() -> bool:
    return night_light_state_path().is_file()


def set_night_light(on: bool) -> tuple[bool, str]:
    from shutil import which

    if not which("redshift"):
        return False, "Install redshift for night light"
    if on:
        rc, out = run(["redshift", "-P", "-O", "4500"])
        if rc != 0:
            return False, out.strip() or "Night light failed"
        night_light_state_path().write_text("1\n", encoding="utf-8")
        return True, "Night light on"
    run(["redshift", "-x"])
    try:
        night_light_state_path().unlink()
    except OSError:
        pass
    return True, "Night light off"


def shutil_which(name: str) -> str | None:
    from shutil import which

    return which(name)


# --- Bluetooth --------------------------------------------------------------

def bt_powered() -> bool:
    rc, out = run(["bluetoothctl", "show"])
    return rc == 0 and re.search(r"Powered:\s*yes", out) is not None


def set_bt_powered(on: bool) -> None:
    run(["bluetoothctl", "power", "on" if on else "off"])


def bt_scan(on: bool) -> None:
    run(["bluetoothctl", "scan", "on" if on else "off"], timeout=3.0)


def bt_devices() -> list[dict]:
    rc, out = run(["bluetoothctl", "devices"])
    if rc != 0:
        return []
    connected: set[str] = set()
    _, cout = run(["bluetoothctl", "devices", "Connected"])
    for line in cout.splitlines():
        m = re.match(r"Device\s+([0-9A-Fa-f:]{17})\s+", line)
        if m:
            connected.add(m.group(1).upper())

    rows: list[dict] = []
    for line in out.splitlines():
        m = re.match(r"Device\s+([0-9A-Fa-f:]{17})\s+(.*)$", line)
        if not m:
            continue
        mac, name = m.group(1).upper(), m.group(2).strip() or m.group(1)
        rows.append({"mac": mac, "name": name, "connected": mac in connected})
    rows.sort(key=lambda r: (not r["connected"], r["name"].lower()))
    return rows


def bt_connect(mac: str) -> tuple[bool, str]:
    rc, out = run(["bluetoothctl", "connect", mac], timeout=30.0)
    return rc == 0, out.strip() or ("Connected" if rc == 0 else "Connect failed")


def bt_disconnect(mac: str) -> None:
    run(["bluetoothctl", "disconnect", mac], timeout=15.0)


# --- Brightness / volume / performance --------------------------------------

def brightness_pct() -> int:
    try:
        cur = int(subprocess.check_output(["brightnessctl", "g"], text=True).strip())
        mx = int(subprocess.check_output(["brightnessctl", "m"], text=True).strip()) or 1
        return max(1, min(100, cur * 100 // mx))
    except Exception:
        return 50


def set_brightness_pct(pct: int) -> None:
    pct = max(1, min(100, int(pct)))
    run(["brightnessctl", "set", f"{pct}%"])


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
        pct = max(0, sum(pcts) // len(pcts)) if pcts else 0
        return pct, muted
    except Exception:
        return 0, False


def set_volume_pct(pct: int) -> None:
    pct = max(0, min(150, int(pct)))
    run(["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{pct}%"])


def set_volume_mute(muted: bool) -> None:
    run(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "1" if muted else "0"])


def source_muted() -> bool:
    rc, out = run(["pactl", "get-source-mute", "@DEFAULT_SOURCE@"])
    return rc == 0 and "yes" in out.lower()


def set_source_mute(muted: bool) -> None:
    run(["pactl", "set-source-mute", "@DEFAULT_SOURCE@", "1" if muted else "0"])


def perf_profile() -> str:
    rc, out = run(["powerprofilesctl", "get"])
    if rc != 0:
        return "balanced"
    return out.strip() or "balanced"


def set_perf_profile(name: str) -> None:
    run(["powerprofilesctl", "set", name])


# --- UI ---------------------------------------------------------------------

class LookApplet(Gtk.Window):
    def __init__(self, kind: str) -> None:
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.kind = kind
        self.set_title(f"look-applet-{kind}")
        self.set_decorated(False)
        self.set_keep_above(True)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_resizable(False)
        if kind in ("network", "bluetooth"):
            height = HEIGHT_TALL
        else:
            height = HEIGHT_COMPACT
        self.set_default_size(WIDTH, height)
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        self.stick()

        css = Gtk.CssProvider()
        css.load_from_data(
            b"""
            window.look-applet {
              background-color: @theme_bg_color;
              color: @theme_fg_color;
              border: 1px solid mix(@theme_fg_color, @theme_bg_color, 0.7);
              border-radius: 0;
            }
            window.look-applet label, window.look-applet button {
              color: @theme_fg_color;
            }
            window.look-applet list row:selected {
              background-color: @theme_selected_bg_color;
              color: @theme_selected_fg_color;
            }
            window.look-applet .status {
              opacity: 0.75;
              font-size: 11px;
            }
            window.look-applet scale {
              margin: 4px 0;
            }
            """
        )
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css,
            Gtk.STYLE_PROVIDER_PRIORITY_USER,
        )
        self.get_style_context().add_class("look-applet")

        self._status = Gtk.Label(xalign=0.0)
        self._status.get_style_context().add_class("status")
        self._status.set_line_wrap(True)
        self._bright_timer = None
        self._vol_timer = None

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        root.set_margin_top(10)
        root.set_margin_bottom(10)
        root.set_margin_start(12)
        root.set_margin_end(12)
        self.add(root)

        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        title = Gtk.Label(xalign=0.0)
        title.set_markup(
            f'<span face="{NERD}" weight="bold">{TITLES.get(kind, kind)}</span>'
        )
        header.pack_start(title, True, True, 0)
        close_btn = Gtk.Button(label="✕")
        close_btn.set_relief(Gtk.ReliefStyle.NONE)
        close_btn.connect("clicked", lambda *_: self.close())
        header.pack_end(close_btn, False, False, 0)
        root.pack_start(header, False, False, 0)

        builders = {
            "network": self._build_network,
            "bluetooth": self._build_bluetooth,
            "brightness": self._build_brightness,
            "volume": self._build_volume,
            "performance": self._build_performance,
        }
        builders[kind](root)

        root.pack_start(self._status, False, False, 0)

        if kind in ("network", "bluetooth", "volume"):
            adv = Gtk.Button(label="Advanced…")
            adv.connect("clicked", self._on_advanced)
            root.pack_end(adv, False, False, 0)

        self.connect("key-press-event", self._on_key)
        self.connect("map-event", lambda *_: self._place() or False)
        self.connect("destroy", lambda *_: Gtk.main_quit())

    def _set_status(self, text: str) -> None:
        self._status.set_text(text)

    def _on_key(self, _w, event) -> bool:
        if event.keyval == Gdk.KEY_Escape:
            self.close()
            return True
        return False

    def _place(self) -> None:
        mx, my, mw, _mh = primary_geometry()
        x = mx + mw - WIDTH - MARGIN
        y = my + BAR_H + MARGIN
        self.move(max(mx, x), max(my, y))

    def _on_advanced(self, *_a) -> None:
        cmd = {
            "network": ["nm-connection-editor"],
            "bluetooth": ["blueman-manager"],
            "volume": ["pavucontrol"],
        }.get(self.kind)
        if cmd:
            subprocess.Popen(cmd, start_new_session=True)
        self.close()

    # -- brightness --

    def _build_brightness(self, root: Gtk.Box) -> None:
        pct = brightness_pct()
        self._bright_val = Gtk.Label(label=f"{pct}%", xalign=1.0)
        head = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        head.pack_start(Gtk.Label(label="Display", xalign=0.0), True, True, 0)
        head.pack_end(self._bright_val, False, False, 0)
        root.pack_start(head, False, False, 0)

        self._bright_scale = Gtk.Scale.new_with_range(
            Gtk.Orientation.HORIZONTAL, 1, 100, 1
        )
        self._bright_scale.set_value(pct)
        self._bright_scale.set_draw_value(False)
        self._bright_scale.set_hexpand(True)
        self._bright_scale.connect("value-changed", self._on_bright_changed)
        root.pack_start(self._bright_scale, False, False, 0)

        night = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        night.pack_start(Gtk.Label(label="Night light", xalign=0.0), True, True, 0)
        self._night_sw = Gtk.Switch()
        has_redshift = bool(shutil_which("redshift"))
        self._night_sw.set_sensitive(has_redshift)
        self._night_sw.set_active(has_redshift and night_light_enabled())
        self._night_sw.connect("state-set", self._on_night_toggle)
        night.pack_end(self._night_sw, False, False, 0)
        root.pack_start(night, False, False, 0)
        if has_redshift:
            self._set_status("Drag to adjust")
        else:
            self._set_status("Install redshift for night light")

    def _on_bright_changed(self, scale: Gtk.Scale) -> None:
        pct = int(scale.get_value())
        self._bright_val.set_text(f"{pct}%")
        if self._bright_timer is not None:
            GLib.source_remove(self._bright_timer)
        self._bright_timer = GLib.timeout_add(40, self._apply_brightness, pct)

    def _apply_brightness(self, pct: int) -> bool:
        self._bright_timer = None
        set_brightness_pct(pct)
        return False

    def _on_night_toggle(self, _sw: Gtk.Switch, state: bool) -> bool:
        ok, msg = set_night_light(state)
        self._set_status(msg)
        if not ok:
            return True  # revert switch
        return False

    # -- volume --

    def _build_volume(self, root: Gtk.Box) -> None:
        pct, muted = volume_state()
        self._vol_val = Gtk.Label(label=f"{pct}%", xalign=1.0)
        head = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        head.pack_start(Gtk.Label(label="Output", xalign=0.0), True, True, 0)
        head.pack_end(self._vol_val, False, False, 0)
        root.pack_start(head, False, False, 0)

        self._vol_scale = Gtk.Scale.new_with_range(
            Gtk.Orientation.HORIZONTAL, 0, 150, 1
        )
        self._vol_scale.set_value(min(150, pct))
        self._vol_scale.set_draw_value(False)
        self._vol_scale.add_mark(100, Gtk.PositionType.BOTTOM, None)
        self._vol_scale.connect("value-changed", self._on_vol_changed)
        root.pack_start(self._vol_scale, False, False, 0)

        mute_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        mute_row.pack_start(Gtk.Label(label="Mute output", xalign=0.0), True, True, 0)
        self._vol_mute = Gtk.Switch()
        self._vol_mute.set_active(muted)
        self._vol_mute.connect("state-set", self._on_vol_mute)
        mute_row.pack_end(self._vol_mute, False, False, 0)
        root.pack_start(mute_row, False, False, 0)

        mic_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        mic_row.pack_start(Gtk.Label(label="Mute mic", xalign=0.0), True, True, 0)
        self._mic_mute = Gtk.Switch()
        self._mic_mute.set_active(source_muted())
        self._mic_mute.connect("state-set", self._on_mic_mute)
        mic_row.pack_end(self._mic_mute, False, False, 0)
        root.pack_start(mic_row, False, False, 0)
        self._set_status("0–150% (mark at 100%)")

    def _on_vol_changed(self, scale: Gtk.Scale) -> None:
        pct = int(scale.get_value())
        self._vol_val.set_text(f"{pct}%")
        if self._vol_timer is not None:
            GLib.source_remove(self._vol_timer)
        self._vol_timer = GLib.timeout_add(40, self._apply_volume, pct)

    def _apply_volume(self, pct: int) -> bool:
        self._vol_timer = None
        set_volume_pct(pct)
        if pct > 0 and self._vol_mute.get_active():
            self._vol_mute.set_active(False)
            set_volume_mute(False)
        return False

    def _on_vol_mute(self, _sw: Gtk.Switch, state: bool) -> bool:
        set_volume_mute(state)
        return False

    def _on_mic_mute(self, _sw: Gtk.Switch, state: bool) -> bool:
        set_source_mute(state)
        return False

    # -- performance --

    def _build_performance(self, root: Gtk.Box) -> None:
        current = perf_profile()
        self._perf_group: list[Gtk.RadioButton] = []
        first = None
        for pid, label in PERF_PROFILES:
            btn = Gtk.RadioButton.new_with_label_from_widget(first, label)
            if first is None:
                first = btn
            btn.set_active(pid == current)
            btn._profile_id = pid  # type: ignore[attr-defined]
            btn.connect("toggled", self._on_perf_toggled)
            root.pack_start(btn, False, False, 0)
            self._perf_group.append(btn)
        self._set_status(f"Current: {current}")

    def _on_perf_toggled(self, btn: Gtk.RadioButton) -> None:
        if not btn.get_active():
            return
        pid = getattr(btn, "_profile_id", "")
        if not pid:
            return
        set_perf_profile(pid)
        self._set_status(f"Current: {pid}")

    # -- network --

    def _build_network(self, root: Gtk.Box) -> None:
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        row.pack_start(Gtk.Label(label="Wi‑Fi", xalign=0.0), True, True, 0)
        self._wifi_sw = Gtk.Switch()
        self._wifi_sw.set_active(wifi_radio())
        self._wifi_sw.connect("state-set", self._on_wifi_toggle)
        row.pack_end(self._wifi_sw, False, False, 0)
        root.pack_start(row, False, False, 0)

        tools = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        refresh = Gtk.Button(label="Refresh")
        refresh.connect("clicked", lambda *_: self._reload_wifi())
        disc = Gtk.Button(label="Disconnect")
        disc.connect("clicked", self._on_wifi_disconnect)
        tools.pack_start(refresh, True, True, 0)
        tools.pack_start(disc, True, True, 0)
        root.pack_start(tools, False, False, 0)

        # Share connected network (password + QR) — expander acts as dropdown
        self._share_exp = Gtk.Expander(label="Share current network")
        share_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        share_box.set_margin_top(6)
        self._share_ssid = Gtk.Label(xalign=0.0)
        self._share_ssid.set_line_wrap(True)
        share_box.pack_start(self._share_ssid, False, False, 0)

        pw_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self._share_pw = Gtk.Entry()
        self._share_pw.set_visibility(False)
        self._share_pw.set_editable(False)
        self._share_pw.set_hexpand(True)
        pw_row.pack_start(self._share_pw, True, True, 0)
        self._pw_reveal = Gtk.Button(label="Show")
        self._pw_reveal.connect("clicked", self._on_toggle_pw)
        pw_row.pack_start(self._pw_reveal, False, False, 0)
        share_box.pack_start(pw_row, False, False, 0)

        btns = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        copy_pw = Gtk.Button(label="Copy password")
        copy_pw.connect("clicked", self._on_copy_password)
        copy_qr = Gtk.Button(label="Copy Wi‑Fi string")
        copy_qr.connect("clicked", self._on_copy_wifi_string)
        btns.pack_start(copy_pw, True, True, 0)
        btns.pack_start(copy_qr, True, True, 0)
        share_box.pack_start(btns, False, False, 0)

        self._qr_image = Gtk.Image()
        self._qr_image.set_halign(Gtk.Align.CENTER)
        share_box.pack_start(self._qr_image, False, False, 0)
        self._share_exp.add(share_box)
        root.pack_start(self._share_exp, False, False, 0)
        self._share_secret = ""
        self._share_payload = ""

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)
        self._wifi_list = Gtk.ListBox()
        self._wifi_list.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self._wifi_list.set_activate_on_single_click(True)
        self._wifi_list.connect("row-activated", self._on_wifi_activate)
        scroll.add(self._wifi_list)
        root.pack_start(scroll, True, True, 0)
        self._reload_wifi()

    def _on_wifi_toggle(self, _switch: Gtk.Switch, state: bool) -> bool:
        set_wifi_radio(state)
        GLib.timeout_add(400, self._reload_wifi)
        return False

    def _reload_wifi(self, *_a) -> bool:
        for child in list(self._wifi_list.get_children()):
            self._wifi_list.remove(child)
        if not wifi_radio():
            self._wifi_sw.set_active(False)
            self._share_exp.set_visible(False)
            self._set_status("Wi‑Fi is off")
            return False
        self._wifi_sw.set_active(True)
        nets = wifi_networks()
        self._update_share_panel(nets)
        if not nets:
            self._set_status("No networks found")
            return False
        for n in nets:
            lock = " " if n["security"] and n["security"] != "--" else ""
            mark = "● " if n["active"] else "○ "
            label = Gtk.Label(
                label=f"{mark}{n['ssid']}{lock}   {n['signal']}%",
                xalign=0.0,
            )
            label.set_margin_top(6)
            label.set_margin_bottom(6)
            label.set_margin_start(4)
            label.set_margin_end(4)
            row = Gtk.ListBoxRow()
            row.add(label)
            row._ssid = n["ssid"]  # type: ignore[attr-defined]
            row._security = n["security"]  # type: ignore[attr-defined]
            row._active = n["active"]  # type: ignore[attr-defined]
            self._wifi_list.add(row)
        self._wifi_list.show_all()
        self._set_status(f"{len(nets)} networks")
        return False

    def _update_share_panel(self, nets: list[dict] | None = None) -> None:
        conn = wifi_active_connection()
        listed = wifi_active_from(nets) if nets is not None else None
        if not conn and not listed:
            self._share_exp.set_expanded(False)
            self._share_exp.set_visible(False)
            self._share_secret = ""
            self._share_payload = ""
            return
        ssid = (conn or {}).get("ssid") or (listed or {}).get("ssid") or ""
        password = (conn or {}).get("password") or ""
        security = (listed or {}).get("security") or ""
        key_mgmt = (conn or {}).get("key_mgmt") or ""
        if not security and key_mgmt:
            security = "WPA" if "psk" in key_mgmt or "sae" in key_mgmt else key_mgmt
        self._share_secret = password
        self._share_payload = wifi_share_payload(ssid.rstrip("\n"), security, password)
        self._share_ssid.set_text(f"SSID: {ssid}")
        self._share_pw.set_text(password or "(no password / open)")
        self._share_pw.set_visibility(False)
        self._pw_reveal.set_label("Show")
        png = wifi_qr_png(self._share_payload)
        if png:
            self._qr_image.set_from_file(str(png))
            self._qr_image.set_visible(True)
        else:
            self._qr_image.clear()
            self._qr_image.set_visible(False)
        self._share_exp.set_visible(True)
        self._share_exp.show_all()

    def _on_toggle_pw(self, *_a) -> None:
        vis = not self._share_pw.get_visibility()
        self._share_pw.set_visibility(vis)
        self._pw_reveal.set_label("Hide" if vis else "Show")

    def _on_copy_password(self, *_a) -> None:
        if not self._share_secret:
            self._set_status("No password to copy")
            return
        clipboard_set(self._share_secret)
        self._set_status("Password copied")

    def _on_copy_wifi_string(self, *_a) -> None:
        if not self._share_payload:
            self._set_status("Nothing to copy")
            return
        clipboard_set(self._share_payload)
        self._set_status("Wi‑Fi string copied")

    def _on_wifi_disconnect(self, *_a) -> None:
        wifi_disconnect()
        self._set_status("Disconnected")
        GLib.timeout_add(500, self._reload_wifi)

    def _on_wifi_activate(self, _lb, row: Gtk.ListBoxRow) -> None:
        ssid = getattr(row, "_ssid", "")
        security = getattr(row, "_security", "")
        active = getattr(row, "_active", False)
        if not ssid:
            return
        if active:
            self._set_status(f"Already on {ssid}")
            return
        password = None
        if security and security != "--" and not wifi_known(ssid):
            password = self._ask_password(ssid)
            if password is None:
                return
        self._set_status(f"Connecting to {ssid}…")

        def work() -> None:
            ok, msg = wifi_connect(ssid, password)
            GLib.idle_add(self._after_wifi_connect, ok, msg)

        threading.Thread(target=work, daemon=True).start()

    def _after_wifi_connect(self, ok: bool, msg: str) -> bool:
        self._set_status(msg.splitlines()[-1][:80] if msg else ("OK" if ok else "Failed"))
        self._reload_wifi()
        return False

    def _ask_password(self, ssid: str) -> str | None:
        dlg = Gtk.Dialog(
            title="Wi‑Fi password",
            transient_for=self,
            modal=True,
            destroy_with_parent=True,
        )
        dlg.add_buttons(
            Gtk.STOCK_CANCEL,
            Gtk.ResponseType.CANCEL,
            Gtk.STOCK_OK,
            Gtk.ResponseType.OK,
        )
        box = dlg.get_content_area()
        box.set_spacing(8)
        box.set_margin_top(12)
        box.set_margin_bottom(12)
        box.set_margin_start(12)
        box.set_margin_end(12)
        box.add(Gtk.Label(label=f"Password for {ssid}", xalign=0.0))
        entry = Gtk.Entry()
        entry.set_visibility(False)
        entry.set_input_purpose(Gtk.InputPurpose.PASSWORD)
        entry.set_activates_default(True)
        box.add(entry)
        dlg.set_default_response(Gtk.ResponseType.OK)
        dlg.show_all()
        resp = dlg.run()
        text = entry.get_text()
        dlg.destroy()
        if resp != Gtk.ResponseType.OK:
            return None
        return text

    # -- bluetooth --

    def _build_bluetooth(self, root: Gtk.Box) -> None:
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        row.pack_start(Gtk.Label(label="Bluetooth", xalign=0.0), True, True, 0)
        self._bt_sw = Gtk.Switch()
        self._bt_sw.set_active(bt_powered())
        self._bt_sw.connect("state-set", self._on_bt_toggle)
        row.pack_end(self._bt_sw, False, False, 0)
        root.pack_start(row, False, False, 0)

        tools = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self._scan_btn = Gtk.Button(label="Scan")
        self._scan_btn.connect("clicked", self._on_bt_scan)
        refresh = Gtk.Button(label="Refresh")
        refresh.connect("clicked", lambda *_: self._reload_bt())
        tools.pack_start(self._scan_btn, True, True, 0)
        tools.pack_start(refresh, True, True, 0)
        root.pack_start(tools, False, False, 0)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)
        self._bt_list = Gtk.ListBox()
        self._bt_list.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self._bt_list.set_activate_on_single_click(True)
        self._bt_list.connect("row-activated", self._on_bt_activate)
        scroll.add(self._bt_list)
        root.pack_start(scroll, True, True, 0)

        self._scanning = False
        self._reload_bt()

    def _on_bt_toggle(self, _switch: Gtk.Switch, state: bool) -> bool:
        set_bt_powered(state)
        GLib.timeout_add(400, self._reload_bt)
        return False

    def _on_bt_scan(self, *_a) -> None:
        if not bt_powered():
            self._set_status("Turn Bluetooth on first")
            return
        self._scanning = not self._scanning
        bt_scan(self._scanning)
        self._scan_btn.set_label("Stop scan" if self._scanning else "Scan")
        self._set_status("Scanning…" if self._scanning else "Scan stopped")
        if self._scanning:
            GLib.timeout_add(2000, self._reload_bt_while_scan)

    def _reload_bt_while_scan(self) -> bool:
        self._reload_bt()
        return self._scanning

    def _reload_bt(self, *_a) -> bool:
        for child in list(self._bt_list.get_children()):
            self._bt_list.remove(child)
        if not bt_powered():
            self._bt_sw.set_active(False)
            self._set_status("Bluetooth is off")
            return False
        self._bt_sw.set_active(True)
        devices = bt_devices()
        if not devices:
            self._set_status("No devices — try Scan")
            return False
        for d in devices:
            mark = "● " if d["connected"] else "○ "
            label = Gtk.Label(label=f"{mark}{d['name']}", xalign=0.0)
            label.set_margin_top(6)
            label.set_margin_bottom(6)
            label.set_margin_start(4)
            label.set_margin_end(4)
            row = Gtk.ListBoxRow()
            row.add(label)
            row._mac = d["mac"]  # type: ignore[attr-defined]
            row._connected = d["connected"]  # type: ignore[attr-defined]
            row._name = d["name"]  # type: ignore[attr-defined]
            self._bt_list.add(row)
        self._bt_list.show_all()
        self._set_status(f"{len(devices)} devices")
        return False

    def _on_bt_activate(self, _lb, row: Gtk.ListBoxRow) -> None:
        mac = getattr(row, "_mac", "")
        connected = getattr(row, "_connected", False)
        name = getattr(row, "_name", mac)
        if not mac:
            return
        if connected:
            self._set_status(f"Disconnecting {name}…")
            bt_disconnect(mac)
            GLib.timeout_add(500, self._reload_bt)
            return
        self._set_status(f"Connecting to {name}…")

        def work() -> None:
            ok, msg = bt_connect(mac)
            GLib.idle_add(self._after_bt_connect, ok, msg)

        threading.Thread(target=work, daemon=True).start()

    def _after_bt_connect(self, ok: bool, msg: str) -> bool:
        self._set_status(msg.splitlines()[-1][:80] if msg else ("OK" if ok else "Failed"))
        self._reload_bt()
        return False


def try_toggle_existing(kind: str) -> bool:
    """Toggle a live applet. Stale sock files must not swallow the click."""
    path = sock_path(kind)
    if not path.exists():
        return False
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as s:
            # connect() fails with ECONNREFUSED when nothing is bound — sendto alone
            # would "succeed" on a leftover sock and the bar click would no-op.
            s.connect(str(path))
            s.send(b"toggle")
        return True
    except OSError:
        try:
            path.unlink()
        except OSError:
            pass
        return False


def close_others(kind: str) -> None:
    for other in KINDS:
        if other != kind:
            try_toggle_existing(other)


def run_applet(kind: str) -> None:
    path = sock_path(kind)
    if path.exists():
        try:
            path.unlink()
        except OSError:
            pass

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    sock.bind(str(path))
    sock.setblocking(False)

    win = LookApplet(kind)

    def on_socket(_fd, _cond):
        try:
            data, _ = sock.recvfrom(16)
            if data:
                win.close()
        except BlockingIOError:
            pass
        return True

    def cleanup(*_a):
        try:
            sock.close()
        except OSError:
            pass
        try:
            path.unlink()
        except OSError:
            pass
        if kind == "bluetooth":
            bt_scan(False)

    win.connect("destroy", cleanup)
    GLib.io_add_watch(sock.fileno(), GLib.IO_IN, on_socket)
    win.show_all()
    win._place()
    Gtk.main()


def main() -> None:
    kind = sys.argv[1] if len(sys.argv) > 1 else ""
    if kind not in KINDS:
        print(
            "usage: look-applet.py "
            "network|bluetooth|brightness|volume|performance",
            file=sys.stderr,
        )
        sys.exit(1)
    load_look_env()
    if try_toggle_existing(kind):
        return
    close_others(kind)
    run_applet(kind)


if __name__ == "__main__":
    main()
