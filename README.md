🚀 VPS Master Setup

"Ubuntu" (https://img.shields.io/badge/Ubuntu-22.04-orange)
"Shell" (https://img.shields.io/badge/Shell-Bash-blue)
"License" (https://img.shields.io/badge/License-MIT-green)
"Auto Install" (https://img.shields.io/badge/Install-One%20Command-success)

"Visitors" (https://api.visitorbadge.io/api/visitors?path=technicalboy2023/vps-master-setup&label=Visitors&countColor=%23263759)

---

⚡ One Command Installation

curl -s https://raw.githubusercontent.com/technicalboy2023/vps-master-setup/main/install.sh | bash

This script automatically:

✔ Updates Ubuntu
✔ Installs XFCE desktop
✔ Configures XRDP
✔ Installs Tailscale VPN
✔ Applies RAM optimizations
✔ Installs browsers
✔ Hardens server security

---

🎬 Installation Demo

"Install Demo" (https://raw.githubusercontent.com/technicalboy2023/vps-master-setup/main/assets/install-demo.gif)

---

✨ Features

🔐 Security

- Root SSH login disabled
- Fail2Ban enabled
- UFW firewall configured
- Secure sudo user

🖥 Desktop Environment

- XFCE lightweight desktop
- XRDP optimized remote desktop
- XRDP black screen fix
- Software rendering enabled

🌐 Networking

- Tailscale VPN installed
- Private remote desktop access
- Public RDP port blocked

⚡ Performance Optimization

The script applies kernel tuning:

vm.swappiness=10
vm.overcommit_memory=1
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.dirty_expire_centisecs=500
vm.dirty_writeback_centisecs=100

---

📋 System Requirements

Requirement| Minimum
OS| Ubuntu 22.04
RAM| 2 GB
Disk| 15 GB
CPU| 1 vCPU

---

👤 Login Credentials

User: aman
Password: password

⚠ Change password immediately:

passwd aman

---

🌐 Remote Desktop Access

Start Tailscale:

tailscale up

Get IP:

tailscale ip

Connect using RDP:

IP: Tailscale IP
User: aman
Password: password

---

🛡 Security Architecture

Internet
   │
   ▼
Tailscale VPN
   │
   ▼
XRDP Server
   │
   ▼
XFCE Desktop

Public port 3389 blocked for security.

---

⭐ Star History

""Star History Chart" (https://api.star-history.com/svg?repos=technicalboy2023/vps-master-setup&type=Date)" (https://star-history.com/#technicalboy2023/vps-master-setup&Date)

---

📂 Project Structure

vps-master-setup
│
├ install.sh
├ README.md
├ LICENSE
└ assets
     └ install-demo.gif

---

🧠 Use Cases

- Remote desktop VPS
- AI / n8n automation
- Docker servers
- Development environments
- Disposable monthly VPS

---

⭐ Support

If this project helped you, please give it a star ⭐
