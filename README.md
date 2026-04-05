# 🖥️ VPS Master Setup — Automated Ubuntu Desktop Server

<div align="center">

[![GitHub stars](https://img.shields.io/github/stars/technicalboy2023/vps-master-setup?style=for-the-badge&logo=github&color=FFD700)](https://github.com/technicalboy2023/vps-master-setup/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/technicalboy2023/vps-master-setup?style=for-the-badge&logo=github&color=4A90D9)](https://github.com/technicalboy2023/vps-master-setup/network)
[![GitHub issues](https://img.shields.io/github/issues/technicalboy2023/vps-master-setup?style=for-the-badge&logo=github&color=E74C3C)](https://github.com/technicalboy2023/vps-master-setup/issues)
[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
[![Version](https://img.shields.io/badge/Version-2.0.0-blue?style=for-the-badge)](https://github.com/technicalboy2023/vps-master-setup/releases)

[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04_LTS-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![XFCE](https://img.shields.io/badge/Desktop-XFCE4-2284F2?style=for-the-badge&logo=xfce&logoColor=white)](https://xfce.org/)
[![XRDP](https://img.shields.io/badge/RDP-XRDP-0078D4?style=for-the-badge&logo=windows&logoColor=white)](http://www.xrdp.org/)
[![Tailscale](https://img.shields.io/badge/VPN-Tailscale-242424?style=for-the-badge&logo=tailscale&logoColor=white)](https://tailscale.com/)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)

**🎯 Transform any bare Ubuntu 22.04 VPS into a secure, fully-featured remote desktop — in one command.**

*Production-grade · Open Source · Multi-Provider · ARM64 + amd64*

[✨ Features](#-key-features) • [🚀 Quick Start](#-one-command-installation) • [📋 Requirements](#-system-requirements) • [🔧 Customization](#-customization) • [🐛 Troubleshooting](#-troubleshooting)

</div>

---

## 🚀 Introduction

**VPS Master Setup v2.0** is a production-ready, single-script automation tool that converts a fresh Ubuntu 22.04 VPS into a **secure remote desktop environment** with zero manual configuration.

Whether you're a developer needing a persistent cloud workstation, a sysadmin managing remote infrastructure, or a power user running 24/7 automation — this script handles everything: desktop environment, RDP server, VPN, swap, firewall, browsers, and security hardening.

> 🔥 **No GitHub required.** Download once, run anywhere. Works on DigitalOcean, Linode, Vultr, Hetzner, OVH, Contabo, Oracle Cloud, AWS, GCP, Azure, and more.

---

## ✨ Key Features

### 🔒 Security — Hardened by Default
- UFW Firewall with SSH-only public access
- Fail2Ban intrusion prevention (brute-force protection)
- Root SSH login completely disabled
- RDP port 3389 blocked from public internet (Tailscale VPN only)
- SSH drop-in hardening (`/etc/ssh/sshd_config.d/`) — no config overwrite
- **Manual password prompt** — no hardcoded credentials, ever

### ⚡ Performance — Tuned for Low-End VPS
- **ZRAM** compressed RAM swap — dynamic size (2x RAM, 1–4GB range)
- Traditional swapfile fallback — also dynamically sized
- Kernel sysctl tuning (`swappiness`, `dirty_ratio`, `tcp_syncookies`)
- `vm.overcommit_memory=0` — safe heuristic (no OOM surprises)
- XRDP 24-bit color mode — 2x faster than 32-bit

### 🖥️ Complete Desktop
- Full **XFCE4** lightweight desktop environment
- XFCE4 Goodies — 40+ plugins pre-installed
- Thunar file manager, terminal, task manager, screenshot tool
- Black screen fix applied automatically

### 🌐 Modern Browsers
- **Firefox** from Mozilla's official APT repo (not Snap — no lag)
- **Google Chrome** stable (amd64) / **Chromium** (ARM64) — auto-detected
- GPU software rendering enabled for VPS compatibility

### 🛡️ Future-Proof & Multi-Architecture
- **amd64 + ARM64** architecture auto-detection
- Supports **all major VPS providers** — all mirror URLs normalized
- Ubuntu version check with graceful warnings
- Full setup log at `/var/log/vps-master-setup.log`
- Tailscale auth key support (`TS_AUTH_KEY`) for fully unattended deploys

### 🔁 Idempotent & Safe
- Re-runnable without duplicates or breaking existing setup
- Drop-in config files — never overwrites original system configs
- Every step has error handling and fallbacks

---

## 🛠️ Tech Stack

| Component | Technology |
|-----------|-----------|
| **OS** | Ubuntu 22.04 LTS |
| **Desktop** | XFCE4 + XFCE4-Goodies |
| **Remote Access** | XRDP + Tailscale VPN |
| **Firewall** | UFW + Fail2Ban |
| **Swap** | ZRAM + Traditional Swapfile (dynamic) |
| **Browsers** | Firefox (Mozilla) + Chrome / Chromium |
| **Script** | Bash (POSIX-safe, `set -euo pipefail`) |
| **Arch** | amd64 (x86_64) + ARM64 |

---

## 📋 System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **OS** | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS (fresh) |
| **CPU** | 1 Core | 2+ Cores |
| **RAM** | 1 GB | 2–4 GB |
| **Storage** | 15 GB | 30+ GB |
| **Architecture** | amd64 or ARM64 | amd64 |
| **Network** | Any | 10+ Mbps |

### ✅ Tested VPS Providers
`DigitalOcean` · `Linode (Akamai)` · `Vultr` · `Hetzner` · `OVH` · `Contabo` · `Oracle Cloud` · `AWS EC2` · `GCP` · `Azure`

---

## 📦 One-Command Installation

### ⚡ Quick Install (Recommended)

```bash
# Step 1 — Install tmux (keeps session alive if SSH drops)
apt install tmux -y && tmux new -s vps-setup

# Step 2 — Run the installer
curl -fsSL https://raw.githubusercontent.com/technicalboy2023/vps-master-setup/main/install.sh | sudo bash
```

> 💡 **Why tmux?** If your SSH connection drops mid-install, `tmux attach -t vps-setup` reconnects you to the running session.

---

### 📥 Manual Install (Inspect Before Running)

```bash
# Download the script
wget https://raw.githubusercontent.com/technicalboy2023/vps-master-setup/main/install.sh

# Review it first (recommended)
cat install.sh

# Run it
sudo bash install.sh
```

---

### 🤖 Unattended Install (CI / Automation)

```bash
# Set your Tailscale auth key — no browser auth needed
export TS_AUTH_KEY="tskey-auth-xxxxxxxxxxxx"

curl -fsSL https://raw.githubusercontent.com/technicalboy2023/vps-master-setup/main/install.sh | sudo -E bash
```

> Get your auth key at: [login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys)

---

## ⚙️ Usage

### 1. Run the Script

During setup, you'll be prompted to set a password for user `aman`:

```
[6/14] Creating admin user: aman

  Enter password for user 'aman': ████████   (hidden input)
  Confirm password:               ████████   (hidden input)

[INFO] User 'aman' created.
[INFO] Password set successfully.
```

Password rules enforced:
- Minimum 8 characters
- Must be confirmed (re-typed)
- Empty password rejected

### 2. Authenticate Tailscale

When the script reaches step 14, it prints a URL:

```
========================================================
  ACTION REQUIRED: Authenticate Tailscale
  Open the URL below in your browser:
========================================================

To authenticate, visit:
        https://login.tailscale.com/a/xxxxxxxxxxxxxxx

========================================================
```

Open this URL on your phone or laptop to authorize the VPS on your Tailscale network.

### 3. Get Your Tailscale IP

```bash
tailscale ip -4
```

### 4. Connect via RDP

```
Host     : <tailscale-ip>:3389
Username : aman
Password : (what you entered during setup)
```

### 5. Reboot

```bash
reboot
```

> ⚠️ A reboot is required to load the updated kernel and activate all swap/sysctl settings.

---

## 🖥️ Connecting via RDP

<details>
<summary><b>🪟 Windows — Remote Desktop Connection</b></summary>

1. Press `Win + R` → type `mstsc` → Enter
2. Enter: `<tailscale-ip>:3389`
3. Username: `aman`
4. Password: (your setup password)

</details>

<details>
<summary><b>🍎 macOS — Microsoft Remote Desktop</b></summary>

1. Install [Microsoft Remote Desktop](https://apps.apple.com/app/microsoft-remote-desktop/id1295203466) from App Store
2. Add PC → `<tailscale-ip>:3389`
3. Username: `aman`, Password: (your setup password)

</details>

<details>
<summary><b>🐧 Linux — Remmina or xfreerdp</b></summary>

```bash
# Install Remmina
sudo apt install remmina -y

# Or use xfreerdp directly
xfreerdp /v:<tailscale-ip> /u:aman /p:yourpassword /dynamic-resolution
```

</details>

<details>
<summary><b>📱 Mobile — iOS / Android</b></summary>

1. Install **Microsoft Remote Desktop** from App Store / Play Store
2. Add PC → Tailscale IP → Connect

</details>

---

## 📁 What Gets Installed

<details>
<summary><b>📦 Full Package List</b></summary>

**Desktop Environment**
- `xfce4` — Core XFCE4 desktop
- `xfce4-goodies` — 40+ plugins
- `xfce4-session` — Session manager
- `xfce4-terminal` — Terminal emulator
- `thunar` — File manager
- `mousepad` — Text editor
- `xfce4-taskmanager` — Task manager
- `xfce4-screenshooter` — Screenshot tool

**Remote Desktop**
- `xrdp` — RDP server
- `ssl-cert` — SSL certificates

**Browsers**
- `firefox` — Mozilla official APT repo (non-Snap)
- `google-chrome-stable` — Latest Chrome (amd64)
- `chromium-browser` — Fallback for ARM64

**Security**
- `ufw` — Uncomplicated Firewall
- `fail2ban` — Intrusion prevention
- SSH hardening via drop-in config

**VPN**
- `tailscale` — Zero-config VPN

**Swap & Memory**
- ZRAM — Compressed RAM swap (dynamic)
- Swapfile — Traditional disk swap (dynamic)
- Custom sysctl tuning

**Utilities**
- `curl`, `wget`, `git`, `nano`, `htop`
- `tmux`, `net-tools`, `openssl`
- `network-manager-gnome`

</details>

---

## 📊 What the Script Does — Step by Step

```
[1/14]  Set timezone → Asia/Kolkata
[2/14]  Fix APT mirrors → archive.ubuntu.com (all providers)
[3/14]  System update → apt update + upgrade
[4/14]  Install base packages
[5/14]  Configure UFW firewall
[6/14]  Create user 'aman' (manual password prompt)
[7/14]  SSH hardening (drop-in config, no overwrite)
[8/14]  Install XFCE4 desktop + black screen fix
[9/14]  Install XRDP + block port 3389 publicly
[10/14] Configure ZRAM + swapfile (dynamic sizing)
[11/14] Apply kernel/sysctl optimizations
[12/14] Enable software rendering (/etc/environment)
[13/14] Install Firefox + Chrome/Chromium
[14/14] Install + authenticate Tailscale
```

---

## 🔧 Customization

### 👤 Change Default Username

Edit the script — replace all occurrences of `aman` with your preferred username:

```bash
sed -i 's/aman/yourname/g' install.sh
sudo bash install.sh
```

### 🌍 Change Timezone

```bash
# Edit line ~68 in install.sh
timedatectl set-timezone America/New_York
# Full list: timedatectl list-timezones
```

### 💾 Override Swap Size

The script auto-calculates swap as `2 × RAM (capped 1–4GB)`. To override:

```bash
# Edit install.sh — replace the auto-calc lines with:
SWAP_MB=4096   # 4GB fixed
SWAP_BYTES=$(( SWAP_MB * 1024 * 1024 ))
```

### 🎨 XRDP Color Depth

```bash
# In install.sh, change the sed line:
sed -i 's/max_bpp=32/max_bpp=16/' /etc/xrdp/xrdp.ini   # Fastest
sed -i 's/max_bpp=32/max_bpp=24/' /etc/xrdp/xrdp.ini   # Balanced (default)
```

---

## 🔍 Check Setup Logs

```bash
# Full log
cat /var/log/vps-master-setup.log

# Page-by-page
less /var/log/vps-master-setup.log

# Only errors/warnings
grep -E "ERROR|WARN|FAIL" /var/log/vps-master-setup.log

# Only success messages
grep "INFO" /var/log/vps-master-setup.log
```

---

## 🐛 Troubleshooting

<details>
<summary><b>❌ Black screen after RDP login</b></summary>

```bash
# SSH into VPS and run:
sudo apt install xfce4-session -y
echo "startxfce4" > /home/aman/.xsession
chown aman:aman /home/aman/.xsession
sudo systemctl restart xrdp
```

Then reconnect via RDP.
</details>

<details>
<summary><b>🔌 Can't connect to RDP</b></summary>

```bash
# Check XRDP status
sudo systemctl status xrdp

# Restart XRDP
sudo systemctl restart xrdp

# Verify Tailscale is connected
tailscale status
tailscale ip -4

# Check firewall — 3389 must be DENY publicly
sudo ufw status
```
</details>

<details>
<summary><b>💾 Low memory / OOM errors</b></summary>

```bash
# Check current swap usage
free -h
swapon --show

# Manually enable if needed
sudo swapon /swapfile
sudo swapon /dev/zram0
```
</details>

<details>
<summary><b>🌐 Tailscale authentication stuck</b></summary>

```bash
# Run tailscale up manually — you'll see the auth URL
sudo tailscale up

# Check status
tailscale status
tailscale ip -4
```
</details>

<details>
<summary><b>🔑 Forgot the aman user password</b></summary>

```bash
# Reset password as root
sudo passwd aman
```
</details>

<details>
<summary><b>🦊 Firefox not opening in RDP session</b></summary>

```bash
# Software rendering is already set, but verify:
grep LIBGL /etc/environment
# Should show: LIBGL_ALWAYS_SOFTWARE=1

# Re-login to RDP session after checking
```
</details>

---

## 🔒 Security Best Practices

### After First Login — Do These Immediately

```bash
# 1. Set up SSH key authentication
ssh-copy-id aman@<tailscale-ip>

# 2. Disable password SSH (after keys are set up)
sudo nano /etc/ssh/sshd_config
# Add: PasswordAuthentication no
sudo systemctl restart ssh

# 3. Enable automatic security updates
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure -plow unattended-upgrades

# 4. Monitor Fail2Ban
sudo fail2ban-client status sshd
```

---

## 📊 Performance Benchmarks

Tested on **2GB RAM / 1 vCPU** (DigitalOcean Droplet $12/mo):

| Metric | Value |
|--------|-------|
| **Idle RAM** | ~380MB |
| **With Firefox** | ~650MB |
| **With Chrome** | ~820MB |
| **ZRAM Swap** | 3.9GB compressed |
| **Disk Swap** | 3.9GB traditional |
| **SSH Login** | < 1 second (UseDNS off) |
| **RDP Response** | < 100ms (LAN / Tailscale) |
| **Setup Time** | 12–18 minutes |

---

## ❓ FAQ

<details>
<summary><b>Can I run this on Debian / CentOS / other distros?</b></summary>

No. Currently Ubuntu 22.04 LTS only. Debian support is on the roadmap.
</details>

<details>
<summary><b>Does it work on ARM64 (Oracle Cloud free tier)?</b></summary>

Yes! The script auto-detects architecture. On ARM64, Chrome is replaced with Chromium automatically.
</details>

<details>
<summary><b>Can I access RDP without Tailscale?</b></summary>

Not by default — port 3389 is blocked for security. To allow public RDP (not recommended):
```bash
sudo ufw allow 3389/tcp
```
</details>

<details>
<summary><b>Is it safe to run on a non-fresh VPS?</b></summary>

Yes — the script is idempotent. It won't duplicate users, swap, or configs. However, fresh VPS is always recommended.
</details>

<details>
<summary><b>How do I update to v2.0 from v1.0?</b></summary>

Just re-run the v2.0 script. It will skip existing user/swap creation and apply only missing configs.
</details>

---

## 🤝 Contributing

Contributions are welcome! Here's how:

1. 🍴 **Fork** this repository
2. 🌿 Create a feature branch: `git checkout -b feature/your-feature`
3. ✍️ Commit your changes: `git commit -m 'Add: your feature description'`
4. 📤 Push to branch: `git push origin feature/your-feature`
5. 🎉 Open a **Pull Request**

### 💡 Good First Contributions
- Ubuntu 24.04 LTS support
- GNOME / KDE desktop option flag
- Docker pre-installation flag
- VNC as alternative to XRDP
- `--minimal` flag (no browsers, no GUI)
- Debian 12 support

---

## 📝 Changelog

### v2.0.0 — Major Security & Stability Release
- ✅ **FIXED:** Hardcoded password replaced with interactive secure prompt
- ✅ **FIXED:** Tailscale auth URL was hidden (`/dev/null`) — now visible
- ✅ **FIXED:** Systemd ZRAM service had multiple `ExecStart` (broken) — now single combined command
- ✅ **FIXED:** `/etc/environment` had invalid `export` keyword removed
- ✅ **FIXED:** Mirror fix now covers all providers (not just Linode)
- ✅ **FIXED:** Swap size is now dynamic (2× RAM) instead of hardcoded 2GB
- ✅ **FIXED:** `zram-config` package conflict with manual ZRAM setup — removed
- ✅ **FIXED:** `vm.overcommit_memory` set to safe `0` (was dangerous `1`)
- ✅ **FIXED:** Chrome hardcoded to amd64 — ARM64 now uses Chromium
- ✅ **NEW:** Ubuntu version check with graceful warnings
- ✅ **NEW:** Full setup log at `/var/log/vps-master-setup.log`
- ✅ **NEW:** `TS_AUTH_KEY` env var for unattended Tailscale auth
- ✅ **NEW:** `network-manager-gnome` now actually installed
- ✅ **NEW:** Dedicated sysctl config in `/etc/sysctl.d/99-vps-tuning.conf`
- ✅ **REMOVED:** Deprecated SSH `Compression yes` setting
- ✅ **REMOVED:** Duplicate `htop` install

### v1.0.0 — Initial Release
- Ubuntu 22.04 + XFCE4 + XRDP + Tailscale + ZRAM

---

## 📄 License

```
MIT License — Free to use, modify, and distribute with attribution.
```

See [LICENSE](LICENSE) for full text.

---

## 👨‍💻 Author

**Aman** — DevOps Engineer & Infrastructure Automation Enthusiast

- 🐙 GitHub: [@technicalboy2023](https://github.com/technicalboy2023)
- 🌐 Website: [GyaniBaba](https://technicalboy2023.github.io/gyaniguru)

---

## ⭐ Support This Project

If **VPS Master Setup** saved you hours of manual configuration:

- ⭐ **Star** this repository
- 🍴 **Fork** and customize for your workflow
- 🐛 **Report issues** — help make it better
- 💡 **Suggest features** via GitHub Issues
- 📢 **Share** with your DevOps community

<div align="center">

**Give a ⭐ if this saved your time!**

[![GitHub Repo stars](https://img.shields.io/github/stars/technicalboy2023/vps-master-setup?style=social)](https://github.com/technicalboy2023/vps-master-setup/stargazers)
[![GitHub followers](https://img.shields.io/github/followers/technicalboy2023?style=social)](https://github.com/technicalboy2023)

---

*Built with ❤️ for the DevOps & self-hosting community*

*Tested on Ubuntu 22.04 LTS · Deployed across DigitalOcean, Linode, Vultr, Hetzner, Oracle Cloud*

**[⬆ Back to Top](#️-vps-master-setup--automated-ubuntu-desktop-server)**

</div>
