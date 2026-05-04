#!/usr/bin/env bash
# ============================================================
# Personal Hyprland setup script for a fresh Arch Linux install
#
# Prerequisites:
#   - Arch base system installed via archinstall (Minimal profile)
#   - btrfs, no encryption, systemd-boot, NetworkManager
#   - You are logged in as your primary (sudo-capable) user
#   - Network is working (ping archlinux.org)
#
# Run as your normal user (NOT root):
#   chmod +x setup.sh
#   ./setup.sh
# ============================================================

set -euo pipefail

# ---------- helpers ----------
RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; BLU='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${BLU}==>${NC} $*"; }
ok()   { echo -e "${GRN}[ok]${NC} $*"; }
warn() { echo -e "${YLW}[warn]${NC} $*"; }
err()  { echo -e "${RED}[err]${NC} $*" >&2; }

# ---------- guards ----------
if [[ $EUID -eq 0 ]]; then
    err "Don't run this as root. Run as your normal user; it will sudo when needed."
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    err "sudo is not installed. Install it and add your user to the wheel group first."
    exit 1
fi

if ! ping -c 1 -W 3 archlinux.org >/dev/null 2>&1; then
    err "No network. Bring up NetworkManager (sudo systemctl enable --now NetworkManager) first."
    exit 1
fi

PRIMARY_USER="$USER"
log "Setting up for primary user: $PRIMARY_USER"

# Cache sudo creds upfront
sudo -v
# Keep-alive: refresh sudo timestamp until script ends
( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null || true' EXIT

# ============================================================
# Phase 2 — Enable multilib + install yay
# ============================================================
log "Phase 2: enabling multilib repository"

if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
    ok "multilib enabled in /etc/pacman.conf"
else
    ok "multilib already enabled"
fi

log "Syncing package databases"
sudo pacman -Syu --noconfirm

log "Installing yay (AUR helper)"
if ! command -v yay >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm git base-devel
    tmpdir="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
    pushd "$tmpdir/yay-bin" >/dev/null
    makepkg -si --noconfirm
    popd >/dev/null
    rm -rf "$tmpdir"
    ok "yay installed"
else
    ok "yay already installed"
fi

# ============================================================
# Phase 3 — Hyprland stack
# ============================================================
log "Phase 3: installing Hyprland stack"

sudo pacman -S --needed --noconfirm \
    hyprland xdg-desktop-portal-hyprland \
    waybar wofi mako \
    hyprlock hypridle hyprpaper \
    alacritty \
    polkit-gnome \
    grim slurp wl-clipboard \
    brightnessctl playerctl \
    network-manager-applet blueman bluez bluez-utils \
    pipewire wireplumber pipewire-pulse pipewire-alsa \
    pavucontrol \
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji \
    thunar thunar-volman gvfs \
    qt5-wayland qt6-wayland

sudo systemctl enable --now bluetooth
ok "Hyprland stack installed"

# ============================================================
# Phase 4 — SDDM display manager
# ============================================================
log "Phase 4: installing SDDM"

sudo pacman -S --needed --noconfirm sddm
sudo systemctl enable sddm

if [[ ! -f /usr/share/wayland-sessions/hyprland.desktop ]]; then
    warn "Hyprland session file missing — SDDM might not show Hyprland as an option"
else
    ok "SDDM installed, Hyprland session entry present"
fi

# ============================================================
# Phase 5 — User-facing apps
# ============================================================
log "Phase 5: installing apps (Firefox, Steam, Spotify)"

sudo pacman -S --needed --noconfirm firefox

# Steam needs a graphics driver pick — non-interactive default works for most
# but if you have NVIDIA proprietary, you may want to install lib32-nvidia-utils manually after
sudo pacman -S --needed --noconfirm steam || warn "Steam install needed graphics driver selection — re-run 'sudo pacman -S steam' interactively if it failed"

# Spotify from AUR
yay -S --needed --noconfirm spotify || warn "Spotify install failed — you can retry with 'yay -S spotify'"

ok "Apps installed"

# ============================================================
# Phase 6 — System-wide configs in /etc/xdg
# ============================================================
log "Phase 6: writing system-wide configs to /etc/xdg"

sudo mkdir -p /etc/xdg/hypr /etc/xdg/waybar /etc/xdg/mako /etc/xdg/alacritty

# ----- Hyprland main config -----
sudo tee /etc/xdg/hypr/hyprland.conf > /dev/null << 'HYPR_EOF'
# ============================================================
# System-wide Hyprland config
# Per-user overrides: append lines below the source= in ~/.config/hypr/hyprland.conf
# ============================================================

monitor=,preferred,auto,1

# Autostart
exec-once = waybar
exec-once = mako
exec-once = hyprpaper
exec-once = nm-applet --indicator
exec-once = blueman-applet
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = hypridle

# Environment
env = XCURSOR_SIZE,24
env = QT_QPA_PLATFORMTHEME,qt5ct

input {
    kb_layout = us
    follow_mouse = 1
    sensitivity = 0
    touchpad {
        natural_scroll = yes
    }
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(88c0d0ee) rgba(81a1c1ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

decoration {
    rounding = 8
    blur {
        enabled = true
        size = 6
        passes = 2
    }
    drop_shadow = yes
    shadow_range = 4
    shadow_render_power = 3
}

animations {
    enabled = yes
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 5, myBezier
    animation = windowsOut, 1, 5, default, popin 80%
    animation = border, 1, 8, default
    animation = fade, 1, 5, default
    animation = workspaces, 1, 4, default
}

dwindle {
    pseudotile = yes
    preserve_split = yes
}

# Keybinds
$mod = SUPER

bind = $mod, Return, exec, alacritty
bind = $mod, Q, killactive,
bind = $mod SHIFT, E, exit,
bind = $mod, E, exec, thunar
bind = $mod, B, exec, firefox
bind = $mod, V, togglefloating,
bind = $mod, D, exec, wofi --show drun
bind = $mod, L, exec, hyprlock
bind = $mod, F, fullscreen,

# Screenshots
bind = , Print, exec, grim -g "$(slurp)" - | wl-copy
bind = SHIFT, Print, exec, grim - | wl-copy

# Move focus
bind = $mod, left, movefocus, l
bind = $mod, right, movefocus, r
bind = $mod, up, movefocus, u
bind = $mod, down, movefocus, d

# Workspaces 1-5
bind = $mod, 1, workspace, 1
bind = $mod, 2, workspace, 2
bind = $mod, 3, workspace, 3
bind = $mod, 4, workspace, 4
bind = $mod, 5, workspace, 5
bind = $mod SHIFT, 1, movetoworkspace, 1
bind = $mod SHIFT, 2, movetoworkspace, 2
bind = $mod SHIFT, 3, movetoworkspace, 3
bind = $mod SHIFT, 4, movetoworkspace, 4
bind = $mod SHIFT, 5, movetoworkspace, 5

# Mouse drag windows
bindm = $mod, mouse:272, movewindow
bindm = $mod, mouse:273, resizewindow

# Media + brightness keys
bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl  = , XF86AudioMute,        exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindl  = , XF86AudioPlay,        exec, playerctl play-pause
bindl  = , XF86AudioNext,        exec, playerctl next
bindl  = , XF86AudioPrev,        exec, playerctl previous
bindel = , XF86MonBrightnessUp,   exec, brightnessctl set 5%+
bindel = , XF86MonBrightnessDown, exec, brightnessctl set 5%-
HYPR_EOF

# ----- hyprpaper -----
sudo tee /etc/xdg/hypr/hyprpaper.conf > /dev/null << 'HYPRPAPER_EOF'
# Uncomment and point to an image to set wallpaper
# preload = ~/Pictures/wallpaper.jpg
# wallpaper = ,~/Pictures/wallpaper.jpg
HYPRPAPER_EOF

# ----- hyprlock -----
sudo tee /etc/xdg/hypr/hyprlock.conf > /dev/null << 'HYPRLOCK_EOF'
background {
    monitor =
    color = rgba(25, 25, 25, 1.0)
    blur_passes = 2
}

input-field {
    monitor =
    size = 250, 50
    position = 0, -80
    halign = center
    valign = center
    outline_thickness = 2
    inner_color = rgba(0, 0, 0, 0.5)
    outer_color = rgba(255, 255, 255, 0.5)
    placeholder_text = <i>Password...</i>
    fade_on_empty = true
}

label {
    monitor =
    text = $TIME
    font_size = 64
    position = 0, 80
    halign = center
    valign = center
}
HYPRLOCK_EOF

# ----- hypridle -----
sudo tee /etc/xdg/hypr/hypridle.conf > /dev/null << 'HYPRIDLE_EOF'
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
}

listener {
    timeout = 300
    on-timeout = hyprlock
}

listener {
    timeout = 600
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}
HYPRIDLE_EOF

# ----- waybar config -----
sudo tee /etc/xdg/waybar/config.jsonc > /dev/null << 'WAYBAR_EOF'
{
    "layer": "top",
    "position": "top",
    "height": 32,
    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "network", "bluetooth", "battery", "tray"],

    "hyprland/workspaces": { "format": "{id}" },
    "clock": { "format": "{:%a %b %d  %H:%M}" },
    "pulseaudio": {
        "format": "{volume}% ",
        "format-muted": "muted",
        "on-click": "pavucontrol"
    },
    "network": {
        "format-wifi": "{essid} ({signalStrength}%) ",
        "format-ethernet": "eth ",
        "format-disconnected": "offline"
    },
    "bluetooth": { "format": "{status}" },
    "battery": {
        "format": "{capacity}% {icon}",
        "format-icons": ["", "", "", "", ""]
    },
    "tray": { "spacing": 8 }
}
WAYBAR_EOF

# ----- waybar style -----
sudo tee /etc/xdg/waybar/style.css > /dev/null << 'WAYBAR_CSS_EOF'
* {
    font-family: "JetBrainsMono Nerd Font", sans-serif;
    font-size: 13px;
    border: none;
    border-radius: 0;
}

window#waybar {
    background: rgba(30, 30, 46, 0.85);
    color: #cdd6f4;
}

#workspaces button {
    padding: 0 8px;
    color: #cdd6f4;
}

#workspaces button.active {
    background: #89b4fa;
    color: #1e1e2e;
}

#clock, #pulseaudio, #network, #bluetooth, #battery, #tray {
    padding: 0 10px;
}
WAYBAR_CSS_EOF

# ----- alacritty -----
sudo tee /etc/xdg/alacritty/alacritty.toml > /dev/null << 'ALACRITTY_EOF'
[window]
opacity = 0.95
padding = { x = 8, y = 8 }

[font]
size = 11
normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }

[colors.primary]
background = "#1e1e2e"
foreground = "#cdd6f4"
ALACRITTY_EOF

# ----- mako -----
sudo tee /etc/xdg/mako/config > /dev/null << 'MAKO_EOF'
background-color=#1e1e2e
text-color=#cdd6f4
border-color=#89b4fa
border-size=2
border-radius=8
default-timeout=5000
MAKO_EOF

ok "System configs written to /etc/xdg/"

# ============================================================
# Phase 6.5 — /etc/skel templates for new users
# ============================================================
log "Setting up /etc/skel for new users"

sudo mkdir -p /etc/skel/.config/hypr
sudo mkdir -p /etc/skel/.config/waybar
sudo mkdir -p /etc/skel/.config/mako
sudo mkdir -p /etc/skel/.config/alacritty

# Hyprland: thin override file that sources system config
sudo tee /etc/skel/.config/hypr/hyprland.conf > /dev/null << 'SKEL_HYPR_EOF'
# Personal Hyprland config — system defaults from /etc/xdg
source = /etc/xdg/hypr/hyprland.conf

# Add personal overrides below this line.
# Example: bind = SUPER, T, exec, my-custom-thing
SKEL_HYPR_EOF

# These need to live in ~/.config/hypr/ since their tools don't read XDG fallbacks reliably
sudo cp /etc/xdg/hypr/hyprpaper.conf /etc/skel/.config/hypr/
sudo cp /etc/xdg/hypr/hyprlock.conf  /etc/skel/.config/hypr/
sudo cp /etc/xdg/hypr/hypridle.conf  /etc/skel/.config/hypr/

# Waybar, mako, alacritty all check $XDG_CONFIG_DIRS, which includes /etc/xdg.
# Skel can stay empty for those — users who want to customize just create
# ~/.config/<tool>/<file>. We leave the dirs in place as a hint.

ok "/etc/skel populated"

# ============================================================
# Phase 6.6 — Apply configs to current primary user
# ============================================================
log "Applying configs to primary user ($PRIMARY_USER)"

# Don't clobber existing configs — only seed if missing
mkdir -p "$HOME/.config/hypr"

if [[ ! -f "$HOME/.config/hypr/hyprland.conf" ]]; then
    cp /etc/skel/.config/hypr/hyprland.conf "$HOME/.config/hypr/hyprland.conf"
    cp /etc/skel/.config/hypr/hyprpaper.conf "$HOME/.config/hypr/hyprpaper.conf"
    cp /etc/skel/.config/hypr/hyprlock.conf  "$HOME/.config/hypr/hyprlock.conf"
    cp /etc/skel/.config/hypr/hypridle.conf  "$HOME/.config/hypr/hypridle.conf"
    ok "Hyprland configs seeded for $PRIMARY_USER"
else
    warn "$HOME/.config/hypr/hyprland.conf already exists — leaving alone"
fi

# ============================================================
# Phase 7 — Optional: create additional user
# ============================================================
log "Phase 7: optional second user creation"

read -rp "Create a second user now? [y/N] " create_user
if [[ "$create_user" =~ ^[Yy]$ ]]; then
    read -rp "  Username: " new_user
    if id "$new_user" >/dev/null 2>&1; then
        warn "User $new_user already exists — skipping"
    else
        # -m triggers /etc/skel copy automatically
        sudo useradd -m -G wheel,video,audio,input -s /bin/bash "$new_user"
        sudo passwd "$new_user"
        ok "User $new_user created with configs from /etc/skel"
    fi
else
    log "Skipping second user. Add later with:"
    echo "    sudo useradd -m -G wheel,video,audio,input -s /bin/bash <username>"
    echo "    sudo passwd <username>"
fi

# ============================================================
# Done
# ============================================================
echo
ok "All phases complete."
echo
echo "Next steps:"
echo "  1. Reboot:      sudo reboot"
echo "  2. At SDDM, pick a user, ensure session is 'Hyprland', log in"
echo "  3. Try keybinds:"
echo "       Super + Return  -> alacritty"
echo "       Super + D       -> wofi launcher"
echo "       Super + B       -> firefox"
echo "       Super + L       -> lock screen"
echo "       Super + Q       -> close window"
echo
echo "To change system-wide config:    sudo \$EDITOR /etc/xdg/hypr/hyprland.conf"
echo "To change personal config only:  \$EDITOR ~/.config/hypr/hyprland.conf"
echo
