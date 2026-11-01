# Remote Fleet & SSH Management

Duskyport's `duskyssh` engine turns your desktop into a unified mission control harbour for remote servers, cloud VPS instances, Proxmox VE hypervisors, and serial consoles.

---

## 🌐 Features

### 1. Zero-Friction SSH Config Integration
`duskyssh` directly parses your existing `~/.ssh/config`. Any host configured in your SSH client is immediately browsable and launchable from Duskyport without duplicating configurations or passwords.

### 2. Agentless `/proc` Health Sampling
Instead of requiring invasive monitoring daemons (like node_exporter or Datadog) on every remote box, Duskyport connects over a lightweight SSH subchannel to read `/proc/stat`, `/proc/meminfo`, `/proc/loadavg`, and `/proc/net/dev`.
- Real-time CPU utilization %
- Live memory usage (Used / Free / Buffers / Cached)
- Disk space utilization
- Network TX/RX throughput

### 3. Proxmox VE (PVE) API Integration
Connect to home labs and production Proxmox clusters:
- Provide your cluster URL and PVE API token (`PVEAPIToken=USER@REALM!TOKENID=UUID`).
- View all cluster nodes, LXC containers, and QEMU VMs.
- Send ACPI poweroff, reboot, and start commands right from the dashboard.

### 4. Background SSH Tunnels
Create and track persistent local/remote port forwardings:
- Forward remote database ports (e.g. `localhost:5432` -> `remote:5432`)
- Monitor tunnel process status and kill or re-establish connections with a click.

### 5. Console Berths & Secure Keyrings
- **Serial**: Connect to network switches, microcontrollers, and serial terminals using `picocom`.
- **RDP & VNC**: Launch `xfreerdp` and `tigervnc` with hardware acceleration.
- **Keyring Storage**: Securely saves passwords using the FreeDesktop Secret Service API (KWallet, GNOME Keyring, or KeePassXC).
