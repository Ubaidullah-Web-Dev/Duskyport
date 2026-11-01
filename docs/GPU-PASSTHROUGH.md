# GPU Passthrough & Looking Glass Integration

Duskyport includes an integrated, dedicated lane for **PCIe GPU Passthrough** and **Looking Glass B6** frame delivery.

---

## ⚡ What is Looking Glass?

[Looking Glass](https://looking-glass.io/) is an open-source application that allows the use of a KVM (Kernel-based Virtual Machine) configured for VGA PCI Passthrough without an attached physical monitor. It copies the guest frame buffer directly through shared host memory (`/dev/kvmfr0`), giving near-zero latency video stream delivery directly on your Linux desktop.

---

## 🚀 Engine Architecture (`duskyport-gpuvm`)

The `cmd/duskyport-gpuvm` engine provides automated domain generation, vCPU pinning, and process execution:

1. **Host Core Reservation**:
   - Analyzes available CPU cores and topology.
   - Automatically leaves Core 0 reserved for the Linux host OS and compositor, pinning guest vCPUs to remaining isolated cores to prevent audio stutter and frame drops.
2. **IVSHMEM Shared Memory Provisioning**:
   - Injects the proper `<qemu:commandline>` memory-backend-file referencing `/dev/kvmfr0`.
   - Computes required shared memory buffer based on display resolution (e.g., 32 MB for 1080p, 64 MB for 1440p, 128 MB for 4K).
3. **Automated Looking Glass Client Launch**:
   - On VM start, boots the domain via `virsh` and executes `looking-glass-client` with tuned flags.

---

## ⚙️ System Setup Checklist

### 1. Enable IOMMU
Add the relevant kernel parameter to your bootloader (e.g. `intel_iommu=on` or `amd_iommu=on`, and `iommu=pt`).

### 2. KVMFR Kernel Module
Install `kvmfr-dkms` or build the `kvmfr` module:

```bash
yay -S kvmfr-dkms
```

Configure module loading in `/etc/modules-load.d/kvmfr.conf`:
```text
kvmfr
```

Configure shared memory size in `/etc/modprobe.d/kvmfr.conf`:
```text
options kvmfr static_size_mb=64
```

Create udev rules in `/etc/udev/rules.d/99-kvmfr.rules`:
```text
SUBSYSTEM=="kvmfr", OWNER="root", GROUP="kvm", MODE="0660"
```

Add your user to the `kvm` group:
```bash
sudo usermod -aG kvm $USER
```
