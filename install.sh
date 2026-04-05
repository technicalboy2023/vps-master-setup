#!/bin/bash
# ==============================================================
#  VPS MASTER SETUP — FIXED & FUTURE-PROOF
#  Version : 2.0.0
#  Author  : Aman (technicalboy2023)
#  Supports: Ubuntu 22.04 LTS | amd64 + ARM64
#  Providers: DigitalOcean, Linode, Vultr, Hetzner, OVH,
#             Contabo, Oracle Cloud, AWS, GCP, Azure
# ==============================================================

set -euo pipefail

# --------------------------------------------------------------
# LOG SETUP — every output goes to screen AND log file
# BUG FIX: No log file existed before — debug was impossible
# --------------------------------------------------------------
LOG_FILE="/var/log/vps-master-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "================================================="
echo "  VPS MASTER SETUP v2.0 STARTING"
echo "  Log: $LOG_FILE"
echo "  Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================="

# --------------------------------------------------------------
# ROOT CHECK
# --------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Please run as root: sudo bash install.sh"
    exit 1
fi

# --------------------------------------------------------------
# UBUNTU VERSION CHECK
# BUG FIX: Script was running blindly on any OS/version
# --------------------------------------------------------------
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" != "ubuntu" ]; then
        echo "[ERROR] This script only supports Ubuntu. Detected: $ID"
        exit 1
    fi
    if [ "$VERSION_ID" != "22.04" ]; then
        echo "[WARNING] Script is tested on Ubuntu 22.04. Detected: $VERSION_ID"
        echo "[WARNING] Continuing in 5 seconds... (Ctrl+C to abort)"
        sleep 5
    fi
else
    echo "[WARNING] Cannot detect OS version. Continuing anyway..."
fi

# --------------------------------------------------------------
# ARCHITECTURE DETECTION
# BUG FIX: Chrome was hardcoded to amd64, ARM64 always failed
# --------------------------------------------------------------
ARCH=$(dpkg --print-architecture)
MACHINE=$(uname -m)
echo "[INFO] Architecture: $ARCH ($MACHINE)"

# --------------------------------------------------------------
# TIMEZONE
# --------------------------------------------------------------
echo ""
echo "[1/14] Setting timezone to Asia/Kolkata..."
timedatectl set-timezone Asia/Kolkata 2>/dev/null || echo "[WARN] Timezone set failed, continuing"

# --------------------------------------------------------------
# FIX APT MIRRORS — ALL providers, not just Linode
# BUG FIX: Old code only replaced mirrors.linode.com
#          DigitalOcean/Vultr/Hetzner/others were untouched
# --------------------------------------------------------------
echo ""
echo "[2/14] Fixing APT mirrors (all providers → archive.ubuntu.com)..."
if [ -f /etc/apt/sources.list ]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
    # Replace any provider-specific mirror with official Ubuntu archive
    sed -i \
        -e 's|http://mirrors\.linode\.com|http://archive.ubuntu.com|g' \
        -e 's|http://mirrors\.digitalocean\.com|http://archive.ubuntu.com|g' \
        -e 's|http://mirrors\.vultr\.com|http://archive.ubuntu.com|g' \
        -e 's|http://mirror\.hetzner\.com|http://archive.ubuntu.com|g' \
        -e 's|http://mirror\.contabo\.com|http://archive.ubuntu.com|g' \
        -e 's|http://[a-z0-9.-]*\.ec2\.archive\.ubuntu\.com|http://archive.ubuntu.com|g' \
        -e 's|http://[a-z][a-z]\.archive\.ubuntu\.com|http://archive.ubuntu.com|g' \
        /etc/apt/sources.list
    echo "[INFO] APT sources updated."
fi

# --------------------------------------------------------------
# SYSTEM UPDATE
# --------------------------------------------------------------
echo ""
echo "[3/14] Updating system packages..."
apt-get update -qq || { echo "[WARN] apt update had issues, continuing..."; }
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    || echo "[WARN] Upgrade had some issues, continuing..."

# --------------------------------------------------------------
# BASE PACKAGES
# --------------------------------------------------------------
echo ""
echo "[4/14] Installing base packages..."
BASE_PKGS=(curl wget git nano htop ufw fail2ban gnupg
           software-properties-common openssl tmux net-tools
           network-manager-gnome)
# BUG FIX: network-manager-gnome was in README but never installed

for pkg in "${BASE_PKGS[@]}"; do
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg" 2>/dev/null \
        || echo "[WARN] $pkg skipped"
done

# Enable fail2ban
if systemctl list-unit-files 2>/dev/null | grep -q fail2ban; then
    systemctl enable fail2ban 2>/dev/null || true
    systemctl start  fail2ban 2>/dev/null || true
fi

# --------------------------------------------------------------
# FIREWALL SETUP
# --------------------------------------------------------------
echo ""
echo "[5/14] Configuring UFW firewall..."
if command -v ufw &>/dev/null; then
    ufw allow OpenSSH 2>/dev/null || true
    echo "y" | ufw enable 2>/dev/null || true
    echo "[INFO] UFW enabled — SSH allowed."
fi

# --------------------------------------------------------------
# CREATE ADMIN USER WITH SECURE RANDOM PASSWORD
# BUG FIX: "aman:password" hardcoded was a critical security hole
# --------------------------------------------------------------
echo ""
echo "[6/14] Creating admin user: aman"

# Ask user to enter password manually (hidden input, confirmed)
while true; do
    echo ""
    read -rsp "  Enter password for user 'aman': " USER_PASS
    echo ""
    if [ -z "$USER_PASS" ]; then
        echo "[ERROR] Password cannot be empty. Try again."
        continue
    fi
    if [ "${#USER_PASS}" -lt 8 ]; then
        echo "[ERROR] Password must be at least 8 characters. Try again."
        continue
    fi
    read -rsp "  Confirm password: " USER_PASS_CONFIRM
    echo ""
    if [ "$USER_PASS" != "$USER_PASS_CONFIRM" ]; then
        echo "[ERROR] Passwords do not match. Try again."
        continue
    fi
    break
done
GENERATED_PASS="$USER_PASS"

if id "aman" &>/dev/null; then
    echo "[INFO] User 'aman' already exists — updating password."
    echo "aman:${GENERATED_PASS}" | chpasswd || { echo "[ERROR] Password set failed"; exit 1; }
else
    useradd -m -s /bin/bash aman || { echo "[ERROR] User creation failed"; exit 1; }
    echo "aman:${GENERATED_PASS}" | chpasswd || { echo "[ERROR] Password set failed"; exit 1; }
    echo "[INFO] User 'aman' created."
fi

usermod -aG sudo aman 2>/dev/null || true
echo "[INFO] Password set successfully."

# --------------------------------------------------------------
# SSH HARDENING
# BUG FIX: Removed deprecated 'Compression yes' (OpenSSH 8.x+)
# BUG FIX: Used drop-in config (already good, kept it)
# --------------------------------------------------------------
echo ""
echo "[7/14] Hardening SSH..."

mkdir -p /etc/ssh/sshd_config.d

# Drop-in file: safer than editing sshd_config directly
cat > /etc/ssh/sshd_config.d/01-vps-hardening.conf <<'EOF'
# VPS Master Setup — SSH Hardening
PermitRootLogin no
UseDNS no
LoginGraceTime 30
MaxAuthTries 3
X11Forwarding no
EOF
# NOTE: 'Compression yes' intentionally removed — deprecated in OpenSSH 8.x+

systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
echo "[INFO] SSH hardened."

# --------------------------------------------------------------
# XFCE DESKTOP ENVIRONMENT
# --------------------------------------------------------------
echo ""
echo "[8/14] Installing XFCE desktop..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    xfce4 xfce4-goodies xfce4-session \
    2>/dev/null || {
    echo "[WARN] XFCE install had issues, trying with --fix-missing..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y --fix-missing \
        xfce4 xfce4-goodies xfce4-session 2>/dev/null || echo "[WARN] XFCE install skipped"
}

# .xsession for user and skel (black screen fix)
if [ -d /home/aman ]; then
    echo "startxfce4" > /home/aman/.xsession
    chown aman:aman /home/aman/.xsession
    chmod 644 /home/aman/.xsession
fi
echo "startxfce4" > /etc/skel/.xsession
echo "[INFO] XFCE installed."

# --------------------------------------------------------------
# XRDP
# --------------------------------------------------------------
echo ""
echo "[9/14] Installing and configuring XRDP..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq xrdp 2>/dev/null \
    || echo "[WARN] XRDP install failed"

if systemctl list-unit-files 2>/dev/null | grep -q xrdp; then
    # Add aman to ssl-cert group (needed for XRDP certs)
    usermod -aG ssl-cert aman 2>/dev/null || true
    systemctl enable xrdp 2>/dev/null || true
    systemctl restart xrdp 2>/dev/null || true
fi

# XRDP performance: 24-bit color = 2x faster than 32-bit
if [ -f /etc/xrdp/xrdp.ini ]; then
    sed -i 's/max_bpp=32/max_bpp=24/' /etc/xrdp/xrdp.ini 2>/dev/null || true
    systemctl restart xrdp 2>/dev/null || true
fi

# Block public RDP — Tailscale-only access
if command -v ufw &>/dev/null; then
    ufw deny 3389/tcp 2>/dev/null || true
    echo "[INFO] RDP port 3389 blocked publicly (Tailscale only)."
fi

# --------------------------------------------------------------
# SWAP CONFIGURATION — DYNAMIC SIZE BASED ON RAM
# BUG FIX 1: Fixed systemd service with multiple ExecStart
# BUG FIX 2: Removed zram-config package (conflicts with manual setup)
# BUG FIX 3: Swap size is now dynamic — not hardcoded 2GB
# --------------------------------------------------------------
echo ""
echo "[10/14] Configuring swap..."

# Calculate swap size: 2x RAM, min 1GB, max 4GB
RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
SWAP_MB=$(( RAM_KB * 2 / 1024 ))
[ "$SWAP_MB" -lt 1024 ] && SWAP_MB=1024
[ "$SWAP_MB" -gt 4096 ] && SWAP_MB=4096
SWAP_BYTES=$(( SWAP_MB * 1024 * 1024 ))
echo "[INFO] RAM: $((RAM_KB/1024))MB → Setting swap: ${SWAP_MB}MB"

# -- ZRAM (compressed RAM swap) --
echo "Setting up ZRAM..."
# Install only the kernel module — NOT zram-config package (conflicts!)
KERNEL_VER=$(uname -r)
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    "linux-modules-extra-${KERNEL_VER}" 2>/dev/null || true

if modprobe zram 2>/dev/null; then
    if [ -b /dev/zram0 ]; then
        swapoff /dev/zram0 2>/dev/null || true
        echo 1 > /sys/block/zram0/reset 2>/dev/null || true
    fi

    if echo "$SWAP_BYTES" > /sys/block/zram0/disksize 2>/dev/null; then
        mkswap /dev/zram0 2>/dev/null
        swapon /dev/zram0 -p 10 2>/dev/null && echo "[INFO] ZRAM swap active: ${SWAP_MB}MB"
        echo "zram" > /etc/modules-load.d/zram.conf

        # BUG FIX: Multiple ExecStart is invalid in systemd.
        # Fixed: All steps combined into ONE ExecStart with bash -c
        cat > /etc/systemd/system/zram-swap.service <<EOF
[Unit]
Description=ZRAM swap setup
After=local-fs.target
Before=swap.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c '\
    modprobe zram && \
    swapoff /dev/zram0 2>/dev/null || true; \
    echo 1 > /sys/block/zram0/reset 2>/dev/null || true; \
    echo ${SWAP_BYTES} > /sys/block/zram0/disksize && \
    mkswap /dev/zram0 && \
    swapon /dev/zram0 -p 10'
ExecStop=/bin/bash -c 'swapoff /dev/zram0 2>/dev/null || true'

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload 2>/dev/null || true
        systemctl enable zram-swap.service 2>/dev/null || true
        echo "[INFO] ZRAM systemd service created (single ExecStart — fixed)."
    else
        echo "[WARN] ZRAM disksize set failed — using traditional swap only."
    fi
else
    echo "[WARN] ZRAM module not available — using traditional swap only."
fi

# -- Traditional swapfile --
if [ ! -f /swapfile ]; then
    echo "Creating traditional swapfile (${SWAP_MB}MB)..."
    if fallocate -l "${SWAP_MB}M" /swapfile 2>/dev/null \
        || dd if=/dev/zero of=/swapfile bs=1M count="${SWAP_MB}" status=none 2>/dev/null; then
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        grep -q "^/swapfile" /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
        echo "[INFO] Swapfile created: ${SWAP_MB}MB"
    else
        echo "[WARN] Swapfile creation failed."
    fi
else
    echo "[INFO] Swapfile already exists — skipping."
fi

# --------------------------------------------------------------
# KERNEL / SYSCTL OPTIMIZATIONS
# BUG FIX: vm.overcommit_memory=1 was dangerous on low RAM VPS
#          Changed to 0 (default safe — heuristic overcommit)
# BUG FIX: No duplicate-safe approach — now uses tmp file + replace
# --------------------------------------------------------------
echo ""
echo "[11/14] Applying kernel optimizations..."

SYSCTL_CONF="/etc/sysctl.d/99-vps-tuning.conf"
cat > "$SYSCTL_CONF" <<'EOF'
# VPS Master Setup — Kernel tuning
# vm.swappiness: prefer RAM, use swap only when needed
vm.swappiness=10
# vm.overcommit_memory: 0 = safe heuristic (was 1 = always overcommit, dangerous!)
vm.overcommit_memory=0
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.dirty_expire_centisecs=500
vm.dirty_writeback_centisecs=100
# Network performance
net.core.rmem_max=134217728
net.core.wmem_max=134217728
# Protect against SYN flood attacks
net.ipv4.tcp_syncookies=1
net.ipv4.conf.all.rp_filter=1
EOF

sysctl -p "$SYSCTL_CONF" 2>/dev/null || echo "[WARN] sysctl apply failed — will apply on reboot"
echo "[INFO] Kernel tuning applied."

# --------------------------------------------------------------
# SOFTWARE RENDERING (for GPU-less VPS)
# BUG FIX: /etc/environment must NOT use 'export' keyword
#          PAM reads it as plain key=value — export is invalid here
# --------------------------------------------------------------
echo ""
echo "[12/14] Enabling software rendering..."

ENV_FILE="/etc/environment"
# Remove any old broken entry (with or without export)
sed -i '/LIBGL_ALWAYS_SOFTWARE/d' "$ENV_FILE" 2>/dev/null || true
# Add correct format — NO 'export' keyword
echo "LIBGL_ALWAYS_SOFTWARE=1" >> "$ENV_FILE"
echo "[INFO] LIBGL_ALWAYS_SOFTWARE=1 set in /etc/environment (no export — fixed)."

# --------------------------------------------------------------
# BROWSERS
# BUG FIX: Chrome was hardcoded to amd64 — ARM64 always failed
#          Now detects arch: amd64=Chrome, arm64=Chromium
# --------------------------------------------------------------
echo ""
echo "[13/14] Installing browsers..."

# -- Remove Snap Firefox first --
echo "Removing Snap Firefox..."
snap remove firefox 2>/dev/null || true
DEBIAN_FRONTEND=noninteractive apt-get remove -y -qq firefox 2>/dev/null || true
DEBIAN_FRONTEND=noninteractive apt-get purge  -y -qq firefox 2>/dev/null || true
DEBIAN_FRONTEND=noninteractive apt-get autoremove -y -qq 2>/dev/null || true

# -- Install Firefox from Mozilla official repo --
echo "Installing Firefox (Mozilla official)..."
install -d -m 0755 /etc/apt/keyrings

if wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg \
        -O /tmp/mozilla-key.gpg 2>/dev/null; then
    gpg --dearmor < /tmp/mozilla-key.gpg > /etc/apt/keyrings/mozilla.gpg 2>/dev/null
    rm -f /tmp/mozilla-key.gpg
    echo "deb [signed-by=/etc/apt/keyrings/mozilla.gpg] https://packages.mozilla.org/apt mozilla main" \
        > /etc/apt/sources.list.d/mozilla.list
    cat > /etc/apt/preferences.d/mozilla <<'EOF'
Package: firefox*
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF
    apt-get update -qq 2>/dev/null || true
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq firefox \
        2>/dev/null && echo "[INFO] Firefox installed." \
        || echo "[WARN] Firefox install failed."
else
    echo "[WARN] Could not reach Mozilla repo — Firefox skipped."
fi

# -- Install browser by architecture --
if [ "$ARCH" = "amd64" ]; then
    # Google Chrome — amd64 only
    echo "Installing Google Chrome (amd64)..."
    if wget -q -O - https://dl.google.com/linux/linux_signing_key.pub 2>/dev/null \
            | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg 2>/dev/null; then
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] \
https://dl.google.com/linux/chrome/deb/ stable main" \
            > /etc/apt/sources.list.d/google-chrome.list
        apt-get update -qq 2>/dev/null || true
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq google-chrome-stable \
            2>/dev/null && echo "[INFO] Google Chrome installed." \
            || echo "[WARN] Chrome install failed."
    else
        echo "[WARN] Could not reach Google repo — Chrome skipped."
    fi
else
    # ARM64 — Google Chrome doesn't exist, use Chromium
    echo "[INFO] ARM64 detected — installing Chromium (Chrome not available on ARM)..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq chromium-browser \
        2>/dev/null && echo "[INFO] Chromium installed (ARM64)." \
        || echo "[WARN] Chromium install failed."
fi

# --------------------------------------------------------------
# TAILSCALE VPN
# BUG FIX: Auth URL was being sent to /dev/null — user never saw it!
#          Now supports TS_AUTH_KEY env var for unattended setup
# --------------------------------------------------------------
echo ""
echo "[14/14] Installing Tailscale..."

if curl -fsSL https://tailscale.com/install.sh 2>/dev/null | sh 2>/dev/null; then
    systemctl enable tailscaled 2>/dev/null || true
    systemctl start  tailscaled 2>/dev/null || true

    # BUG FIX: Previously `nohup tailscale up > /dev/null 2>&1 &`
    # Auth URL was hidden. Now:
    # - If TS_AUTH_KEY env var is set → unattended auth (CI/automation use)
    # - Otherwise → run in foreground so user sees the auth URL
    if [ -n "${TS_AUTH_KEY:-}" ]; then
        echo "[INFO] Using TS_AUTH_KEY for unattended Tailscale auth..."
        tailscale up --authkey "$TS_AUTH_KEY" --accept-routes 2>/dev/null \
            && echo "[INFO] Tailscale authenticated!" \
            || echo "[WARN] Tailscale auth failed — run 'tailscale up' manually."
    else
        echo ""
        echo "========================================================"
        echo "  ACTION REQUIRED: Authenticate Tailscale"
        echo "  Open the URL below in your browser:"
        echo "========================================================"
        # Run in foreground — user MUST see the auth URL
        tailscale up 2>&1 || true
        echo "========================================================"
    fi
else
    echo "[WARN] Tailscale install script failed."
fi

# --------------------------------------------------------------
# FINAL CLEANUP
# --------------------------------------------------------------
echo ""
echo "Running final cleanup..."
DEBIAN_FRONTEND=noninteractive apt-get autoremove -y -qq 2>/dev/null || true
DEBIAN_FRONTEND=noninteractive apt-get autoclean -y   2>/dev/null || true

# --------------------------------------------------------------
# SUMMARY
# --------------------------------------------------------------
echo ""
echo "========================================================="
echo "  VPS MASTER SETUP COMPLETE"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================================="
echo ""
echo "  User     : aman"
echo "  Password : (as entered by you during setup)"
echo ""
echo "  SECURITY REMINDERS:"
echo "  1. Set up SSH key auth: ssh-copy-id aman@<tailscale-ip>"
echo "  2. Disable password SSH after keys: PasswordAuthentication no"
echo ""
echo "  NEXT STEPS:"
echo "  1. Get Tailscale IP : tailscale ip -4"
echo "  2. Connect RDP      : <tailscale-ip>:3389"
echo "  3. Login with       : aman / (password above)"
echo "  4. Reboot VPS       : reboot"
echo ""
echo "  Full log : $LOG_FILE"
echo "========================================================="
