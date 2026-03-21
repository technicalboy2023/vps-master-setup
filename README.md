# 🖥️ VPS Master Setup Script

> **One-shot automated VPS provisioning** — Transform a bare Ubuntu 22.04 server into a fully configured, secure, remote-accessible desktop environment in minutes.

[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04_LTS-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Bash](https://img.shields.io/badge/Bash-Script-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![XRDP](https://img.shields.io/badge/Remote_Desktop-XRDP-0078D4?style=for-the-badge&logo=windows&logoColor=white)](http://www.xrdp.org/)
[![Tailscale](https://img.shields.io/badge/VPN-Tailscale-242424?style=for-the-badge&logo=tailscale&logoColor=white)](https://tailscale.com/)

---

## 📖 Description

**VPS Master Setup** is a fully automated Bash script that provisions a production-ready Ubuntu 22.04 VPS from scratch. It installs and configures a complete **XFCE graphical desktop**, remote desktop access via **XRDP**, a secure **Tailscale VPN** tunnel, hardened **firewall rules**, performance-tuned **kernel parameters**, and production browsers — all in a single run.

Ideal for developers and sysadmins who need a **persistent cloud desktop** for browsing, automation, or running GUI applications on a remote server — securely accessible from anywhere via Tailscale, without exposing RDP to the public internet.

---

## ✨ Features

| Category | Details |
|---|---|
| 🔒 **Security** | UFW firewall, Fail2Ban IDS, root SSH disabled, RDP port blocked publicly |
| 🖥️ **Desktop** | Full XFCE4 desktop environment with goodies |
| 🌐 **Remote Access** | XRDP with black-screen fix, accessible privately over Tailscale VPN |
| 🚀 **Performance** | 2 GB swap file, kernel-level RAM/disk I/O optimizations, 24-bit color for RDP |
| 🦊 **Browsers** | Firefox (Mozilla official repo, not Snap) + Google Chrome stable |
| 🕸️ **VPN** | Tailscale installed, enabled, and launched automatically |
| 🛡️ **Hardening** | SSH compression enabled, DNS lookup disabled, Fail2Ban active |
| 🕐 **Timezone** | Set to `Asia/Kolkata` (IST) automatically |
| 🔄 **Idempotent** | Safe to re-run — existing users and swap files are not duplicated |
| 📦 **Dependencies** | All required packages installed and configured in one pass |

---

## 🧰 Requirements

- **OS:** Ubuntu 22.04 LTS (fresh install recommended)
- **Access:** Root or `sudo` privileges
- **Architecture:** `amd64` (x86_64)
- **RAM:** Minimum 1 GB (2 GB+ recommended for desktop use)
- **Disk:** Minimum 10 GB free space
- **Network:** Internet access from the VPS

> ⚠️ **Tailscale requires manual authentication.** After `tailscale up` runs, the script will pause and print a login URL. Open it in a browser to authorize the VPS on your Tailscale network.

---

## 📂 File Structure

```
vps-setup/
├── setup.sh          # The main setup script (this file)
└── README.md         # Documentation
```

The script creates and modifies the following system paths:

```
/etc/apt/sources.list            # Mirror fix (Linode → Ubuntu)
/etc/apt/sources.list.d/         # Mozilla and Chrome repos added
/etc/apt/keyrings/               # GPG keys for Mozilla and Chrome
/etc/apt/preferences.d/mozilla   # Pin Firefox to Mozilla repo
/etc/ssh/sshd_config.d/          # SSH hardening config
/etc/sysctl.conf                 # Kernel performance parameters
/etc/environment                 # LIBGL software rendering enabled
/etc/fstab                       # Swap entry added
/etc/xrdp/xrdp.ini               # XRDP color depth reduced to 24-bit
/swapfile                        # 2 GB swap file
/home/aman/                      # Admin user home directory
/home/aman/.xsession             # XFCE session launcher for RDP
/etc/skel/.xsession              # XFCE session default (black screen fix)
```

---

## 🚀 Installation & Usage

### Step 1 — Upload the script to your VPS

```bash
# Option A: Clone the repo
git clone https://github.com/technicalboy2023/vps-master-setup.git
cd vps-master-setup

# Option B: Download directly
wget https://raw.githubusercontent.com/technicalboy2023/vps-master-setup/main/setup.sh
```

### Step 2 — Make it executable

```bash
chmod +x setup.sh
```

### Step 3 — Run as root

```bash
sudo bash setup.sh
```

> 💡 **Tip:** Run inside a `tmux` or `screen` session so the script survives SSH disconnects:
> ```bash
> sudo apt install tmux -y && tmux new -s setup
> sudo bash setup.sh
> ```

### Step 4 — Authorize Tailscale

When the script runs `tailscale up`, it will output a URL like:

```
To authenticate, visit:
  https://login.tailscale.com/a/xxxxxxxxxxxxxx
```

Open that URL on your phone or laptop to authorize the VPS.

### Step 5 — Connect via Remote Desktop

Once the script completes:

1. Find your VPS's **Tailscale IP** from [https://login.tailscale.com/admin/machines](https://login.tailscale.com/admin/machines)
2. Open **Microsoft Remote Desktop** (Windows/macOS/iOS/Android)
3. Add a new connection with:
   - **PC Name:** `<tailscale-ip>:3389`
   - **Username:** `aman`
   - **Password:** `password` *(change this — see Customization)*
4. Connect — the XFCE desktop will load

---

## ⚙️ How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                       setup.sh execution flow                   │
├─────────────────────────────────────────────────────────────────┤
│  1. Root check → Timezone (IST) → Fix apt mirror                │
│  2. System update → Install base packages (curl, git, ufw...)   │
│  3. Fail2Ban enabled → UFW configured (SSH allowed only)        │
│  4. User "aman" created → added to sudo group                   │
│  5. Root SSH login disabled via sshd_config.d drop-in           │
│  6. XFCE4 desktop + goodies installed                           │
│  7. XRDP installed, enabled → black screen fix applied          │
│  8. RDP port 3389 BLOCKED publicly via UFW                      │
│  9. 2 GB swapfile created → added to /etc/fstab                 │
│ 10. Kernel params tuned (swappiness, dirty ratio, overcommit)   │
│ 11. XRDP optimized (24-bit color) → software rendering enabled  │
│ 12. Snap Firefox removed → Mozilla repo Firefox installed       │
│ 13. Google Chrome stable installed from official repo           │
│ 14. Tailscale installed, started → tailscale up triggered       │
└─────────────────────────────────────────────────────────────────┘
```

**Why Tailscale for RDP?**
Rather than exposing port 3389 to the internet (a massive attack surface), the script blocks RDP publicly and routes all remote desktop traffic through Tailscale's encrypted WireGuard tunnel. This means your desktop is reachable only from your personal Tailscale network.

---

## 🔧 Customization Options

| Setting | Location in Script | How to Change |
|---|---|---|
| **Admin username** | `useradd -m -s /bin/bash aman` | Replace `aman` with your preferred username |
| **Admin password** | `echo "aman:password"` | Replace `password` with a strong password |
| **Swap size** | `fallocate -l 2G /swapfile` | Change `2G` to `4G`, `8G`, etc. |
| **Timezone** | `timedatectl set-timezone Asia/Kolkata` | Use any valid TZ (e.g., `America/New_York`) |
| **RDP color depth** | `max_bpp=24` in xrdp.ini | Change to `16` for speed or `32` for quality |
| **Swappiness** | `vm.swappiness=10` | Lower (0–10) = prefer RAM; higher = use swap more |
| **APT mirror** | `archive.ubuntu.com` | Change to a mirror closer to your VPS region |

---

## 🔐 Security Notes

> Please review these carefully before deploying to production.

- **🚨 Change the default password immediately** — `aman:password` is set for initial access only. Run `passwd aman` after first login.
- **🔒 RDP is NOT exposed publicly** — Port 3389 is blocked by UFW. Access is only possible through Tailscale VPN.
- **🛡️ Root login is disabled** — SSH `PermitRootLogin no` is enforced via a drop-in config file.
- **🤖 Fail2Ban is active** — Protects against SSH brute-force attacks out of the box.
- **🔑 Consider SSH key auth** — For additional security, add your public key to `/home/aman/.ssh/authorized_keys` and disable password auth (`PasswordAuthentication no`).
- **🌐 Tailscale uses WireGuard** — All RDP traffic is end-to-end encrypted in transit.
- **🦊 Firefox is pinned** — Installed from Mozilla's official APT repo with a pin priority of 1000, preventing Snap from overriding it.

---

## 🐛 Troubleshooting

**Black screen after RDP login?**
The script already applies the standard fix (`echo "startxfce4" > ~/.xsession`). If it still occurs, log in via SSH and run:
```bash
echo "startxfce4" > /home/aman/.xsession
chown aman:aman /home/aman/.xsession
sudo systemctl restart xrdp
```

**XRDP not connecting?**
Check service status and ensure Tailscale is up:
```bash
sudo systemctl status xrdp
tailscale status
```

**Firefox GPG error during install?**
```bash
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | \
  gpg --dearmor | sudo tee /etc/apt/keyrings/mozilla.gpg > /dev/null
```

**Low memory / OOM kills?**
Verify swap is active:
```bash
free -h
swapon --show
```

---

## 📦 Installed Packages Summary

| Package | Purpose |
|---|---|
| `xfce4` + `xfce4-goodies` | Lightweight desktop environment |
| `xrdp` | Remote Desktop Protocol server |
| `tailscale` | Zero-config VPN for secure remote access |
| `fail2ban` | SSH brute-force protection |
| `ufw` | Uncomplicated Firewall |
| `firefox` (Mozilla repo) | Web browser (non-Snap) |
| `google-chrome-stable` | Google Chrome browser |
| `htop` | Interactive process monitor |
| `curl`, `wget`, `git`, `nano` | Essential dev utilities |
| `gnupg`, `software-properties-common` | GPG and repo management |

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

```
MIT License — free to use, modify, and distribute with attribution.
```

---

## 👤 Author

**Aman**

- 🌐 GitHub: [@technicalboy2023](https://github.com/technicalboy2023)
- 💬 Feel free to open issues or PRs for improvements!

---

## 🌟 Star This Repo

If this script saved you time, consider giving it a ⭐ on GitHub — it helps others find it!

---

*Built for Ubuntu 22.04 LTS · Tested on Linode, DigitalOcean, and Hetzner VPS providers*
