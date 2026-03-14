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

"Install Demo" (https://readme-typing-svg.demolab.com?font=Fira+Code&size=22&duration=2000&pause=800&color=00FF9C&center=true&vCenter=true&width=600&lines=curl+-s+https://raw.githubusercontent.com/technicalboy2023/vps-master-setup/main/install.sh+%7C+bash;Updating+Ubuntu+System...;Installing+XFCE+Desktop...;Configuring+XRDP...;Installing+Tailscale+VPN...;Applying+RAM+Optimizations...;VPS+Setup+Complete!)

---

✨ Features

🔐 Security

- Root SSH login disabled
- Fail2Ban enabled
- UFW firewall configured
- Secure sudo admin user

---

🖥 Desktop Environment

- XFCE lightweight desktop
- XRDP optimized remote desktop
- XRDP black screen fix
- Software rendering enabled

---

🌐 Private Remote Access

- Tailscale VPN installed
- Secure RDP access via private network
- Public RDP port blocked

---

⚙️ Performance Optimization

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

👤 Default Login Credentials

User: aman
Password: password

⚠ Change password immediately:

passwd aman

---

🌐 Remote Desktop Access

Start Tailscale:

tailscale up

Get your Tailscale IP:

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

Public RDP port 3389 blocked for security.

---

⭐ Star History

""Star History Chart" (https://api.star-history.com/svg?repos=technicalboy2023/vps-master-setup&type=Date)" (https://star-history.com/#technicalboy2023/vps-master-setup&Date)

---

📂 Project Structure

vps-master-setup
│
├ install.sh
├ README.md
└ .github
    └ workflows
        └ script-check.yml

---

🧠 Use Cases

- Remote desktop VPS
- Automation servers
- AI tools
- n8n workflows
- Development environments
- Disposable monthly VPS

---

📜 License

MIT License

---

⭐ Support

If this project helped you, consider giving it a GitHub Star ⭐
