#!/usr/bin/env bash
# shellcheck disable=SC2059
# ==============================================================================
#  Duskyport — Fleet Dashboard & Virtual Machine Manager for Dusky & Arch Linux
#  Maintained by Ubaid (https://github.com/Ubaidullah-Web-Dev/duskyport)
#
#  Usage:
#    curl -sSL https://raw.githubusercontent.com/Ubaidullah-Web-Dev/duskyport/main/install.sh | bash
#    or:
#    ./install.sh [options]
#
#  Options:
#    -y, --yes, --unattended   Non-interactive mode (use default options)
#    --no-extras               Skip installing optional VM tools (quickemu, picocom, etc.)
#    --no-matugen              Skip configuring Matugen theming
#    --no-rules                Skip configuring Hyprland window rules
#    -u, --uninstall           Uninstall Duskyport and revert configurations
#    --remove-deps             During uninstall, also remove optional VM dependencies
#    --purge                   During uninstall, also remove user configs and data
# ==============================================================================
set -euo pipefail
# shellcheck disable=SC2059

# Text styling
BOLD="$(tput bold 2>/dev/null || true)"
GREEN="$(tput setaf 2 2>/dev/null || true)"
CYAN="$(tput setaf 6 2>/dev/null || true)"
YELLOW="$(tput setaf 3 2>/dev/null || true)"
RED="$(tput setaf 1 2>/dev/null || true)"
RESET="$(tput sgr0 2>/dev/null || true)"

log_info()  { printf "${CYAN}==>${RESET} ${BOLD}%s${RESET}\n" "$1"; }
log_ok()    { printf "${GREEN}  ✓${RESET} %s\n" "$1"; }
log_warn()  { printf "${YELLOW}  !${RESET} %s\n" "$1"; }
log_err()   { printf "${RED}  ✗${RESET} %s\n" "$1" >&2; }

# Parse arguments
MODE="install"
UNATTENDED=false
INSTALL_EXTRAS=true
CONFIG_MATUGEN=true
CONFIG_RULES=true
PURGE=false
REMOVE_DEPS=false

for arg in "$@"; do
  case "$arg" in
    -u|--uninstall)
      MODE="uninstall"
      ;;
    --purge)
      PURGE=true
      REMOVE_DEPS=true
      ;;
    --remove-deps)
      REMOVE_DEPS=true
      ;;
    --keep-deps)
      REMOVE_DEPS=false
      ;;
    -y|--yes|--unattended)
      UNATTENDED=true
      ;;
    --no-extras)
      INSTALL_EXTRAS=false
      ;;
    --no-matugen)
      CONFIG_MATUGEN=false
      ;;
    --no-rules)
      CONFIG_RULES=false
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo ""
      echo "Installation Options:"
      echo "  -y, --yes, --unattended   Non-interactive mode (use default options)"
      echo "  --no-extras               Skip installing optional VM tools (quickemu, picocom, etc.)"
      echo "  --no-matugen              Skip configuring Matugen theming"
      echo "  --no-rules                Skip configuring Hyprland window rules"
      echo ""
      echo "Uninstallation Options:"
      echo "  -u, --uninstall           Safely uninstall Duskyport and revert configurations"
      echo "  --remove-deps             Also uninstall optional VM tools (quickemu, spice-gtk, etc.)"
      echo "  --purge                   Remove user data (~/.config/duskyport) and optional deps"
      exit 0
      ;;
  esac
done

do_uninstall() {
  printf "\n"
  printf "${RED}${BOLD}======================================================${RESET}\n"
  printf "${RED}${BOLD}  Duskyport Uninstaller${RESET}\n"
  printf "${RED}${BOLD}======================================================${RESET}\n\n"

  local rm_matugen=true
  local rm_rules=true
  local rm_user_data="$PURGE"
  local rm_deps="$REMOVE_DEPS"

  if [[ "$UNATTENDED" != "true" && -t 0 ]]; then
    printf "${BOLD}Uninstallation Options:${RESET}\n"

    read -r -p "  Revert Matugen theming configuration (~/.config/matugen/config.toml)? [Y/n] " ans_mat
    ans_mat="${ans_mat:-y}"
    [[ "$ans_mat" =~ ^[Yy]$ ]] || rm_matugen=false

    read -r -p "  Revert Dusky/Hyprland window rules (~/.config/hypr/user.lua)? [Y/n] " ans_rul
    ans_rul="${ans_rul:-y}"
    [[ "$ans_rul" =~ ^[Yy]$ ]] || rm_rules=false

    read -r -p "  Remove Duskyport user configs and cached skins (~/.config/duskyport)? [y/N] " ans_cfg
    ans_cfg="${ans_cfg:-n}"
    [[ "$ans_cfg" =~ ^[Yy]$ ]] && rm_user_data=true

    read -r -p "  Uninstall optional VM & console packages (quickemu, spice-gtk, etc.)? [y/N] " ans_dp
    ans_dp="${ans_dp:-n}"
    [[ "$ans_dp" =~ ^[Yy]$ ]] && rm_deps=true

    printf "\n"
  fi

  # 1. Remove Binaries
  log_info "Removing Duskyport binaries from /usr/bin..."
  sudo rm -f \
    /usr/bin/duskyport \
    /usr/bin/duskyvm \
    /usr/bin/duskyport-fetch \
    /usr/bin/duskyport-mon \
    /usr/bin/duskyssh \
    /usr/bin/duskyport-ssh \
    /usr/bin/duskyport-gpuvm \
    /usr/bin/duskyport-qml
  log_ok "Binaries removed."

  # 2. Remove Application Data
  log_info "Removing Duskyport application data..."
  sudo rm -rf "/usr/share/duskyport"
  sudo rm -rf "/usr/share/quickshell/duskyport"

  if command -v duskytunes >/dev/null 2>&1; then
    log_info "Preserving Dusky.Ui runtime (required by Duskytunes)."
  else
    sudo rm -rf "/usr/lib/qt6/qml/Dusky/Ui"
    rm -rf "$HOME/.local/lib/qt6/qml/Dusky/Ui"
    rm -rf "$HOME/.local/share/quickshell/Dusky/Ui"
    log_ok "Dusky design runtime removed."
  fi
  log_ok "Application data removed."

  # 3. Remove Desktop Entries and Icons
  log_info "Removing desktop entries and icons..."
  sudo rm -f "/usr/share/applications/duskyport.desktop"
  rm -f "$HOME/.local/share/applications/duskyport.desktop"
  for s in 16 32 48 64 128 256 512; do
    sudo rm -f "/usr/share/icons/hicolor/${s}x${s}/apps/duskyport.png"
  done
  sudo rm -f "/usr/share/icons/hicolor/scalable/apps/duskyport.svg"
  sudo gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null || true
  sudo update-desktop-database -q /usr/share/applications 2>/dev/null || true
  update-desktop-database -q "$HOME/.local/share/applications" 2>/dev/null || true
  log_ok "Desktop launchers and icons removed."

  # 4. Safely Revert Matugen
  if [[ "$rm_matugen" == "true" ]]; then
    log_info "Safely reverting Matugen template registration..."
    local mat_conf="$HOME/.config/matugen/config.toml"
    if [[ -f "$mat_conf" ]]; then
      cp -a "$mat_conf" "$mat_conf.bak.$(date +%Y%m%d%H%M%S)"
      python3 - "$mat_conf" << 'PY'
import sys
from pathlib import Path
p = Path(sys.argv[1])
if not p.exists():
    sys.exit(0)
lines = p.read_text().splitlines(keepends=True)
out = []
in_target = False
for line in lines:
    stripped = line.strip()
    if stripped == "[templates.duskyport]":
        in_target = True
        continue
    if in_target:
        if stripped.startswith("[") and stripped.endswith("]"):
            in_target = False
            out.append(line)
        else:
            continue
    else:
        out.append(line)
p.write_text("".join(out).rstrip() + "\n")
PY
      log_ok "Reverted [templates.duskyport] in ~/.config/matugen/config.toml (backup created)."
    fi
    rm -f "$HOME/.config/matugen/templates/duskyport.json"
    rm -rf "$HOME/.config/duskyport/skins/matugen"
  fi

  # 5. Revert Hyprland Window Rules
  if [[ "$rm_rules" == "true" ]]; then
    log_info "Reverting Dusky/Hyprland window rules..."
    local hypr_lua="$HOME/.config/hypr/user.lua"
    if [[ -f "$hypr_lua" ]]; then
      python3 - "$hypr_lua" << 'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
if not p.exists():
    sys.exit(0)
begin = '-- BEGIN DUSKYPORT MANAGED WINDOW RULE'
end = '-- END DUSKYPORT MANAGED WINDOW RULE'
s = p.read_text()
while begin in s:
    a = s.index(begin)
    b = s.find(end, a)
    if b < 0:
        s = s[:a]
        break
    b += len(end)
    if b < len(s) and s[b:b+1] == '\n': b += 1
    s = s[:a] + s[b:]
p.write_text(s.rstrip() + ('\n' if s.strip() else ''))
PY
      command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true
      log_ok "Hyprland window rules removed."
    fi
  fi

  # 6. User Config and State
  if [[ "$rm_user_data" == "true" ]]; then
    log_info "Purging user data in ~/.config/duskyport and ~/.local/share/duskyport..."
    rm -rf "$HOME/.config/duskyport"
    rm -rf "$HOME/.local/share/duskyport"
    rm -rf "$HOME/.cache/duskyport"
    log_ok "User data purged."
  else
    log_info "Preserving user configuration in ~/.config/duskyport (use --purge to delete)."
  fi

  # 7. Optional Dependency Removal
  if [[ "$rm_deps" == "true" ]]; then
    log_info "Checking optional dependencies for safe removal..."
    local candidates=(quickemu spice-gtk libisoburn picocom inetutils freerdp tigervnc)
    for pkg in "${candidates[@]}"; do
      if pacman -Qi "$pkg" >/dev/null 2>&1; then
        local count=0
        if command -v pactree >/dev/null 2>&1; then
          count=$(pactree -r "$pkg" 2>/dev/null | wc -l || echo 0)
        fi
        if [[ "$count" -le 1 ]]; then
          log_info "Removing unused dependency: $pkg..."
          sudo pacman -R --noconfirm "$pkg" 2>/dev/null || true
        else
          log_warn "Skipping $pkg: required by another installed package."
        fi
      fi
    done
    log_ok "Optional dependencies cleaned."
  fi

  printf "\n"
  printf "${GREEN}${BOLD}======================================================${RESET}\n"
  printf "${GREEN}${BOLD}  Duskyport has been successfully uninstalled!${RESET}\n"
  printf "${GREEN}${BOLD}======================================================${RESET}\n\n"
  exit 0
}

if [[ "$MODE" == "uninstall" ]]; then
  do_uninstall
fi

printf "\n"
printf "${CYAN}${BOLD}"
cat << 'EOF'
    ____             __                                 __ 
   / __ \__  _______/ /____  ______  ____  ____  _____/ /_
  / / / / / / / ___/ //_/ / / / __ \/ __ \/ __ \/ ___/ __/
 / /_/ / /_/ (__  ) ,< / /_/ / /_/ / /_/ / /_/ / /  / /_  
/_____/\__,_/____/_/|_|\__, / .___/\____/\____/_/   \__/  
                      /____/_/                            
EOF
printf "${RESET}"
printf "   ${BOLD}Duskyport Installer for Dusky OS & Arch Linux${RESET}\n"
printf "   ${CYAN}Created & Maintained by Ubaid${RESET}\n\n"

# Verify system is Arch/pacman-based
if ! command -v pacman >/dev/null 2>&1; then
  log_err "This installer requires an Arch-based Linux distribution (with pacman)."
  exit 1
fi

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  log_err "Please run this script as your regular user (not root). It will invoke sudo when needed."
  exit 1
fi

# Interactive Questionnaire (if interactive and not unattended)
if [[ "$UNATTENDED" != "true" && -t 0 ]]; then
  printf "${BOLD}Installation Options:${RESET}\n"
  
  read -r -p "  Install recommended VM & console tools (quickemu, picocom, freerdp)? [Y/n] " ans_extras
  ans_extras="${ans_extras:-y}"
  if [[ ! "$ans_extras" =~ ^[Yy]$ ]]; then
    INSTALL_EXTRAS=false
  fi

  read -r -p "  Configure Matugen Material 3 dynamic theming template? [Y/n] " ans_matugen
  ans_matugen="${ans_matugen:-y}"
  if [[ ! "$ans_matugen" =~ ^[Yy]$ ]]; then
    CONFIG_MATUGEN=false
  fi

  if [[ -f "$HOME/.config/hypr/hyprland.lua" ]]; then
    read -r -p "  Configure Dusky/Hyprland window floating rule for Duskyport? [Y/n] " ans_rules
    ans_rules="${ans_rules:-y}"
    if [[ ! "$ans_rules" =~ ^[Yy]$ ]]; then
      CONFIG_RULES=false
    fi
  else
    CONFIG_RULES=false
  fi
  printf "\n"
fi

# Locate or fetch source tree
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
TEMP_DIR=""

if [[ -f "$SCRIPT_DIR/client/shell.qml" && -d "$SCRIPT_DIR/runtime" ]]; then
  SRC_ROOT="$SCRIPT_DIR"
else
  log_info "Downloading Duskyport source files from GitHub..."
  TEMP_DIR="$(mktemp -d /tmp/duskyport-install-XXXXXX)"
  trap 'rm -rf "$TEMP_DIR"' EXIT
  git clone --depth 1 https://github.com/Ubaidullah-Web-Dev/Duskyport.git "$TEMP_DIR"
  SRC_ROOT="$TEMP_DIR"
fi

# Step 1: Install system dependencies
log_info "Installing core dependencies via pacman..."
sudo pacman -S --needed --noconfirm \
  quickshell \
  matugen \
  openssl \
  librsvg \
  desktop-file-utils \
  hicolor-icon-theme \
  xdg-utils \
  polkit \
  jq
log_ok "Core system dependencies installed."

# Step 2: Install optional VM & Remote tools if requested
if [[ "$INSTALL_EXTRAS" == "true" ]]; then
  log_info "Installing recommended VM and console berths..."
  sudo pacman -S --needed --noconfirm \
    spice-gtk \
    libisoburn \
    qemu-desktop \
    cdrtools \
    zsync \
    picocom \
    inetutils \
    freerdp \
    tigervnc 2>/dev/null || true

  # Try to install quickemu via AUR helper if available
  if command -v yay >/dev/null 2>&1; then
    log_info "Installing quickemu from AUR via yay..."
    yay -S --needed --noconfirm quickemu 2>/dev/null || log_warn "Could not install quickemu via yay automatically."
  elif command -v paru >/dev/null 2>&1; then
    log_info "Installing quickemu from AUR via paru..."
    paru -S --needed --noconfirm quickemu 2>/dev/null || log_warn "Could not install quickemu via paru automatically."
  else
    log_warn "No AUR helper (yay/paru) detected. Install 'quickemu' manually to download automated OS images."
  fi
  log_ok "VM and console tools installed."
fi

# Step 3: Install QML design runtime (Dusky.Ui / Singletons)
log_info "Installing Dusky QML design runtime (Tokens & Singletons)..."
if [[ -d "$SRC_ROOT/runtime/qml/Dusky/Ui" ]]; then
  mkdir -p "$HOME/.local/lib/qt6/qml/Dusky"
  rm -rf "$HOME/.local/lib/qt6/qml/Dusky/Ui"
  cp -r "$SRC_ROOT/runtime/qml/Dusky/Ui" "$HOME/.local/lib/qt6/qml/Dusky/"

  mkdir -p "$HOME/.local/share/quickshell/Dusky"
  rm -rf "$HOME/.local/share/quickshell/Dusky/Ui"
  cp -r "$SRC_ROOT/runtime/qml/Dusky/Ui" "$HOME/.local/share/quickshell/Dusky/"

  sudo mkdir -p "/usr/lib/qt6/qml/Dusky"
  sudo rm -rf "/usr/lib/qt6/qml/Dusky/Ui"
  sudo cp -r "$SRC_ROOT/runtime/qml/Dusky/Ui" "/usr/lib/qt6/qml/Dusky/"

  sudo mkdir -p "/usr/share/duskyport/qml/Dusky"
  sudo rm -rf "/usr/share/duskyport/qml/Dusky/Ui"
  sudo cp -r "$SRC_ROOT/runtime/qml/Dusky/Ui" "/usr/share/duskyport/qml/Dusky/"

  log_ok "Dusky QML design runtime registered."
else
  log_warn "QML runtime directory not found in source tree."
fi

# Step 4: Build or Install Binaries
log_info "Installing Duskyport engine and helper binaries..."
BIN_DIR="$SRC_ROOT/bin/x86_64"

# If Go is installed and sources present, build fresh binaries
if command -v go >/dev/null 2>&1 && [[ -d "$SRC_ROOT/cmd" ]]; then
  log_info "Compiling helper engines with Go..."
  mkdir -p "$BIN_DIR"
  (cd "$SRC_ROOT" && go build -ldflags="-s -w" -o "$BIN_DIR/duskyport-fetch" ./cmd/duskyport-fetch)
  (cd "$SRC_ROOT" && go build -ldflags="-s -w" -o "$BIN_DIR/duskyport-mon" ./cmd/duskyport-mon)
  (cd "$SRC_ROOT" && go build -ldflags="-s -w" -o "$BIN_DIR/duskyssh" ./cmd/duskyssh)
  (cd "$SRC_ROOT" && go build -ldflags="-s -w" -o "$BIN_DIR/duskyport-gpuvm" ./cmd/duskyport-gpuvm)
  log_ok "Helper engines compiled."
fi

# Install main script
sudo install -Dm755 "$SRC_ROOT/bin/duskyport" "/usr/bin/duskyport"
sudo ln -sf "/usr/bin/duskyport" "/usr/bin/duskyvm"

# Install Go helpers
if [[ -f "$BIN_DIR/duskyport-fetch" ]]; then
  sudo install -Dm755 "$BIN_DIR/duskyport-fetch" "/usr/bin/duskyport-fetch"
  sudo install -Dm755 "$BIN_DIR/duskyport-mon" "/usr/bin/duskyport-mon"
  sudo install -Dm755 "$BIN_DIR/duskyssh" "/usr/bin/duskyssh"
  sudo ln -sf "/usr/bin/duskyssh" "/usr/bin/duskyport-ssh"
  sudo install -Dm755 "$BIN_DIR/duskyport-gpuvm" "/usr/bin/duskyport-gpuvm"
else
  log_err "Binaries not found in $BIN_DIR!"
  exit 1
fi

# Launcher script
if [[ -f "$SRC_ROOT/packaging/linux/duskyport-qml" ]]; then
  sudo install -Dm755 "$SRC_ROOT/packaging/linux/duskyport-qml" "/usr/bin/duskyport-qml"
fi
log_ok "Binaries installed to /usr/bin."

# Step 5: Install Client UI
log_info "Installing QML client UI..."
sudo rm -rf "/usr/share/duskyport/client"
sudo install -dm755 "/usr/share/duskyport/client"
sudo cp -r "$SRC_ROOT/client/." "/usr/share/duskyport/client/"

# Also register in quickshell default config location
sudo install -dm755 "/usr/share/quickshell/duskyport"
sudo cp -r "$SRC_ROOT/client/." "/usr/share/quickshell/duskyport/"

log_ok "Client UI installed to /usr/share/duskyport/client and /usr/share/quickshell/duskyport."

# Step 6: Configure Matugen Dynamic Theming
if [[ "$CONFIG_MATUGEN" == "true" ]]; then
  log_info "Configuring Matugen dynamic theming..."
  MATUGEN_DIR="$HOME/.config/matugen"
  MATUGEN_CONF="$MATUGEN_DIR/config.toml"
  DUSKYPORT_SKINS="$HOME/.config/duskyport/skins/matugen"
  mkdir -p "$DUSKYPORT_SKINS"

  sudo install -dm755 "/usr/share/duskyport/matugen"
  sudo install -Dm644 "$SRC_ROOT/matugen/duskyport.json" "/usr/share/duskyport/matugen/duskyport.json"

  if command -v matugen >/dev/null 2>&1; then
    mkdir -p "$MATUGEN_DIR/templates"
    install -Dm644 "$SRC_ROOT/matugen/duskyport.json" "$MATUGEN_DIR/templates/duskyport.json"

    if [[ -f "$MATUGEN_CONF" ]]; then
      if ! grep -q "templates.duskyport" "$MATUGEN_CONF"; then
        cat << 'MATUGEN_EOF' >> "$MATUGEN_CONF"

[templates.duskyport]
input_path  = '/usr/share/duskyport/matugen/duskyport.json'
output_path = '~/.config/duskyport/skins/matugen/skin.json'
MATUGEN_EOF
        log_ok "Registered Duskyport template in ~/.config/matugen/config.toml"
      fi
    else
      mkdir -p "$MATUGEN_DIR"
      cat << 'MATUGEN_EOF' > "$MATUGEN_CONF"
[config]

[templates.duskyport]
input_path  = '/usr/share/duskyport/matugen/duskyport.json'
output_path = '~/.config/duskyport/skins/matugen/skin.json'
MATUGEN_EOF
      log_ok "Created ~/.config/matugen/config.toml with Duskyport template"
    fi

    # Attempt initial theme generation from current wallpaper
    WALLPAPER=""
    for w in \
      "$(cat "$HOME/.config/dusky/settings/dusky_theme/dark_wal" 2>/dev/null)" \
      "$(cat "$HOME/.config/dusky/settings/dusky_theme/current_fav" 2>/dev/null)" \
      "$HOME/Pictures/Wallpapers"/* \
      "$HOME/Pictures/wallpapers"/* \
      "$HOME/Pictures"/*.{png,jpg,jpeg}; do
      if [[ -f "$w" ]]; then
        WALLPAPER="$w"
        break
      fi
    done

    if [[ -n "$WALLPAPER" && -f "$WALLPAPER" ]]; then
      log_info "Generating initial Matugen skin from $WALLPAPER..."
      matugen --source-color-index 0 image "$WALLPAPER" >/dev/null 2>&1 || \
        matugen --prefer saturation image "$WALLPAPER" >/dev/null 2>&1 || true
    fi

    # Fallback to generating palette from signature slate color if wallpaper was not available
    if [[ ! -f "$DUSKYPORT_SKINS/skin.json" ]]; then
      log_info "Generating default Matugen theme from signature slate palette..."
      matugen color hex '#2d3136' >/dev/null 2>&1 || true
    fi

    # Final fallback: copy shipped default skin.json if generation was skipped
    if [[ ! -f "$DUSKYPORT_SKINS/skin.json" && -f "$SRC_ROOT/matugen/skin.json" ]]; then
      cp "$SRC_ROOT/matugen/skin.json" "$DUSKYPORT_SKINS/skin.json"
    fi

    if [[ -f "$DUSKYPORT_SKINS/skin.json" ]]; then
      log_ok "Matugen skin configured at ~/.config/duskyport/skins/matugen/skin.json"
    fi
  fi
fi

# Step 7: Install Desktop Entry and Icons
log_info "Installing desktop entry and icons..."
sudo install -Dm644 "$SRC_ROOT/packaging/linux/duskyport.desktop" "/usr/share/applications/duskyport.desktop"
mkdir -p "$HOME/.local/share/applications"
install -Dm644 "$SRC_ROOT/packaging/linux/duskyport.desktop" "$HOME/.local/share/applications/duskyport.desktop"

# Icons
if [[ -d "$SRC_ROOT/packaging/linux/icons" ]]; then
  for s in 16 32 48 64 128 256 512; do
    if [[ -f "$SRC_ROOT/packaging/linux/icons/${s}x${s}/apps/duskyport.png" ]]; then
      sudo install -Dm644 "$SRC_ROOT/packaging/linux/icons/${s}x${s}/apps/duskyport.png" "/usr/share/icons/hicolor/${s}x${s}/apps/duskyport.png"
    fi
  done
  if [[ -f "$SRC_ROOT/packaging/linux/icons/scalable/apps/duskyport.svg" ]]; then
    sudo install -Dm644 "$SRC_ROOT/packaging/linux/icons/scalable/apps/duskyport.svg" "/usr/share/icons/hicolor/scalable/apps/duskyport.svg"
  fi
elif [[ -f "$SRC_ROOT/client/logo.svg" ]]; then
  sudo install -Dm644 "$SRC_ROOT/client/logo.svg" "/usr/share/icons/hicolor/scalable/apps/duskyport.svg"
fi

sudo gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null || true
sudo update-desktop-database -q /usr/share/applications 2>/dev/null || true
update-desktop-database -q "$HOME/.local/share/applications" 2>/dev/null || true
log_ok "Desktop entry and icons registered."

# Step 8: Configure Hyprland Window Rules if requested
if [[ "$CONFIG_RULES" == "true" && -f "$SRC_ROOT/scripts/dusky-window-rule.sh" ]]; then
  log_info "Configuring Dusky/Hyprland window rules..."
  bash "$SRC_ROOT/scripts/dusky-window-rule.sh" install 2>/dev/null || true
  log_ok "Hyprland window rules applied."
fi

printf "\n"
printf "${GREEN}${BOLD}======================================================${RESET}\n"
printf "${GREEN}${BOLD}  Duskyport has been successfully installed!${RESET}\n"
printf "${GREEN}${BOLD}======================================================${RESET}\n\n"
printf "Launch it by running:  ${CYAN}${BOLD}duskyport${RESET}\n"
printf "CLI commands:          ${CYAN}${BOLD}duskyport caps${RESET} | ${CYAN}${BOLD}duskyport list${RESET} | ${CYAN}${BOLD}duskyssh list${RESET}\n"
printf "Or search for ${BOLD}Duskyport${RESET} in your application menu (Rofi/Wofi).\n\n"
