<div align="center">

# 🚢 Duskyport

**A native desktop fleet dashboard, virtual machine manager, and remote server harbour for Dusky OS & Arch Linux.**

<br />

[![CI](https://github.com/Ubaidullah-Web-Dev/duskyport/actions/workflows/ci.yml/badge.svg)](https://github.com/Ubaidullah-Web-Dev/duskyport/actions/workflows/ci.yml)
[![Release](https://github.com/Ubaidullah-Web-Dev/duskyport/actions/workflows/release.yml/badge.svg)](https://github.com/Ubaidullah-Web-Dev/duskyport/actions/workflows/release.yml)
[![License](https://img.shields.io/badge/license-GPL--3.0-blue?style=flat-square)](https://github.com/Ubaidullah-Web-Dev/duskyport)
<img alt="Linux x86_64" src="https://img.shields.io/badge/platform-Arch%20%7C%20Dusky%20Linux-8996a8?style=flat-square&logo=arch-linux&logoColor=white">
<img alt="Go" src="https://img.shields.io/badge/engines-Go-2d3136?style=flat-square&logo=go&logoColor=white">
<img alt="Quickshell / QML" src="https://img.shields.io/badge/UI-Quickshell%20%2F%20QML-2d3136?style=flat-square">

<br /><br />

### 🚀 One-Line Installation

Run this single command in your terminal to automatically install Duskyport and configure all dependencies:

```bash
curl -sSL https://raw.githubusercontent.com/Ubaidullah-Web-Dev/Duskyport/main/install.sh | bash
```

To uninstall at any time:
```bash
curl -sSL https://raw.githubusercontent.com/Ubaidullah-Web-Dev/Duskyport/main/install.sh | bash -s -- --uninstall
```

</div>

<br />

---

## ⚡ What is Duskyport?

**Duskyport** is the harbour for every machine you command: the local iron in the yard, the GPU-passthrough rigs, and the distant servers reached over SSH.

The primary interface is written in pure **Quickshell / QML**, connected to fast, standalone Go helper engines (`duskyport-fetch`, `duskyport-mon`, `duskyssh`, `duskyport-gpuvm`).

---

## 🌟 Key Capabilities

### 1. 🖥️ Local Virtual Machines
- **Quickget / Quickemu Engine**: Auto-downloads and runs ~1,000 OS releases (Ubuntu, Fedora, Windows, macOS, Arch, Alpine, etc.) with tuned defaults.
- **Instant Cloud Machines**: Boots curated prebuilt cloud-init images (Ubuntu, Debian, Fedora, Arch, Alpine, Rocky) with a baked `dusky` user and authorized SSH keys.
- **Custom ISO Importer**: Import and provision VMs from any custom OS ISO.
- **Live Snapshots & Management**: QCOW2 live snapshot creation, rollback, disk resizing, CPU core pinning, memory ballooning, USB device passthrough, and port forwards.
- **Monitoring & Metrics**: Live CPU, memory RSS, disk I/O, network I/O, and guest agent status (`duskyport-mon`).

### 2. 🎮 GPU Passthrough & Looking Glass
- Dedicated Looking Glass GPU passthrough lane for near-native virtualized gaming and workstation workloads.
- Automated CPU vCPU core pinning and host core reservation.
- Low-latency visual frame buffer delivery via `/dev/kvmfr0`.

### 3. 🌐 Remote Fleet & SSH
- **Unified SSH Config**: Parses and manages `~/.ssh/config` and clean sidecar metadata without rewriting user configuration.
- **Real-Time Health Probes**: Agentless `/proc` health sampling over SSH (CPU load, memory usage, disk allocation, network rates).
- **Proxmox VE (PVE) Integration**: Connects via API tokens to monitor clusters, nodes, LXC containers, and QEMU guests with start/stop/shutdown controls.
- **SSH Tunnels**: Open, inspect, and manage tracked background SSH port forwards.

### 4. 📟 Serial & Network Consoles
- First-party berths for serial cables (`picocom`), legacy telnet (`inetutils`), Windows RDP (`freerdp`), and VNC (`tigervnc`).
- Secure credentials storage in system login keyring via Secret Service.

### 5. 🎨 Dynamic Material 3 Theming
- Live palette adaptation via **Matugen**. Whenever the wallpaper or theme switches, Duskyport's interface automatically updates its tokens and accent colors in real time.

---

## 📦 Installation & Usage

### 1. Automatic One-Line Install (Recommended)

```bash
curl -sSL https://raw.githubusercontent.com/Ubaidullah-Web-Dev/Duskyport/main/install.sh | bash
```

To uninstall at any time:
```bash
curl -sSL https://raw.githubusercontent.com/Ubaidullah-Web-Dev/Duskyport/main/install.sh | bash -s -- --uninstall
```

The interactive installer will:
- Install required system packages (`quickshell`, `openssl`, `librsvg`, `xdg-utils`, etc.)
- Offer to install recommended VM clients (`quickemu`, `spice-gtk`, `libisoburn`, `picocom`, `freerdp`, `tigervnc`)
- Register the QML design runtime (`Dusky.Ui`)
- Compile and install helper binaries to `/usr/bin/`
- Register the desktop launcher and high-resolution icons
- Configure the Matugen Material 3 dynamic theming template

### 2. Manual Installation from Source

```bash
git clone https://github.com/Ubaidullah-Web-Dev/duskyport.git
cd duskyport
./install.sh
```

---

## 🛠️ CLI Usage

Duskyport provides full scriptable CLI control:

```bash
# Launch the graphical dashboard
duskyport

# Query host virtualization readiness
duskyport caps

# List local virtual machines
duskyport list

# Instant cloud-init disposable VM
duskyport instant alpine my-test-box --disposable

# List remote SSH hosts
duskyssh list

# Probe live health across all remote servers
duskyssh probeall

# Open a serial or RDP console
duskyssh console open <id>
```

---

## 👤 Author & Credits

- **Maintained & Packaged by**: [Ubaid](https://github.com/Ubaidullah-Web-Dev)
- **GitHub**: [https://github.com/Ubaidullah-Web-Dev/duskyport](https://github.com/Ubaidullah-Web-Dev/duskyport)
- Licensed under the **GNU General Public License v3.0**.
