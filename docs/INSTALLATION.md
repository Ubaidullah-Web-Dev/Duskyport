# Duskyport Installation Guide

This guide covers installing Duskyport on **Arch Linux** and **Dusky OS**.

---

## 🚀 Quick Install (Recommended)

Run the single-command automated installer:

```bash
curl -sSL https://raw.githubusercontent.com/Ubaidullah-Web-Dev/Duskyport/main/install.sh | bash
```

The script will prompt you to:
1. Install core system packages (`quickshell`, `matugen`, `openssl`, etc.) via `pacman`.
2. Install optional hypervisor and console utilities (`quickemu`, `looking-glass`, `picocom`, `freerdp`, `tigervnc`) via `pacman` and `yay`/`paru`.
3. Register the Matugen dynamic theme template and immediately generate palette tokens from your wallpaper.
4. Add the Hyprland floating window rule so Duskyport opens cleanly centered.

For non-interactive or automated setups, pass `-y`:

```bash
curl -sSL https://raw.githubusercontent.com/Ubaidullah-Web-Dev/Duskyport/main/install.sh | bash -s -- -y
```

---

## 🛠️ Manual Installation from Source

### 1. Install Prerequisites

Ensure the required dependencies are installed:

```bash
# Core requirements
sudo pacman -S --needed quickshell matugen openssl librsvg desktop-file-utils hicolor-icon-theme xdg-utils polkit jq

# Optional recommended VM and console berths
sudo pacman -S --needed qemu-desktop spice-gtk libisoburn picocom inetutils freerdp tigervnc

# AUR helpers for automated OS images & Looking Glass
yay -S --needed quickemu looking-glass
```

### 2. Clone the Repository

```bash
git clone https://github.com/Ubaidullah-Web-Dev/Duskyport.git
cd Duskyport
```

### 3. Run the Local Installer

```bash
chmod +x install.sh
./install.sh
```

---

## 📦 Arch Linux PKGBUILD

You can build and install Duskyport using `makepkg`:

```bash
cd packaging/arch
makepkg -si
```

---

## 🗑️ Uninstallation

Duskyport includes a clean and safe uninstallation mode:

```bash
# Interactive uninstaller
./install.sh --uninstall
# or directly via curl:
curl -sSL https://raw.githubusercontent.com/Ubaidullah-Web-Dev/Duskyport/main/install.sh | bash -s -- --uninstall

# Non-interactive uninstall (removes binaries, desktop entries, reverts matugen & window rules)
./install.sh --uninstall -y

# Full purge (also cleans ~/.config/duskyport and optional dependencies)
./install.sh --uninstall -y --purge
```

The uninstaller:
- Removes all binaries and desktop launchers from `/usr/bin/` and `/usr/share/`.
- Preserves shared components (`Dusky.Ui`) if Duskytunes is installed.
- Safely strips the `[templates.duskyport]` block from `~/.config/matugen/config.toml` without touching any of your other themes or configs.
- Reverts the Hyprland floating window rule from `~/.config/hypr/user.lua` and reloads `hyprctl`.
- Optionally cleans up unused VM dependencies if confirmed.

---

## 🧪 Verification

After installation, verify that Duskyport's CLI and hypervisor engines are ready:

```bash
# Verify host virtualization capabilities
duskyport caps

# List remote SSH hosts
duskyssh list

# Launch graphical dashboard
duskyport
```
