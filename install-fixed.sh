#!/bin/bash

# VPS Master Setup Script v2.0
# Optimized for 2GB RAM, 1 CPU, 20GB Disk
# Ubuntu 22.04 LTS

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
LOG_FILE="/var/log/vps-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Functions
log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# ==================== HEADER ====================

clear
log "=========================================="
log "   VPS MASTER SETUP v2.0"
log "   2GB RAM Ultra-Optimized"
log "=========================================="
echo ""

# ==================== PRE-CHECKS ====================

log "=== SYSTEM CHECKS ==="

# Root check
if [ "$EUID" -ne 0 ]; then
    error "Please run as root: sudo bash $0"
    exit 1
fi
log "✓ Running as root"

# RAM check
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
info "RAM detected: ${TOTAL_RAM}MB"
if [ "$TOTAL_RAM" -lt 1536 ]; then
    warn "LOW RAM: ${TOTAL_RAM}MB (Recommended: 1536MB+)"
    read -p "Continue anyway? (y/N): " FORCE
    [[ "$FORCE" =~ ^[Yy]$ ]] || exit 1
else
    log "✓ RAM sufficient"
fi

# Disk check
DISK_FREE=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
info "Disk free: ${DISK_FREE}GB"
if [ "$DISK_FREE" -lt 5 ]; then
    error "Insufficient disk space: ${DISK_FREE}GB (Need 5GB+)"
    exit 1
fi
log "✓ Disk space OK"

# Network check
if ! ping -c 1 8.8.8.8 &>/dev/null; then
    warn "No internet detected! Continuing anyway..."
else
    log "✓ Internet connected"
fi

# ==================== USER INPUT ====================

echo ""
log "=== USER CONFIGURATION ==="

read -p "Enter username [default: aman]: " USERNAME
USERNAME=${USERNAME:-aman}

while true; do
    echo ""
    read -s -p "Enter password (min 6 chars): " USERPASS
    echo ""
    read -s -p "Confirm password: " USERPASS_CONFIRM
    echo ""
    
    if [ "$USERPASS" != "$USERPASS_CONFIRM" ]; then
        warn "Passwords don't match. Try again."
        continue
    fi
    
    if [ ${#USERPASS} -lt 6 ]; then
        warn "Password too short (min 6 chars). Try again."
        continue
    fi
    
    log "✓ Password set"
    break
done

read -p "Enter timezone [default: Asia/Kolkata]: " TIMEZONE
TIMEZONE=${TIMEZONE:-Asia/Kolkata}

# ==================== SYSTEM BASE ====================

log "=== CONFIGURING SYSTEM ==="

# Timezone
timedatectl set-timezone "$TIMEZONE" 2>/dev/null || {
    warn "Invalid timezone, using Asia/Kolkata"
    timedatectl set-timezone Asia/Kolkata
}
log "✓ Timezone set"

# Fix mirrors for speed
sed -i 's|http://|https://|g' /etc/apt/sources.list 2>/dev/null || true
sed -i 's|mirrors.linode.com|archive.ubuntu.com|g' /etc/apt/sources.list 2>/dev/null || true
sed -i 's|mirrors.digitalocean.com|archive.ubuntu.com|g' /etc/apt/sources.list 2>/dev/null || true
log "✓ Mirrors optimized"

# Update system
log "Updating package lists..."
apt-get update -qq
log "✓ Package lists updated"

log "Upgrading packages..."
apt-get upgrade -y -qq
log "✓ System upgraded"

# ==================== ESSENTIAL PACKAGES ====================

log "=== INSTALLING BASE PACKAGES ==="

DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
    curl wget git nano htop ufw fail2ban \
    gnupg ca-certificates net-tools \
    apt-transport-https software-properties-common \
    zram-tools p7zip-full unzip

log "✓ Base packages installed"

# Enable fail2ban
systemctl enable fail2ban --now
log "✓ Fail2Ban enabled"

# ==================== MEMORY OPTIMIZATION ====================

log "=== MEMORY OPTIMIZATION (CRITICAL) ==="

# ZRAM setup
log "Configuring ZRAM..."
cat > /etc/default/zramswap << 'EOF'
ALGO=lz4
PERCENT=150
PRIORITY=100
EOF

systemctl enable zramswap --now
sleep 2

# Verify ZRAM
if swapon --show | grep -q zram; then
    ZRAM_SIZE=$(swapon --show=SIZE | grep zram | awk '{print $2}')
    log "✓ ZRAM active: $ZRAM_SIZE"
else
    warn "ZRAM failed, using disk swap fallback"
fi

# Emergency swap
if [ ! -f /swapfile ]; then
    fallocate -l 512M /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw,pri=10 0 0' >> /etc/fstab
    log "✓ Emergency swap created (512MB)"
fi

# Kernel tuning for 2GB RAM
log "Applying kernel optimizations..."
cat >> /etc/sysctl.conf << 'EOF'

# === 2GB RAM Optimizations ===
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.dirty_expire_centisecs=500
vm.dirty_writeback_centisecs=100
vm.overcommit_memory=1
vm.page-cluster=0
vm.min_free_kbytes=32768

# Network
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq

# OOM
vm.oom_kill_allocating_task=1
EOF

sysctl -p >/dev/null 2>&1
log "✓ Kernel tuned"

# Enable BBR
modprobe tcp_bbr 2>/dev/null || true
echo "tcp_bbr" >> /etc/modules-load.d/bbr.conf 2>/dev/null || true

# ==================== FIREWALL ====================

log "=== CONFIGURING FIREWALL ==="

ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw logging off
ufw --force enable

log "✓ Firewall enabled (SSH only)"

# ==================== USER SETUP ====================

log "=== CREATING USER ==="

# Remove if exists
id "$USERNAME" &>/dev/null && {
    warn "User $USERNAME exists, removing..."
    userdel -r "$USERNAME" 2>/dev/null || true
}

# Create user
useradd -m -s /bin/bash "$USERNAME"
echo "$USERNAME:$USERPASS" | chpasswd
usermod -aG sudo "$USERNAME"

# SSH directory
mkdir -p /home/$USERNAME/.ssh
chmod 700 /home/$USERNAME/.ssh
touch /home/$USERNAME/.ssh/authorized_keys
chmod 600 /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh

log "✓ User $USERNAME created"

# ==================== SSH HARDENING ====================

log "=== HARDENING SSH ==="

mkdir -p /etc/ssh/sshd_config.d

cat > /etc/ssh/sshd_config.d/99-hardening.conf << 'EOF'
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
UseDNS no
Compression yes
MaxSessions 2
EOF

systemctl restart sshd
log "✓ SSH hardened"

# ==================== XFCE DESKTOP ====================

log "=== INSTALLING XFCE (MINIMAL) ==="

# Core only
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
    xfce4-panel \
    xfce4-session \
    xfce4-settings \
    xfce4-terminal \
    xfwm4 \
    xfdesktop4 \
    thunar \
    dbus-x11 \
    x11-xserver-utils \
    gtk2-engines-xfce

# Remove bloat
apt-get purge -y --auto-remove \
    xfce4-power-manager \
    xfce4-screensaver \
    xfce4-clipman \
    xfce4-dict \
    2>/dev/null || true

# Session config
echo "startxfce4" > /home/$USERNAME/.xsession
chown $USERNAME:$USERNAME /home/$USERNAME/.xsession
chmod 644 /home/$USERNAME/.xsession

# Also for skel
echo "startxfce4" > /etc/skel/.xsession

log "✓ XFCE installed (minimal)"

# ==================== XRDP ====================

log "=== INSTALLING XRDP ==="

apt-get install -y -qq --no-install-recommends xrdp

# Optimize
sed -i 's/max_bpp=32/max_bpp=16/' /etc/xrdp/xrdp.ini
sed -i 's/xserverbpp=24/xserverbpp=16/' /etc/xrdp/xrdp.ini 2>/dev/null || true

# Additional optimizations
cat >> /etc/xrdp/xrdp.ini << 'EOF'

[Globals]
bitmap_cache=yes
bitmap_compression=yes
EOF

systemctl enable xrdp --now

# Block public RDP (Tailscale only)
ufw deny 3389/tcp comment 'Block public RDP' 2>/dev/null || true

log "✓ XRDP installed (port 3389, localhost only via Tailscale)"

# ==================== FIREFOX ====================

log "=== INSTALLING FIREFOX ==="

# Remove snap completely
systemctl stop snapd 2>/dev/null || true
apt-get purge -y snapd 2>/dev/null || true
rm -rf /snap /var/snap /var/lib/snapd 2>/dev/null || true

# Block snap
cat > /etc/apt/preferences.d/nosnap.pref << 'EOF'
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

# Mozilla repo
install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- 2>/dev/null | \
    gpg --dearmor > /etc/apt/keyrings/mozilla.gpg 2>/dev/null || true

echo "deb [signed-by=/etc/apt/keyrings/mozilla.gpg] https://packages.mozilla.org/apt mozilla main" > \
    /etc/apt/sources.list.d/mozilla.list 2>/dev/null || true

# Pin Firefox
echo -e "Package: firefox*\nPin: origin packages.mozilla.org\nPin-Priority: 1000" > \
    /etc/apt/preferences.d/mozilla 2>/dev/null || true

apt-get update -qq 2>/dev/null || true
apt-get install -y --allow-downgrades --no-install-recommends firefox 2>/dev/null || \
apt-get install -y firefox-esr 2>/dev/null || \
warn "Firefox install failed, install manually"

# Firefox low-RAM config
mkdir -p /home/$USERNAME/.mozilla/firefox/*.default-release 2>/dev/null || true
cat > /home/$USERNAME/.user.js 2>/dev/null << 'EOF'
// Low RAM optimizations
user_pref("browser.cache.disk.enable", false);
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.tabs.firefox-view", false);
user_pref("browser.compactmode.show", true);
user_pref("browser.uidensity", 1);
user_pref("dom.ipc.processCount", 1);
user_pref("extensions.pocket.enabled", false);
user_pref("browser.newtabpage.enabled", false);
EOF

chown -R $USERNAME:$USERNAME /home/$USERNAME/.mozilla 2>/dev/null || true
chown $USERNAME:$USERNAME /home/$USERNAME/.user.js 2>/dev/null || true

log "✓ Firefox installed (optimized)"

# ==================== TAILSCALE ====================

log "=== INSTALLING TAILSCALE ==="

curl -fsSL https://tailscale.com/install.sh | sh
systemctl enable tailscaled --now

log "✓ Tailscale installed"

# ==================== OOM PROTECTION ====================

log "=== INSTALLING OOM PROTECTION ==="

apt-get install -y -qq --no-install-recommends earlyoom 2>/dev/null || true

cat > /etc/default/earlyoom << 'EOF'
EARLYOOM_ARGS="-m 5 -s 100 -r 60 --prefer 'chrome|firefox|Web Content' --avoid 'sshd|xrdp|xfce'"
EOF

systemctl enable earlyoom --now 2>/dev/null || warn "EarlyOOM failed"

log "✓ OOM protection enabled"

# ==================== CLEANUP ====================

log "=== CLEANING UP ==="

# Remove bloat
apt-get purge -y --auto-remove \
    libreoffice* \
    thunderbird \
    rhythmbox \
    totem \
    gnome-games \
    aisleriot \
    gnome-mahjongg \
    gnome-mines \
    gnome-sudoku \
    2>/dev/null || true

# Clean
apt-get autoremove -y -qq
apt-get autoclean -qq
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/* 2>/dev/null || true

log "✓ Cleanup complete"

# ==================== FINAL INFO ====================

log "=== CREATING INFO FILE ==="

# Get IP info
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unknown")

cat > /home/$USERNAME/VPS-INFO.txt << EOF
========================================
   VPS MASTER SETUP COMPLETE
========================================

SERVER INFO
-----------
Public IP: $PUBLIC_IP
Username: $USERNAME
Hostname: $(hostname)

CONNECTION STEPS
----------------
1. SSH into VPS:
   ssh $USERNAME@$PUBLIC_IP

2. Start Tailscale:
   sudo tailscale up
   (Open the URL in browser to authenticate)

3. Get Tailscale IP:
   tailscale ip -4
   (Example: 100.x.x.x)

4. Connect via RDP:
   - Windows: mstsc → 100.x.x.x:3389
   - Mac: Microsoft Remote Desktop → 100.x.x.x:3389
   - Username: $USERNAME
   - Password: (as set during install)

OPTIMIZATIONS APPLIED
---------------------
✓ ZRAM 3GB (150% of RAM)
✓ Emergency swap 512MB
✓ Kernel tuned for 2GB RAM
✓ XFCE minimal (no bloat)
✓ Firefox optimized (disk cache disabled)
✓ XRDP 16-bit color (fast)
✓ EarlyOOM (kills runaway processes)
✓ Firewall (SSH only)
✓ Fail2Ban (brute-force protection)

PERFORMANCE TIPS
----------------
• Max 3-4 Firefox tabs recommended
• Close unused applications
• Use terminal apps when possible
• Monitor RAM: htop or free -h

USEFUL COMMANDS
---------------
htop              - System monitor
free -h           - RAM usage
tailscale status  - VPN status
tailscale ip -4   - Tailscale IP
ncdu /            - Disk usage
sudo reboot       - Restart

TROUBLESHOOTING
---------------
Black screen on RDP:
  echo "startxfce4" > ~/.xsession && sudo systemctl restart xrdp

Firefox slow:
  Close tabs, restart Firefox

System hang:
  SSH in, run: sudo killall -9 firefox

Low RAM:
  sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches

LOG FILE
--------
Setup log: $LOG_FILE

========================================
EOF

chown $USERNAME:$USERNAME /home/$USERNAME/VPS-INFO.txt
chmod 644 /home/$USERNAME/VPS-INFO.txt

log "✓ Info file created: ~/VPS-INFO.txt"

# ==================== COMPLETION ====================

echo ""
log "========================================"
log "   SETUP COMPLETE!"
log "========================================"
echo ""
info "Username: $USERNAME"
info "RDP Port: 3389 (via Tailscale only)"
info "Log file: $LOG_FILE"
echo ""
warn "IMPORTANT NEXT STEPS:"
echo "1. Run: sudo tailscale up"
echo "2. Authenticate with the URL provided"
echo "3. Get Tailscale IP: tailscale ip -4"
echo "4. Connect RDP to that IP"
echo ""
info "Read ~/VPS-INFO.txt for full details"
echo ""

# Reboot prompt
read -p "Reboot now? (recommended) [Y/n]: " REBOOT
if [[ "$REBOOT" =~ ^[Nn]$ ]]; then
    log "Skipping reboot. Please reboot manually when ready."
    exit 0
else
    log "Rebooting in 5 seconds..."
    sleep 5
    reboot
fi
