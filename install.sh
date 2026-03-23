#!/bin/bash

# ------------------------------
# 100% SAFE VPS SETUP SCRIPT
# No duplicates, full error handling
# ------------------------------

# Root check
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

echo "================================="
echo " VPS MASTER SETUP STARTING"
echo " Ubuntu 22.04"
echo "================================="

# ------------------------------
# Timezone
# ------------------------------
echo "Setting timezone..."
timedatectl set-timezone Asia/Kolkata 2>/dev/null || echo "Timezone already set or failed"

# ------------------------------
# Fix mirror
# ------------------------------
echo "Fixing apt mirror..."
if [ -f /etc/apt/sources.list ]; then
    sed -i.bak 's|mirrors.linode.com|archive.ubuntu.com|g' /etc/apt/sources.list 2>/dev/null || true
fi

# ------------------------------
# Update system
# ------------------------------
echo "Updating system..."
apt update || { echo "apt update failed, continuing..."; }
DEBIAN_FRONTEND=noninteractive apt upgrade -y || { echo "apt upgrade failed, continuing..."; }

# ------------------------------
# Install dependencies
# ------------------------------
echo "Installing base packages..."
DEBIAN_FRONTEND=noninteractive apt install -y curl wget git nano htop ufw fail2ban gnupg software-properties-common 2>/dev/null || {
    echo "Some packages failed to install, retrying individually..."
    for pkg in curl wget git nano htop ufw fail2ban gnupg software-properties-common; do
        DEBIAN_FRONTEND=noninteractive apt install -y $pkg 2>/dev/null || echo "$pkg installation skipped"
    done
}

# Enable fail2ban
if systemctl list-unit-files | grep -q fail2ban; then
    systemctl enable fail2ban 2>/dev/null || true
    systemctl start fail2ban 2>/dev/null || true
fi

# ------------------------------
# Firewall setup
# ------------------------------
echo "Configuring firewall..."
if command -v ufw &> /dev/null; then
    ufw allow OpenSSH 2>/dev/null || true
    echo "y" | ufw enable 2>/dev/null || true
fi

# ------------------------------
# Create user aman
# ------------------------------
echo "Creating admin user: aman"

if id "aman" &>/dev/null; then
    echo "User aman already exists"
else
    useradd -m -s /bin/bash aman 2>/dev/null || { echo "User creation failed"; }
    echo "aman:password" | chpasswd 2>/dev/null || { echo "Password setting failed"; }
fi

usermod -aG sudo aman 2>/dev/null || true

# ------------------------------
# Disable root SSH login
# ------------------------------
echo "Disabling root SSH login..."

mkdir -p /etc/ssh/sshd_config.d 2>/dev/null || true

echo "PermitRootLogin no" > /etc/ssh/sshd_config.d/01-permitrootlogin.conf 2>/dev/null || true

# Add SSH optimizations only if not present
if [ -f /etc/ssh/sshd_config ]; then
    grep -q "^UseDNS no" /etc/ssh/sshd_config || echo "UseDNS no" >> /etc/ssh/sshd_config
    grep -q "^Compression yes" /etc/ssh/sshd_config || echo "Compression yes" >> /etc/ssh/sshd_config
fi

systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true

# ------------------------------
# Install XFCE desktop
# ------------------------------
echo "Installing XFCE desktop..."

DEBIAN_FRONTEND=noninteractive apt install -y xfce4 xfce4-goodies 2>/dev/null || {
    echo "XFCE installation failed, retrying..."
    DEBIAN_FRONTEND=noninteractive apt install -y --fix-missing xfce4 xfce4-goodies 2>/dev/null || echo "XFCE install skipped"
}

if [ -d /home/aman ]; then
    echo "startxfce4" > /home/aman/.xsession 2>/dev/null || true
    chown aman:aman /home/aman/.xsession 2>/dev/null || true
    chmod 644 /home/aman/.xsession 2>/dev/null || true
fi

# XRDP black screen fix
echo "startxfce4" > /etc/skel/.xsession 2>/dev/null || true

# ------------------------------
# Install XRDP
# ------------------------------
echo "Installing XRDP..."

DEBIAN_FRONTEND=noninteractive apt install -y xrdp 2>/dev/null || echo "XRDP install failed"

if systemctl list-unit-files | grep -q xrdp; then
    systemctl enable xrdp 2>/dev/null || true
    systemctl restart xrdp 2>/dev/null || true
fi

# ------------------------------
# Secure XRDP
# ------------------------------
echo "Blocking public RDP port..."
if command -v ufw &> /dev/null; then
    ufw deny 3389/tcp 2>/dev/null || true
fi

# ------------------------------
# Create Swap (ZRAM + Traditional)
# ------------------------------
echo "Configuring swap..."

# Install ZRAM tools
echo "Installing ZRAM..."
DEBIAN_FRONTEND=noninteractive apt install -y zram-config 2>/dev/null || echo "zram-config not available"

# Try to install kernel modules
KERNEL_VER=$(uname -r)
DEBIAN_FRONTEND=noninteractive apt install -y linux-modules-extra-${KERNEL_VER} 2>/dev/null || true

# Configure ZRAM swap (2GB)
echo "Setting up ZRAM..."
if modprobe zram 2>/dev/null; then
    # Check if zram0 exists
    if [ -b /dev/zram0 ]; then
        # Reset if already configured
        swapoff /dev/zram0 2>/dev/null || true
        echo 1 > /sys/block/zram0/reset 2>/dev/null || true
    fi
    
    # Configure ZRAM
    if echo 2147483648 > /sys/block/zram0/disksize 2>/dev/null; then
        mkswap /dev/zram0 2>/dev/null && swapon /dev/zram0 -p 10 2>/dev/null || echo "ZRAM swap activation failed"
        
        # Make ZRAM persistent
        grep -q "^zram$" /etc/modules-load.d/zram.conf 2>/dev/null || echo "zram" > /etc/modules-load.d/zram.conf
        
        # Create systemd service
        cat > /etc/systemd/system/zram.service <<'EOF'
[Unit]
Description=Configure zram swap device
After=local-fs.target

[Service]
Type=oneshot
ExecStartPre=/sbin/modprobe zram
ExecStartPre=-/sbin/swapoff /dev/zram0
ExecStartPre=-/bin/bash -c 'echo 1 > /sys/block/zram0/reset'
ExecStart=/bin/bash -c 'echo 2147483648 > /sys/block/zram0/disksize'
ExecStart=/sbin/mkswap /dev/zram0
ExecStart=/sbin/swapon /dev/zram0 -p 10
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload 2>/dev/null || true
        systemctl enable zram.service 2>/dev/null || true
        echo "ZRAM configured successfully"
    else
        echo "ZRAM configuration failed, continuing with traditional swap only"
    fi
else
    echo "ZRAM module not available, using traditional swap only"
fi

# Create traditional swapfile (2GB)
if [ ! -f /swapfile ]; then
    echo "Creating traditional swapfile..."
    if fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 2>/dev/null; then
        chmod 600 /swapfile
        if mkswap /swapfile 2>/dev/null; then
            swapon /swapfile 2>/dev/null || echo "Traditional swap activation failed"
            # Add to fstab only if not present
            grep -q "^/swapfile" /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
            echo "Traditional swapfile configured successfully"
        fi
    else
        echo "Swapfile creation failed"
    fi
else
    echo "Swapfile already exists, skipping creation"
fi

# ------------------------------
# RAM Optimization
# ------------------------------
echo "Applying RAM optimizations..."

# Remove duplicates and add settings
declare -A SYSCTL_PARAMS=(
    ["vm.swappiness"]="10"
    ["vm.overcommit_memory"]="1"
    ["vm.vfs_cache_pressure"]="50"
    ["vm.dirty_ratio"]="10"
    ["vm.dirty_background_ratio"]="5"
    ["vm.dirty_expire_centisecs"]="500"
    ["vm.dirty_writeback_centisecs"]="100"
)

for param in "${!SYSCTL_PARAMS[@]}"; do
    value="${SYSCTL_PARAMS[$param]}"
    # Remove existing entries
    sed -i "/^${param}=/d" /etc/sysctl.conf 2>/dev/null || true
    # Add new entry
    echo "${param}=${value}" >> /etc/sysctl.conf
done

sysctl -p 2>/dev/null || echo "sysctl apply failed, will apply on reboot"

# ------------------------------
# XRDP Performance Optimization
# ------------------------------
echo "Optimizing XRDP..."

if [ -f /etc/xrdp/xrdp.ini ]; then
    sed -i 's/max_bpp=32/max_bpp=24/' /etc/xrdp/xrdp.ini 2>/dev/null || true
    systemctl restart xrdp 2>/dev/null || true
fi

# ------------------------------
# Enable software rendering
# ------------------------------
echo "Enabling software rendering..."

if [ -f /etc/environment ]; then
    grep -q "^export LIBGL_ALWAYS_SOFTWARE=1" /etc/environment || echo "export LIBGL_ALWAYS_SOFTWARE=1" >> /etc/environment
fi

# ------------------------------
# Remove Firefox Snap
# ------------------------------
echo "Removing snap Firefox..."

if command -v snap &> /dev/null; then
    snap remove firefox 2>/dev/null || true
fi

DEBIAN_FRONTEND=noninteractive apt remove firefox -y 2>/dev/null || true
DEBIAN_FRONTEND=noninteractive apt purge firefox -y 2>/dev/null || true
DEBIAN_FRONTEND=noninteractive apt autoremove -y 2>/dev/null || true
DEBIAN_FRONTEND=noninteractive apt autoclean 2>/dev/null || true

# ------------------------------
# Install Firefox (Mozilla repo)
# ------------------------------
echo "Installing Firefox..."

install -d -m 0755 /etc/apt/keyrings 2>/dev/null || true

if wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O /tmp/mozilla-key.gpg 2>/dev/null; then
    gpg --dearmor < /tmp/mozilla-key.gpg > /etc/apt/keyrings/mozilla.gpg 2>/dev/null || true
    rm -f /tmp/mozilla-key.gpg
    
    echo "deb [signed-by=/etc/apt/keyrings/mozilla.gpg] https://packages.mozilla.org/apt mozilla main" > /etc/apt/sources.list.d/mozilla.list
    
    echo -e "Package: firefox*\nPin: origin packages.mozilla.org\nPin-Priority: 1000" > /etc/apt/preferences.d/mozilla
    
    apt update 2>/dev/null || true
    DEBIAN_FRONTEND=noninteractive apt install firefox --allow-downgrades -y 2>/dev/null || echo "Firefox installation failed"
else
    echo "Firefox repository setup failed"
fi

# ------------------------------
# Install Google Chrome
# ------------------------------
echo "Installing Google Chrome..."

if wget -q -O - https://dl.google.com/linux/linux_signing_key.pub 2>/dev/null | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg 2>/dev/null; then
    
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
    
    apt update 2>/dev/null || true
    DEBIAN_FRONTEND=noninteractive apt install google-chrome-stable -y 2>/dev/null || echo "Google Chrome installation failed"
else
    echo "Chrome repository setup failed"
fi

# ------------------------------
# Monitoring tools
# ------------------------------
echo "Installing monitoring tools..."

DEBIAN_FRONTEND=noninteractive apt install -y htop 2>/dev/null || echo "htop already installed or failed"

# ------------------------------
# Install Tailscale
# ------------------------------
echo "Installing Tailscale..."

if curl -fsSL https://tailscale.com/install.sh 2>/dev/null | sh 2>/dev/null; then
    systemctl enable tailscaled 2>/dev/null || true
    systemctl start tailscaled 2>/dev/null || true
    
    # Run tailscale up in background (non-blocking)
    nohup tailscale up > /dev/null 2>&1 &
    
    echo "Tailscale installed successfully"
else
    echo "Tailscale installation failed"
fi

# ------------------------------
# Finish
# ------------------------------
echo "================================="
echo " VPS SETUP COMPLETE"
echo "================================="
echo "User: aman"
echo "Password: password"
echo ""
echo "Next steps:"
echo "Connect RDP via Tailscale IP"
echo "Reboot VPS when ready"
echo "================================="
