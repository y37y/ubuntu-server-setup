---

# NVIDIA + Kernel Upgrade Guide (Future-Proof)

This document explains how to keep **Ubuntu 24.04 LTS** stable with an NVIDIA GPU (RTX 4090).
It covers daily updates, driver/kernel upgrades, and recovery if something breaks.

---

## 1. Daily Safe Updates

```bash
sudo apt update && sudo apt upgrade
```

* **Safe:** Kernel + NVIDIA driver are held (pinned).
* Keeps packages, apps, and security fixes up to date.

---

## 2. Check Current Versions

Before upgrades, always note current working versions:

```bash
uname -r          # current kernel
nvidia-smi        # current driver
apt-mark showhold # packages on hold
```

---

## 3. When You Want to Upgrade Kernel + NVIDIA

1. **Unhold pinned packages**

```bash
sudo apt-mark unhold 'nvidia-driver-*' linux-image-generic linux-headers-generic
```

*(This unholds all NVIDIA drivers, not just 535, so you don’t have to edit later.)*

2. **Update everything**

```bash
sudo apt update && sudo apt full-upgrade
```

3. **Reboot into new kernel**

```bash
sudo reboot
```

4. **Verify**

```bash
uname -r
nvidia-smi
```

5. **Re-hold packages**

```bash
sudo apt-mark hold 'nvidia-driver-*' linux-image-generic linux-headers-generic
```

---

## 4. Locking Exact Kernel Version (Optional, for max stability)

If you want to **freeze kernel version exactly** (e.g., `6.14.0-33-generic`):

```bash
sudo apt-mark hold linux-image-6.14.0-33-generic linux-headers-6.14.0-33-generic
```

This guarantees upgrades won’t move past that kernel.
Update manually only when you decide it’s safe.

---

## 5. Recovery Steps

If GUI won’t start (stuck at GDM/SDDM/plymouth):

1. Boot into previous kernel from **GRUB → Advanced Options**.
2. Purge broken driver:

```bash
sudo apt purge 'nvidia-driver-*'
```

3. Reinstall a known good version (example: 535):

```bash
sudo apt install nvidia-driver-535
```

4. Reboot and check:

```bash
nvidia-smi
```

---

## 6. Tips

* **Check NVIDIA website** for latest recommended driver for RTX 4090 + Ubuntu LTS.
* **DKMS** auto-rebuilds NVIDIA modules on kernel upgrade — but sometimes fails → recovery steps above.
* Always keep **SSH enabled** so you can recover if GUI fails.
* Consider **Kubuntu / Plasma** (SDDM) for more stable experience with NVIDIA vs GDM.

---
