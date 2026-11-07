Theme packs live here (not stowed). Bundled: `tokyo-night/`.

## One config, one script

Edit:
  ~/.config/i3/look.conf

Apply everything (desktop wallpaper, GTK/icons/cursor, Vicinae icons, lock cache, LightDM login bg):
  ~/.config/i3/apply-look.sh

Canonical wallpaper symlink (created by apply-look):
  ~/.config/i3/wallpaper → your chosen image

First login wallpaper sync to LightDM may ask for sudo (home is not readable by the greeter user, so `/usr/share/backgrounds/tokyo-night/current` is refreshed from that symlink).
