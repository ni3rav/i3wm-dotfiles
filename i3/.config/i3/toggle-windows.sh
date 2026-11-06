#!/usr/bin/env bash
# Hide / restore windows on X11 under i3 (wmctrl + xdotool).
#
# i3 does not implement EWMH minimize (windowminimize is a no-op here).
# We unmap/map instead, which reliably hides and restores windows.
#
# Usage:
#   toggle-windows.sh           Hide all eligible windows / restore that set
#   toggle-windows.sh --focused Hide focused window / restore it if still hidden

set -euo pipefail

STATE_ALL="${XDG_RUNTIME_DIR:-/tmp}/i3-hidden-windows"
STATE_FOCUSED="${XDG_RUNTIME_DIR:-/tmp}/i3-hidden-focused"

is_infrastructure() {
    local id="$1"
    local wm_class wm_type wm_name

    wm_class=$(xprop -id "$id" WM_CLASS 2>/dev/null || true)
    wm_name=$(xprop -id "$id" WM_NAME 2>/dev/null || true)
    wm_type=$(xprop -id "$id" _NET_WM_WINDOW_TYPE 2>/dev/null || true)

    case "$wm_type" in
        *DOCK*|*DESKTOP*|*TOOLBAR*|*NOTIFICATION*)
            return 0
            ;;
    esac

    case "$wm_class" in
        *i3bar*|*i3-frame*|*Polybar*|*polybar*|*dunst*|*Dunst*|*xfce4-panel*|*Tint2*|*Plank*|*trayer*)
            return 0
            ;;
    esac

    case "$wm_name" in
        *i3bar*)
            return 0
            ;;
    esac

    return 1
}

window_exists() {
    xprop -id "$1" >/dev/null 2>&1
}

# Hidden via our unmap (Withdrawn). Already-unmapped windows are absent from
# wmctrl -l, so minimize-all naturally skips pre-hidden windows.
is_withdrawn() {
    xprop -id "$1" WM_STATE 2>/dev/null | grep -q Withdrawn
}

restore_ids_from() {
    local state_file="$1"
    local id
    [[ -f "$state_file" ]] || return 0
    while read -r id; do
        [[ -n "$id" ]] || continue
        if window_exists "$id"; then
            xdotool windowmap "$id" 2>/dev/null || true
            xdotool windowactivate "$id" 2>/dev/null || true
        fi
    done < "$state_file"
    rm -f "$state_file"
}

hide_all() {
    local id tmp
    tmp=$(mktemp)

    # wmctrl -l lists currently mapped clients only → already-hidden windows
    # are not re-hidden and will not be restored later.
    while read -r id _; do
        [[ -n "$id" ]] || continue
        id=$(printf '%d' "$id")
        if is_infrastructure "$id"; then
            continue
        fi
        if xdotool windowunmap "$id" 2>/dev/null; then
            printf '%s\n' "$id" >> "$tmp"
        fi
    done < <(wmctrl -l | awk '{print $1}')

    if [[ -s "$tmp" ]]; then
        mv "$tmp" "$STATE_ALL"
    else
        rm -f "$tmp"
    fi
}

toggle_all() {
    if [[ -f "$STATE_ALL" ]]; then
        restore_ids_from "$STATE_ALL"
    else
        hide_all
    fi
}

toggle_focused() {
    local focused

    if [[ -f "$STATE_FOCUSED" ]]; then
        focused=$(head -n1 "$STATE_FOCUSED" || true)
        if [[ -n "$focused" ]] && window_exists "$focused" && is_withdrawn "$focused"; then
            xdotool windowmap "$focused" 2>/dev/null || true
            xdotool windowactivate "$focused" 2>/dev/null || true
            rm -f "$STATE_FOCUSED"
            return 0
        fi
        rm -f "$STATE_FOCUSED"
    fi

    focused=$(xdotool getactivewindow 2>/dev/null || true)
    [[ -n "$focused" ]] || return 0

    if is_infrastructure "$focused"; then
        return 0
    fi

    if xdotool windowunmap "$focused" 2>/dev/null; then
        printf '%s\n' "$focused" > "$STATE_FOCUSED"
    fi
}

case "${1:-}" in
    --focused)
        toggle_focused
        ;;
    "")
        toggle_all
        ;;
    *)
        echo "Usage: $0 [--focused]" >&2
        exit 2
        ;;
esac
