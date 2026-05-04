#!/usr/bin/env bash
# ============================================================
# Personal Hyprland setup script for fresh Arch Linux
#
# Prerequisites:
#   - Arch base system installed via archinstall (Minimal profile)
#   - btrfs, no encryption, systemd-boot, NetworkManager
#   - Logged in as your primary (sudo-capable) user
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
    err "sudo is not installed."
    exit 1
fi

if ! ping -c 1 -W 3 archlinux.org >/dev/null 2>&1; then
    err "No network. Bring up NetworkManager (sudo systemctl enable --now NetworkManager) first."
    exit 1
fi

PRIMARY_USER="$USER"
log "Setting up for primary user: $PRIMARY_USER"

# Cache sudo creds upfront and keep them refreshed
sudo -v
( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null || true' EXIT

# ============================================================
# Phase 2 — System update + multilib (for Steam)
# ============================================================
log "Phase 2: enabling multilib and updating system"

if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
    ok "multilib enabled"
else
    ok "multilib already enabled"
fi

sudo pacman -Syu --noconfirm

# ============================================================
# Phase 3 — Hyprland stack (official repos only, no AUR)
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
    qt5-wayland qt6-wayland \
    qt5-graphicaleffects qt5-quickcontrols2 qt5-svg

sudo systemctl enable --now bluetooth
ok "Hyprland stack installed"

# ============================================================
# Phase 4 — SDDM + theming to match Hyprland look
# ============================================================
log "Phase 4: installing and theming SDDM"

sudo pacman -S --needed --noconfirm sddm
sudo systemctl enable sddm

sudo mkdir -p /etc/sddm.conf.d

sudo tee /etc/sddm.conf.d/10-wayland.conf > /dev/null << 'SDDM_WL_EOF'
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=Hyprland
SDDM_WL_EOF

sudo tee /etc/sddm.conf.d/20-theme.conf > /dev/null << 'SDDM_THEME_EOF'
[Theme]
Current=hyprland-dark
CursorTheme=Adwaita
Font=JetBrainsMono Nerd Font

[Users]
MaximumUid=60000
MinimumUid=1000

[General]
Numlock=on
SDDM_THEME_EOF

# Custom dark SDDM theme matching Hyprland palette
# (Catppuccin Mocha-ish: bg #1e1e2e, accent #89b4fa, text #cdd6f4)
sudo mkdir -p /usr/share/sddm/themes/hyprland-dark

sudo tee /usr/share/sddm/themes/hyprland-dark/metadata.desktop > /dev/null << 'META_EOF'
[SddmGreeterTheme]
Name=hyprland-dark
Description=Dark theme matching Hyprland setup
Author=local
License=MIT
Type=sddm-theme
Version=1.0
MainScript=Main.qml
ConfigFile=theme.conf
Theme-Id=hyprland-dark
Theme-API=2.0
META_EOF

sudo tee /usr/share/sddm/themes/hyprland-dark/theme.conf > /dev/null << 'THEMECONF_EOF'
[General]
backgroundColor=#1e1e2e
accentColor=#89b4fa
textColor=#cdd6f4
fontFamily=JetBrainsMono Nerd Font
fontSize=11
THEMECONF_EOF

sudo tee /usr/share/sddm/themes/hyprland-dark/Main.qml > /dev/null << 'QML_EOF'
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#1e1e2e"

    property string accent: "#89b4fa"
    property string textColor: "#cdd6f4"
    property string subtle: "#45475a"
    property string surface: "#313244"

    Rectangle {
        id: card
        width: 380
        height: 360
        radius: 12
        color: "#252535"
        border.color: subtle
        border.width: 1
        anchors.centerIn: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 14

            Text {
                id: clock
                Layout.alignment: Qt.AlignHCenter
                color: textColor
                font.family: "JetBrainsMono Nerd Font"
                font.pointSize: 28
                text: Qt.formatDateTime(new Date(), "HH:mm")
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                color: subtle
                font.family: "JetBrainsMono Nerd Font"
                font.pointSize: 10
                text: Qt.formatDateTime(new Date(), "ddd, MMM d")
            }
            Timer {
                interval: 1000; running: true; repeat: true
                onTriggered: clock.text = Qt.formatDateTime(new Date(), "HH:mm")
            }

            Item { Layout.preferredHeight: 6 }

            ComboBox {
                id: userBox
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                model: userModel
                textRole: "name"
                currentIndex: userModel.lastIndex
                font.family: "JetBrainsMono Nerd Font"
                font.pointSize: 11

                background: Rectangle {
                    color: surface
                    radius: 6
                    border.color: subtle
                    border.width: 1
                }
                contentItem: Text {
                    leftPadding: 12
                    text: userBox.displayText
                    font: userBox.font
                    color: textColor
                    verticalAlignment: Text.AlignVCenter
                }
            }

            TextField {
                id: pwField
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                echoMode: TextInput.Password
                placeholderText: "Password"
                placeholderTextColor: subtle
                color: textColor
                font.family: "JetBrainsMono Nerd Font"
                font.pointSize: 11
                selectByMouse: true
                background: Rectangle {
                    color: surface
                    radius: 6
                    border.color: pwField.activeFocus ? accent : subtle
                    border.width: pwField.activeFocus ? 2 : 1
                }
                onAccepted: loginButton.clicked()
                Component.onCompleted: forceActiveFocus()
            }

            Button {
                id: loginButton
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                text: "Sign in"
                font.family: "JetBrainsMono Nerd Font"
                font.pointSize: 11
                background: Rectangle {
                    color: parent.hovered ? "#a4c2ff" : accent
                    radius: 6
                }
                contentItem: Text {
                    text: loginButton.text
                    color: "#1e1e2e"
                    font: loginButton.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: sddm.login(userBox.currentText, pwField.text, sessionBox.currentIndex)
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Session"
                    color: subtle
                    font.family: "JetBrainsMono Nerd Font"
                    font.pointSize: 9
                }
                Item { Layout.fillWidth: true }
                ComboBox {
                    id: sessionBox
                    Layout.preferredWidth: 180
                    Layout.preferredHeight: 30
                    model: sessionModel
                    textRole: "name"
                    currentIndex: sessionModel.lastIndex
                    font.family: "JetBrainsMono Nerd Font"
                    font.pointSize: 9
                    background: Rectangle {
                        color: "transparent"
                        radius: 4
                        border.color: subtle
                        border.width: 1
                    }
                    contentItem: Text {
                        leftPadding: 8
                        text: sessionBox.displayText
                        color: textColor
                        font: sessionBox.font
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    RowLayout {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 16

        Button {
            text: "Reboot"
            font.family: "JetBrainsMono Nerd Font"
            font.pointSize: 9
            background: Rectangle { color: "transparent" }
            contentItem: Text { text: parent.text; color: subtle; font: parent.font }
            onClicked: sddm.reboot()
        }
        Button {
            text: "Shutdown"
            font.family: "JetBrainsMono Nerd Font"
            font.pointSize: 9
            background: Rectangle { color: "transparent" }
            contentItem: Text { text: parent.text; color: subtle; font: parent.font }
            onClicked: sddm.powerOff()
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            pwField.text = ""
            pwField.placeholderText = "Wrong password"
            pwField.forceActiveFocus()
        }
    }
}
QML_EOF

ok "SDDM theme installed (hyprland-dark)"

# ============================================================
# Phase 5 — User-facing apps (no AUR)
# ============================================================
log "Phase 5: installing apps (Firefox, Steam)"

sudo pacman -S --needed --noconfirm firefox

sudo pacman -S --needed --noconfirm steam || \
    warn "Steam install needs graphics driver selection — re-run 'sudo pacman -S steam' interactively"

ok "Apps installed"

# ============================================================
# Phase 6 — System-wide configs in /etc/xdg
# ============================================================
log "Phase 6: writing system-wide configs to /etc/xdg"

sudo mkdir -p /etc/xdg/hypr /etc/xdg/waybar /etc/xdg/mako /etc/xdg/alacritty /etc/xdg/wofi

# ----- Hyprland main config (FIXED for 0.45+ shadow syntax) -----
sudo tee /etc/xdg/hypr/hyprland.conf > /dev/null << 'HYPR_EOF'
# ============================================================
# System-wide Hyprland config
# Per-user file (~/.config/hypr/hyprland.conf) sources this then overrides
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
    col.active_border = rgba(89b4faee) rgba(74c7ecee) 45deg
    col.inactive_border = rgba(45475aaa)
    layout = dwindle
}

decoration {
    rounding = 8

    blur {
        enabled = true
        size = 6
        passes = 2
        new_optimizations = true
    }

    # Hyprland 0.45+ shadow subblock (was: drop_shadow / shadow_range / shadow_render_power)
    shadow {
        enabled = true
        range = 8
        render_power = 3
        color = rgba(00000055)
    }
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

# Workspaces
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

# Media + brightness
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
# Drop a wallpaper at ~/Pictures/wallpaper.jpg and uncomment:
# preload = ~/Pictures/wallpaper.jpg
# wallpaper = ,~/Pictures/wallpaper.jpg
HYPRPAPER_EOF

# ----- hyprlock (FIXED: visible password dots, proper colors) -----
sudo tee /etc/xdg/hypr/hyprlock.conf > /dev/null << 'HYPRLOCK_EOF'
# ============================================================
# hyprlock — locks the CURRENT user's session.
# It does NOT support switching users (by design).
# To switch users: log out (Super+Shift+E) -> SDDM -> pick other user.
# ============================================================

general {
    grace = 0
    hide_cursor = false
    no_fade_in = false
    disable_loading_bar = true
}

background {
    monitor =
    color = rgba(30, 30, 46, 1.0)
    blur_passes = 2
    blur_size = 7
}

# Big clock
label {
    monitor =
    text = cmd[update:1000] echo "$(date +'%H:%M')"
    color = rgba(205, 214, 244, 1.0)
    font_size = 90
    font_family = JetBrainsMono Nerd Font
    position = 0, 200
    halign = center
    valign = center
}

# Date
label {
    monitor =
    text = cmd[update:60000] echo "$(date +'%A, %B %d')"
    color = rgba(166, 173, 200, 1.0)
    font_size = 18
    font_family = JetBrainsMono Nerd Font
    position = 0, 110
    halign = center
    valign = center
}

# Username greeting
label {
    monitor =
    text =   $USER
    color = rgba(137, 180, 250, 1.0)
    font_size = 16
    font_family = JetBrainsMono Nerd Font
    position = 0, -20
    halign = center
    valign = center
}

# Password input — visible dots, focus border, fail state
input-field {
    monitor =
    size = 320, 55
    position = 0, -90
    halign = center
    valign = center

    outline_thickness = 2
    rounding = 10

    inner_color   = rgba(49, 50, 68, 0.85)
    outer_color   = rgba(137, 180, 250, 1.0)
    check_color   = rgba(166, 227, 161, 1.0)
    fail_color    = rgba(243, 139, 168, 1.0)
    font_color    = rgba(205, 214, 244, 1.0)

    # Dot visibility — these are what was missing
    dots_size     = 0.30
    dots_spacing  = 0.30
    dots_center   = true
    dots_rounding = -1

    placeholder_text = <i>Password...</i>
    fail_text        = <i>$FAIL ($ATTEMPTS)</i>

    fade_on_empty = false
    hide_input    = false

    capslock_color = rgba(249, 226, 175, 1.0)
}

# Bottom hint
label {
    monitor =
    text = Press Enter to unlock  ·  Log out from session to switch users
    color = rgba(108, 112, 134, 1.0)
    font_size = 11
    font_family = JetBrainsMono Nerd Font
    position = 0, 40
    halign = center
    valign = bottom
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

# ----- waybar -----
sudo tee /etc/xdg/waybar/config.jsonc > /dev/null << 'WAYBAR_EOF'
{
    "layer": "top",
    "position": "top",
    "height": 32,
    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "network", "bluetooth", "battery", "tray"],

    "hyprland/workspaces": { "format": "{id}" },
    "hyprland/window":     { "max-length": 60 },
    "clock":               { "format": "{:%a %b %d  %H:%M}" },
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

# ----- wofi -----
sudo tee /etc/xdg/wofi/style.css > /dev/null << 'WOFI_CSS_EOF'
window {
    background-color: #1e1e2e;
    color: #cdd6f4;
    border: 2px solid #89b4fa;
    border-radius: 10px;
    font-family: "JetBrainsMono Nerd Font", sans-serif;
    font-size: 13px;
}

#input {
    margin: 8px;
    padding: 6px 10px;
    background-color: #313244;
    color: #cdd6f4;
    border: none;
    border-radius: 6px;
}

#entry:selected {
    background-color: #89b4fa;
    color: #1e1e2e;
    border-radius: 6px;
}
WOFI_CSS_EOF

ok "System configs written to /etc/xdg/"

# ============================================================
# Phase 6.5 — /etc/skel: new users get configs automatically
# ============================================================
log "Setting up /etc/skel so new users get full default configs"

sudo mkdir -p \
    /etc/skel/.config/hypr \
    /etc/skel/.config/waybar \
    /etc/skel/.config/mako \
    /etc/skel/.config/alacritty \
    /etc/skel/.config/wofi \
    /etc/skel/Pictures

# Hyprland: thin override file that sources system config
sudo tee /etc/skel/.config/hypr/hyprland.conf > /dev/null << 'SKEL_HYPR_EOF'
# Personal Hyprland config
# System defaults are sourced from /etc/xdg/hypr/hyprland.conf
# Add personal keybinds, monitor settings, etc. AFTER the source line
source = /etc/xdg/hypr/hyprland.conf

# === your personal overrides below ===
# Example:
# bind = SUPER, T, exec, my-custom-thing
SKEL_HYPR_EOF

# hyprpaper, hyprlock, hypridle read only from ~/.config/hypr/, so copy them in:
sudo cp /etc/xdg/hypr/hyprpaper.conf /etc/skel/.config/hypr/
sudo cp /etc/xdg/hypr/hyprlock.conf  /etc/skel/.config/hypr/
sudo cp /etc/xdg/hypr/hypridle.conf  /etc/skel/.config/hypr/

# Waybar/mako/alacritty/wofi all read $XDG_CONFIG_DIRS automatically when
# user has no own config — empty skel dirs is fine, they fall through to /etc/xdg.

ok "/etc/skel populated — future 'useradd -m' will auto-copy these"

# ============================================================
# Phase 6.6 — Apply configs to existing primary user
# ============================================================
log "Seeding configs for current primary user ($PRIMARY_USER)"

mkdir -p "$HOME/.config/hypr"

if [[ ! -f "$HOME/.config/hypr/hyprland.conf" ]]; then
    cp /etc/skel/.config/hypr/hyprland.conf "$HOME/.config/hypr/hyprland.conf"
    cp /etc/skel/.config/hypr/hyprpaper.conf "$HOME/.config/hypr/hyprpaper.conf"
    cp /etc/skel/.config/hypr/hyprlock.conf  "$HOME/.config/hypr/hyprlock.conf"
    cp /etc/skel/.config/hypr/hypridle.conf  "$HOME/.config/hypr/hypridle.conf"
    ok "Hyprland configs seeded for $PRIMARY_USER"
else
    warn "$HOME/.config/hypr/hyprland.conf exists — leaving alone"
    warn "  to refresh: rm -rf ~/.config/hypr && rerun this script"
fi

# ============================================================
# Phase 7 — Optional: create additional user
# ============================================================
log "Phase 7: optional second user"

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
    log "Skipping. Add later — they'll auto-receive skel configs:"
    echo "    sudo useradd -m -G wheel,video,audio,input -s /bin/bash <username>"
    echo "    sudo passwd <username>"
fi

# ============================================================
# Done
# ============================================================
echo
ok "All phases complete."
echo
echo "Reboot:  sudo reboot"
echo
echo "Keybinds:"
echo "  Super + Return    alacritty       Super + D       wofi launcher"
echo "  Super + B         firefox          Super + E       file manager"
echo "  Super + L         lock screen      Super + Q       close window"
echo "  Super + Shift+E   exit (back to SDDM, where you can switch user)"
echo
echo "Configs:"
echo "  System-wide:    sudo \$EDITOR /etc/xdg/hypr/hyprland.conf"
echo "  Personal:       \$EDITOR ~/.config/hypr/hyprland.conf"
echo "  SDDM theme:     /usr/share/sddm/themes/hyprland-dark/"
echo
