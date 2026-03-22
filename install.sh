#!/bin/bash

# ============================================================
#   VPS MASTER SETUP — FINAL v2.0
#   Ubuntu 22.04 LTS | All VPS Providers
#   Low-End VPS Optimized | Tailscale RDP
#   User: aman | Password: password
# ============================================================

# ============================================================
# SECTION 0 — GLOBAL SETTINGS (Sabse Pehle)
# ============================================================

# --- Non-interactive (koi bhi prompt nahi rukegi script) ---
export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1
export UCF_FORCE_CONFFOLD=1

# --- Pipefail (pipe errors catch karo) ---
set -euo pipefail

# --- Log File (define karo PEHLE trap se) ---
LOG_FILE="/var/log/vps-setup-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# --- Temp Directory ---
TMPDIR_SETUP=$(mktemp -d)

# --- Unified Cleanup Trap (ERR + EXIT dono handle karta hai) ---
cleanup() {
  local EXIT_CODE=$?
  sync
  sleep 1
  rm -rf "$TMPDIR_SETUP" 2>/dev/null || true
  echo ""
  if [ "$EXIT_CODE" -ne 0 ]; then
    echo "❌ Setup FAILED — Line ke paas error aaya." >&2
    echo "📝 Full log dekho: $LOG_FILE" >&2
  else
    echo "📝 Full log saved: $LOG_FILE"
  fi
}
trap cleanup EXIT

# --- Root Check ---
if [ "$EUID" -ne 0 ]; then
  echo "❌ Root se chalao: sudo bash $0"
  exit 1
fi

# ============================================================
# BANNER
# ============================================================
clear
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     VPS MASTER SETUP — FINAL v2.0       ║"
echo "║     Ubuntu 22.04 | All Providers        ║"
echo "║     Low-End Optimized | Tailscale RDP   ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "📝 Log: $LOG_FILE"
echo ""

# ============================================================
# STEP 1/15 — PRE-FLIGHT CHECKS
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 STEP 1/15 — Pre-Flight Checks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# OS check (warning only, script nahi rukti)
if ! grep -q "22.04" /etc/os-release 2>/dev/null; then
  echo "   ⚠️  WARNING: Ubuntu 22.04 nahi hai."
  echo "   OS: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2)"
  echo "   Continue kar rahe hain..."
fi

# Architecture
ARCH=$(dpkg --print-architecture)
echo "   🖥️  Architecture : $ARCH"
if [ "$ARCH" != "amd64" ] && [ "$ARCH" != "arm64" ]; then
  echo "   ❌ Unsupported architecture: $ARCH"
  exit 1
fi

# RAM check
TOTAL_RAM=$(free -m | awk 'NR==2{print $2}')
echo "   💾 RAM           : ${TOTAL_RAM}MB"
if [ "$TOTAL_RAM" -lt 400 ]; then
  echo "   ❌ Minimum 512MB RAM chahiye. Sirf ${TOTAL_RAM}MB hai."
  exit 1
fi

# Disk check
AVAILABLE_MB=$(df / | awk 'NR==2{print int($4/1024)}')
echo "   💿 Disk Free     : ${AVAILABLE_MB}MB"
if [ "$AVAILABLE_MB" -lt 4096 ]; then
  echo "   ❌ Minimum 4GB disk chahiye. Sirf ${AVAILABLE_MB}MB free hai."
  exit 1
fi

# Internet check
echo "   🌐 Internet check kar rahe hain..."
if ! curl -fsSL --max-time 15 https://archive.ubuntu.com -o /dev/null 2>/dev/null; then
  echo "   ❌ Internet nahi hai. Script band ho rahi hai."
  exit 1
fi

echo "   ✅ Pre-flight checks PASSED"

# ============================================================
# STEP 2/15 — TIMEZONE
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🕐 STEP 2/15 — Timezone Set Karna"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

timedatectl set-timezone Asia/Kolkata 2>/dev/null || \
  timedatectl set-timezone UTC

echo "   ✅ Timezone: $(timedatectl show --value -p Timezone 2>/dev/null || echo 'Set')"

# ============================================================
# STEP 3/15 — APT MIRROR FIX (All Providers)
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 STEP 3/15 — APT Mirror Fix (All Providers)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Backup
cp /etc/apt/sources.list "/etc/apt/sources.list.bak.$(date +%Y%m%d)" 2>/dev/null || true

# All major VPS provider mirrors fix
MIRROR_LIST=(
  "mirrors.linode.com"
  "mirror.linode.com"
  "mirrors.digitalocean.com"
  "mirrors.vultr.com"
  "mirror.hetzner.com"
  "mirrors.contabo.com"
  "mirrors.ovh.net"
  "ftp.hosteurope.de"
  "mirror.uplink.de"
  "mirrors.aliyun.com"
  "mirrors.tuna.tsinghua.edu.cn"
)

for MIRROR in "${MIRROR_LIST[@]}"; do
  # Exact pattern match with protocol
  sed -i \
    -e "s|http://${MIRROR}/ubuntu|http://archive.ubuntu.com/ubuntu|g" \
    -e "s|https://${MIRROR}/ubuntu|http://archive.ubuntu.com/ubuntu|g" \
    /etc/apt/sources.list 2>/dev/null || true

  # sources.list.d bhi fix karo
  find /etc/apt/sources.list.d/ -type f -name "*.list" 2>/dev/null | \
  while read -r FILE; do
    sed -i \
      -e "s|http://${MIRROR}/ubuntu|http://archive.ubuntu.com/ubuntu|g" \
      -e "s|https://${MIRROR}/ubuntu|http://archive.ubuntu.com/ubuntu|g" \
      "$FILE" 2>/dev/null || true
  done
done

echo "   ✅ APT mirror fixed (Linode, DO, Vultr, Hetzner, Contabo, OVH aur more)"

# ============================================================
# STEP 4/15 — SYSTEM UPDATE
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔄 STEP 4/15 — System Update"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

apt-get update -qq

# Config file conflicts: existing raho, naya nahi (script nahi rukti)
apt-get upgrade -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" \
  -o Dpkg::Options::="--force-overwrite" \
  --allow-change-held-packages \
  -qq

echo "   ✅ System fully updated"

# ============================================================
# STEP 5/15 — BASE PACKAGES
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 STEP 5/15 — Base Packages Install"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

apt-get install -y -qq \
  curl \
  wget \
  git \
  nano \
  htop \
  ufw \
  fail2ban \
  gnupg \
  gnupg2 \
  software-properties-common \
  ca-certificates \
  apt-transport-https \
  lsb-release \
  unattended-upgrades \
  apt-listchanges \
  chrony \
  earlyoom \
  xz-utils \
  net-tools \
  dbus-x11 \
  psmisc \
  lsof

echo "   ✅ Base packages installed"

# ============================================================
# STEP 6/15 — SECURITY: FAIL2BAN + UFW
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🛡️  STEP 6/15 — Security Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- Fail2Ban ---
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 2h
findtime = 10m
maxretry = 5
backend  = systemd

[sshd]
enabled  = true
port     = ssh
logpath  = %(sshd_log)s
maxretry = 3
bantime  = 24h
EOF

systemctl enable fail2ban --quiet
systemctl restart fail2ban
echo "   ✅ Fail2Ban: SSH 3 tries → 24h ban"

# --- UFW ---
# Pehle reset (duplicate rules avoid karo)
ufw --force reset

ufw default deny incoming
ufw default allow outgoing

# SSH - rate limited
ufw limit OpenSSH comment "SSH rate limited"

# RDP - public se block
ufw deny 3389/tcp comment "RDP blocked from internet"
ufw deny 3389/udp comment "RDP UDP blocked from internet"

# *** FIX #1 — Tailscale interface se RDP allow karo ***
# (Tailscale install hone ke BAAD bhi kaam karta hai - interface allow)
ufw allow in on tailscale0 comment "Tailscale full access" 2>/dev/null || true

# IPv6 enable
if [ -f /etc/default/ufw ]; then
  sed -i 's/^IPV6=no/IPV6=yes/' /etc/default/ufw
  grep -q "^IPV6=" /etc/default/ufw || echo "IPV6=yes" >> /etc/default/ufw
fi

ufw --force enable
echo "   ✅ UFW: SSH rate-limited | RDP internet-blocked | Tailscale allowed"

# ============================================================
# STEP 7/15 — USER SETUP: aman
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "👤 STEP 7/15 — User 'aman' Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if id "aman" &>/dev/null; then
  echo "   User 'aman' pehle se hai — update kar rahe hain..."
  usermod -s /bin/bash aman
  mkdir -p /home/aman
  chown aman:aman /home/aman
else
  useradd -m -s /bin/bash -c "VPS Admin" aman
  echo "   User 'aman' create kiya."
fi

# Password set: "password"
printf 'aman:%s\n' "password" | chpasswd
echo "   🔑 Password: password"

# Sudo group
usermod -aG sudo aman

# Passwordless sudo (RDP ke liye smooth experience)
echo "aman ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/aman
chmod 0440 /etc/sudoers.d/aman
visudo -cf /etc/sudoers.d/aman >/dev/null 2>&1 || {
  rm -f /etc/sudoers.d/aman
  echo "   ⚠️  Sudoers file issue, normal sudo use hoga"
}

echo "   ✅ User aman ready | Password: password | Sudo: yes"

# ============================================================
# STEP 8/15 — SSH HARDENING
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔒 STEP 8/15 — SSH Hardening"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mkdir -p /etc/ssh/sshd_config.d

cat > /etc/ssh/sshd_config.d/01-hardening.conf << 'EOF'
PermitRootLogin no
MaxAuthTries 3
MaxSessions 5
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
PrintMotd no
UseDNS no
Compression yes
EOF

# *** FIX #2 — Syntax test + post-restart verify (lock out prevent) ***
if sshd -t 2>/dev/null; then
  systemctl restart ssh
  sleep 2
  if systemctl is-active --quiet ssh; then
    echo "   ✅ SSH hardened aur running"
  else
    echo "   ⚠️  SSH restart fail — revert kar rahe hain"
    rm -f /etc/ssh/sshd_config.d/01-hardening.conf
    systemctl restart ssh
  fi
else
  echo "   ⚠️  SSH config invalid — revert kar rahe hain"
  rm -f /etc/ssh/sshd_config.d/01-hardening.conf
  systemctl restart ssh
fi

# ============================================================
# STEP 9/15 — SWAP FILE
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💾 STEP 9/15 — Swap File Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ! -f /swapfile ]; then
  # RAM ke hisaab se swap size
  if   [ "$TOTAL_RAM" -lt 512  ]; then SWAP_SIZE="1G"
  elif [ "$TOTAL_RAM" -lt 2048 ]; then SWAP_SIZE="2G"
  else                                  SWAP_SIZE="2G"
  fi

  echo "   Creating ${SWAP_SIZE} swapfile..."

  # fallocate prefer, fallback to dd
  if fallocate -l "$SWAP_SIZE" /swapfile 2>/dev/null; then
    echo "   fallocate se banaya"
  else
    echo "   dd se bana raha hai (time lag sakta hai)..."
    dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress 2>/dev/null
  fi

  chmod 600 /swapfile
  mkswap /swapfile -q
  swapon /swapfile

  # fstab mein add (nofail — swap fail hone pe boot nahi rukta)
  echo '/swapfile none swap sw,nofail 0 0' >> /etc/fstab
  echo "   ✅ Swapfile: ${SWAP_SIZE} created"
else
  echo "   ✅ Swapfile already exists"
fi

# ============================================================
# STEP 10/15 — KERNEL + RAM OPTIMIZATION
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚡ STEP 10/15 — Kernel & RAM Optimization"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Backup sysctl
cp /etc/sysctl.conf "/etc/sysctl.conf.bak.$(date +%Y%m%d)" 2>/dev/null || true

# *** FIX #3 — Duplicate entries pehle saaf karo ***
for PARAM in \
  vm.swappiness vm.overcommit_memory vm.vfs_cache_pressure \
  vm.dirty_ratio vm.dirty_background_ratio \
  vm.dirty_expire_centisecs vm.dirty_writeback_centisecs \
  net.core.rmem_max net.core.wmem_max \
  net.ipv4.tcp_rmem net.ipv4.tcp_wmem \
  net.ipv4.tcp_window_scaling net.ipv4.tcp_fastopen \
  fs.file-max kernel.core_pattern fs.suid_dumpable; do
  sed -i "/^${PARAM}/d" /etc/sysctl.conf 2>/dev/null || true
done

# Clean optimized sysctl
cat >> /etc/sysctl.conf << 'EOF'

# ===== VPS OPTIMIZED — Low-End =====
vm.swappiness=10
vm.overcommit_memory=1
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.dirty_expire_centisecs=500
vm.dirty_writeback_centisecs=100
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_rmem=4096 87380 134217728
net.ipv4.tcp_wmem=4096 65536 134217728
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_fastopen=3
fs.file-max=200000
kernel.core_pattern=/dev/null
fs.suid_dumpable=0
EOF

# *** FIX #4 — sysctl errors dikhao, silent nahi ***
sysctl -p 2>&1 | grep -i "error\|invalid\|unknown" || true
echo "   ✅ Kernel params applied"

# --- Limits (*** FIX #5 — dedicated file, no duplicates ***) ---
cat > /etc/security/limits.d/99-vps-optimized.conf << 'EOF'
* soft core    0
* hard core    0
* soft nofile  65536
* hard nofile  65536
* soft nproc   32768
* hard nproc   32768
EOF
echo "   ✅ System limits set"

# --- ZRAM (*** FIX #6 — Persistent systemd service ***) ---
cat > /usr/local/bin/zram-setup.sh << 'ZEOF'
#!/bin/bash
modprobe zram 2>/dev/null || exit 0
sleep 1
[ ! -b /dev/zram0 ] && exit 0
RAM_MB=$(free -m | awk 'NR==2{print $2}')
ZRAM_MB=$(( RAM_MB / 2 ))
[ "$ZRAM_MB" -lt 128 ] && ZRAM_MB=128
echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null || \
  echo lzo > /sys/block/zram0/comp_algorithm 2>/dev/null || true
echo "${ZRAM_MB}M" > /sys/block/zram0/disksize
mkswap /dev/zram0 -q && swapon -p 100 /dev/zram0
echo "ZRAM: ${ZRAM_MB}MB active"
ZEOF
chmod +x /usr/local/bin/zram-setup.sh

cat > /etc/systemd/system/zram-swap.service << 'SEOF'
[Unit]
Description=ZRAM Compressed Swap
After=local-fs.target swap.target
Before=basic.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/zram-setup.sh
ExecStop=/bin/bash -c "swapoff /dev/zram0 2>/dev/null; \
  echo 1 > /sys/block/zram0/reset 2>/dev/null; true"

[Install]
WantedBy=multi-user.target
SEOF

systemctl daemon-reload
systemctl enable zram-swap --quiet
# *** FIX #7 — sleep 1 for udev device node ***
modprobe zram 2>/dev/null || true
sleep 1
if [ -b /dev/zram0 ]; then
  bash /usr/local/bin/zram-setup.sh
  echo "   ✅ ZRAM: $(( TOTAL_RAM / 2 ))MB compressed swap (persistent)"
else
  echo "   ℹ️  ZRAM: Reboot ke baad active hoga"
fi

# --- EarlyOOM ---
systemctl enable earlyoom --quiet
systemctl restart earlyoom
echo "   ✅ EarlyOOM: System hang prevention active"

# --- /tmp on RAM (*** FIX #8 — sirf fstab, remount nahi ***) ---
if ! grep -q "tmpfs /tmp" /etc/fstab; then
  echo "tmpfs /tmp tmpfs defaults,noatime,nosuid,nodev,size=256M 0 0" >> /etc/fstab
  echo "   ✅ /tmp RAM mount: Reboot ke baad active hoga"
fi

# --- Disable Unnecessary Services ---
for SVC in bluetooth cups cups-browsed avahi-daemon ModemManager; do
  if systemctl list-unit-files 2>/dev/null | grep -q "^${SVC}"; then
    systemctl disable "$SVC" --quiet 2>/dev/null || true
    systemctl stop    "$SVC"         2>/dev/null || true
  fi
done
echo "   ✅ Unnecessary services disabled"

# ============================================================
# STEP 11/15 — XFCE DESKTOP
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🖥️  STEP 11/15 — XFCE Desktop Install"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Low-end optimized — only what's needed
apt-get install -y -qq --no-install-recommends \
  xfce4 \
  xfce4-terminal \
  xfce4-taskmanager \
  xfce4-screenshooter \
  xfce4-notifyd \
  thunar \
  mousepad \
  xfce4-power-manager \
  xdg-utils \
  x11-xserver-utils

# --- .xsession for aman ---
cat > /home/aman/.xsession << 'EOF'
#!/bin/bash
export XDG_SESSION_TYPE=x11
export LIBGL_ALWAYS_SOFTWARE=1
exec startxfce4
EOF
chown aman:aman /home/aman/.xsession
chmod 755 /home/aman/.xsession

# --- System-wide default (black screen fix) ---
cat > /etc/skel/.xsession << 'EOF'
#!/bin/bash
export XDG_SESSION_TYPE=x11
export LIBGL_ALWAYS_SOFTWARE=1
exec startxfce4
EOF
chmod 755 /etc/skel/.xsession

# --- Disable Compositing (performance) ---
mkdir -p /home/aman/.config/xfce4/xfconf/xfce-perchannel-xml/
cat > /home/aman/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="use_compositing" type="bool" value="false"/>
    <property name="vblank_mode"     type="string" value="off"/>
  </property>
</channel>
EOF
chown -R aman:aman /home/aman/.config

# --- Software Rendering (VPS pe GPU nahi hota) ---
grep -q "LIBGL_ALWAYS_SOFTWARE" /etc/environment || \
  echo "LIBGL_ALWAYS_SOFTWARE=1" >> /etc/environment

echo "   ✅ XFCE installed (compositing off, SW rendering on)"

# ============================================================
# STEP 12/15 — XRDP SETUP
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🖥️  STEP 12/15 — XRDP Install & Configure"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

apt-get install -y -qq xrdp

# ssl-cert group (certificate warning fix)
usermod -aG ssl-cert xrdp

# *** FIX #9 — xrdp.ini [xrdp1] sahi section name ***
cat > /etc/xrdp/xrdp.ini << 'EOF'
[Globals]
ini_version=1
fork=true
port=3389
use_vsock=false
security_layer=negotiate
crypt_level=high
certificate=
key_file=
ssl_protocols=TLSv1.2, TLSv1.3
tls_ciphers=HIGH
channel_code=1
max_bpp=24
bulk_compression=true
new_cursors=true
max_idle_time=0
tcp_send_buffer_bytes=4194304
tcp_recv_buffer_bytes=4194304
autorun=

[xrdp1]
name=Xorg
lib=libxup.so
username=ask
password=ask
ip=127.0.0.1
port=-1
code=20
xserverbpp=24
EOF

# *** FIX #10 — sesman.ini: overwrite mat karo, sirf zaroori lines change karo ***
if [ -f /etc/xrdp/sesman.ini ]; then
  # AllowRootLogin off
  sed -i 's/^AllowRootLogin=.*/AllowRootLogin=false/' /etc/xrdp/sesman.ini
  # MaxLoginRetry = 3
  sed -i 's/^MaxLoginRetry=.*/MaxLoginRetry=3/' /etc/xrdp/sesman.ini
  # User window manager enable
  sed -i 's/^EnableUserWindowManager=.*/EnableUserWindowManager=true/' /etc/xrdp/sesman.ini
fi

# *** FIX #11 — startwm.sh: package update safe approach ***
# startwm.sh replace nahi karo — sirf ensure karo .xsession use ho
# (ye pehle se /home/aman/.xsession se handle ho raha hai)

# --- OOM Protection — Persistent via systemd override ***FIX #12*** ---
mkdir -p /etc/systemd/system/xrdp.service.d/
cat > /etc/systemd/system/xrdp.service.d/oom.conf << 'EOF'
[Service]
OOMScoreAdjust=-500
EOF

systemctl daemon-reload
systemctl enable xrdp --quiet
systemctl restart xrdp
sleep 2

if systemctl is-active --quiet xrdp; then
  echo "   ✅ XRDP running | Port 3389 | Tailscale only"
else
  echo "   ❌ XRDP start nahi hua! Log dekho: journalctl -u xrdp"
fi

# --- SSH OOM Protection bhi ---
mkdir -p /etc/systemd/system/ssh.service.d/
cat > /etc/systemd/system/ssh.service.d/oom.conf << 'EOF'
[Service]
OOMScoreAdjust=-500
EOF
systemctl daemon-reload

# ============================================================
# STEP 13/15 — FIREFOX + CHROME / CHROMIUM
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 STEP 13/15 — Browsers Install"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- Remove Snap Firefox ---
if command -v snap &>/dev/null; then
  snap remove firefox 2>/dev/null || true
fi
apt-get remove  -y firefox 2>/dev/null || true
apt-get purge   -y firefox 2>/dev/null || true
apt-get purge   -y snapd   2>/dev/null || true
rm -rf /snap /var/snap /var/lib/snapd /root/snap 2>/dev/null || true
apt-get autoremove -y -qq

# --- Firefox — Mozilla Official Repo ---
install -d -m 0755 /etc/apt/keyrings

echo "   Firefox GPG key download kar rahe hain..."
wget -q "https://packages.mozilla.org/apt/repo-signing-key.gpg" \
  -O "$TMPDIR_SETUP/mozilla.gpg"

# *** FIX #13 — GPG file size verify ***
if [ ! -s "$TMPDIR_SETUP/mozilla.gpg" ]; then
  echo "   ❌ Mozilla GPG key download fail! Firefox skip ho raha hai."
else
  cp "$TMPDIR_SETUP/mozilla.gpg" /etc/apt/keyrings/mozilla.gpg
  chmod 644 /etc/apt/keyrings/mozilla.gpg

  echo "deb [signed-by=/etc/apt/keyrings/mozilla.gpg] https://packages.mozilla.org/apt mozilla main" \
    > /etc/apt/sources.list.d/mozilla.list

  cat > /etc/apt/preferences.d/mozilla-firefox << 'EOF'
Package: firefox*
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

  apt-get update -qq
  apt-get install -y -qq firefox
  echo "   ✅ Firefox installed (Mozilla official, non-Snap)"
fi

# --- Chrome (amd64) / Chromium (arm64) ---
# *** FIX #14 — Architecture check + GPG size verify ***
if [ "$ARCH" = "amd64" ]; then
  echo "   Chrome GPG key download kar rahe hain..."
  wget -q "https://dl.google.com/linux/linux_signing_key.pub" \
    -O "$TMPDIR_SETUP/chrome.gpg.raw"

  if [ ! -s "$TMPDIR_SETUP/chrome.gpg.raw" ]; then
    echo "   ❌ Chrome GPG download fail! Chromium install ho raha hai..."
    apt-get install -y -qq chromium-browser 2>/dev/null || true
  else
    gpg --dearmor < "$TMPDIR_SETUP/chrome.gpg.raw" \
      > /etc/apt/keyrings/google-chrome.gpg
    chmod 644 /etc/apt/keyrings/google-chrome.gpg

    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] \
https://dl.google.com/linux/chrome/deb/ stable main" \
      > /etc/apt/sources.list.d/google-chrome.list

    apt-get update -qq
    apt-get install -y -qq google-chrome-stable
    echo "   ✅ Google Chrome installed"
  fi
else
  # ARM — Chromium use karo
  apt-get install -y -qq chromium-browser 2>/dev/null || \
    apt-get install -y -qq chromium         2>/dev/null || true
  echo "   ✅ Chromium installed (ARM)"
fi

# ============================================================
# STEP 14/15 — TAILSCALE VPN
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 STEP 14/15 — Tailscale VPN Install"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Download install script
curl -fsSL "https://tailscale.com/install.sh" \
  -o "$TMPDIR_SETUP/tailscale-install.sh"

[ -s "$TMPDIR_SETUP/tailscale-install.sh" ] || {
  echo "   ❌ Tailscale install script download fail!"
  exit 1
}

bash "$TMPDIR_SETUP/tailscale-install.sh" 2>/dev/null

systemctl enable tailscaled --quiet
systemctl start  tailscaled

# UFW — Tailscale interface allow (second attempt after install)
ufw allow in on tailscale0 comment "Tailscale VPN" 2>/dev/null || true

# *** FIX #15 — tailscale up hang nahi karega (timeout ke saath) ***
echo ""
echo "   ⚡ Tailscale auth shuru ho raha hai..."
echo "   👇 Neeche URL aayega — browser mein kholo aur login karo:"
echo ""

# Timeout 15 seconds — hang nahi hoga
timeout 15 tailscale up --accept-routes 2>&1 || true

echo ""
echo "   ℹ️  Agar URL nahi aaya: tailscale up command baad mein chalao"
echo "   ✅ Tailscale service running"

# ============================================================
# STEP 15/15 — FINAL SETUP
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔒 STEP 15/15 — Final Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- Auto Security Updates ---
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Mail "";
EOF

systemctl enable unattended-upgrades --quiet
echo "   ✅ Auto security updates enabled"

# --- NTP Chrony ---
systemctl enable chrony --quiet
systemctl restart chrony
echo "   ✅ NTP time sync active"

# --- APT Cleanup ---
apt-get autoremove --purge -y -qq
apt-get autoclean  -y -qq
apt-get clean      -y -qq
echo "   ✅ APT cache cleaned"

# *** FIX #16 — tee flush ke liye sync ***
sync

# ============================================================
# HEALTH CHECK
# ============================================================
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║         🔍 SYSTEM HEALTH CHECK           ║"
echo "╚══════════════════════════════════════════╝"
echo ""

PASS_COUNT=0
FAIL_COUNT=0

check_svc() {
  local LABEL="$1"
  local SVC="$2"
  if systemctl is-active --quiet "$SVC" 2>/dev/null; then
    printf "   ✅ %-15s — Running\n" "$LABEL"
    PASS_COUNT=$(( PASS_COUNT + 1 ))
  else
    printf "   ❌ %-15s — NOT Running!\n" "$LABEL"
    FAIL_COUNT=$(( FAIL_COUNT + 1 ))
  fi
}

check_svc "SSH"          "ssh"
check_svc "Firewall UFW" "ufw"
check_svc "Fail2Ban"     "fail2ban"
check_svc "XRDP"         "xrdp"
check_svc "Tailscale"    "tailscaled"
check_svc "EarlyOOM"     "earlyoom"
check_svc "Chrony NTP"   "chrony"
check_svc "ZRAM Swap"    "zram-swap"

echo ""
echo "   📊 Resources:"
printf "      RAM   : %s\n" "$(free -h | awk 'NR==2{printf "%s used / %s total", $3, $2}')"
printf "      Disk  : %s\n" "$(df -h / | awk 'NR==2{printf "%s used / %s total", $3, $2}')"
printf "      Swap  : %s\n" "$(swapon --show --noheadings 2>/dev/null | awk '{printf "%s (%s)", $1, $3}' | tr '\n' ' ' || echo 'None')"

TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "Auth pending")
printf "      TS IP : %s\n" "$TAILSCALE_IP"

echo ""
printf "   Score: %d passed | %d failed\n" "$PASS_COUNT" "$FAIL_COUNT"

# ============================================================
# COMPLETION SUMMARY
# ============================================================
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║        ✅  SETUP COMPLETE!               ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "   👤 Username  : aman"
echo "   🔑 Password  : password"
echo "   🌐 RDP Port  : 3389 (Tailscale only)"
echo "   📝 Log File  : $LOG_FILE"
echo ""
echo "   ══════════════════════════════════════"
echo "   📋 NEXT STEPS:"
echo "   ══════════════════════════════════════"
echo ""
echo "   1️⃣  Tailscale auth karo:"
echo "       tailscale up"
echo "       (URL browser mein kholo)"
echo ""
echo "   2️⃣  Tailscale IP nikalo:"
echo "       tailscale ip -4"
echo ""
echo "   3️⃣  RDP connect karo:"
echo "       PC Name : <tailscale-ip>:3389"
echo "       Username: aman"
echo "       Password: password"
echo ""
echo "   4️⃣  VPS reboot karo (neeche press karo)"
echo "   ══════════════════════════════════════"
echo ""

# *** FIX #17 — read timeout safe with set -euo pipefail ***
REBOOT_NOW="n"
read -r -t 30 -p "   🔄 Abhi reboot karein? [y/N] (30s auto-skip): " \
  REBOOT_NOW 2>/dev/null || REBOOT_NOW="n"
echo ""

if [[ "${REBOOT_NOW}" =~ ^[Yy]$ ]]; then
  echo "   🔄 Rebooting in 5 seconds... (Ctrl+C se rok sakte ho)"
  sleep 5
  reboot
else
  echo "   ℹ️  Jab ready ho: sudo reboot"
  echo ""
fi
