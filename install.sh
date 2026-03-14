#!/bin/bash

set -e

# Root check
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit
fi

echo "================================="
echo " VPS MASTER SETUP STARTING"
echo " Ubuntu 22.04"
echo "================================="

# ------------------------------
# Timezone
# ------------------------------
echo "Setting timezone..."
timedatectl set-timezone Asia/Kolkata

# ------------------------------
# Fix mirror
# ------------------------------
echo "Fixing apt mirror..."
sed -i 's|mirrors.linode.com|archive.ubuntu.com|g' /etc/apt/sources.list || true

# ------------------------------
# Update system
# ------------------------------
echo "Updating system..."
apt update
apt upgrade -y

# ------------------------------
# Install dependencies
# ------------------------------
echo "Installing base packages..."
apt install -y curl wget git nano htop ufw fail2ban gnupg software-properties-common

systemctl enable fail2ban
systemctl start fail2ban

# ------------------------------
# Firewall setup
# ------------------------------
echo "Configuring firewall..."
ufw allow OpenSSH
ufw --force enable

# ------------------------------
# Create user aman
# ------------------------------
echo "Creating admin user: aman"

if id "aman" &>/dev/null; then
    echo "User aman already exists"
else
    adduser aman
fi

usermod -aG sudo aman

# ------------------------------
# Disable root SSH login
# ------------------------------
echo "Disabling root SSH login..."

mkdir -p /etc/ssh/sshd_config.d

echo "PermitRootLogin no" > /etc/ssh/sshd_config.d/01-permitrootlogin.conf

grep -q "UseDNS no" /etc/ssh/sshd_config || echo "UseDNS no" >> /etc/ssh/sshd_config
grep -q "Compression yes" /etc/ssh/sshd_config || echo "Compression yes" >> /etc/ssh/sshd_config

systemctl restart ssh

# ------------------------------
# Install XFCE desktop
# ------------------------------
echo "Installing XFCE desktop..."

apt install -y xfce4 xfce4-goodies

echo "startxfce4" > /home/aman/.xsession
chown aman:aman /home/aman/.xsession
chmod 644 /home/aman/.xsession

# ------------------------------
# Install XRDP
# ------------------------------
echo "Installing XRDP..."

apt install -y xrdp
systemctl enable xrdp
systemctl restart xrdp

# ------------------------------
# Secure XRDP
# ------------------------------
echo "Blocking public RDP port..."
ufw deny 3389/tcp || true

# ------------------------------
# Create Swap (only if missing)
# ------------------------------
echo "Configuring swap..."

if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# ------------------------------
# RAM Optimization
# ------------------------------
echo "Applying RAM optimizations..."

echo "vm.swappiness=10" >> /etc/sysctl.conf
echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
echo "vm.dirty_ratio=10" >> /etc/sysctl.conf
echo "vm.dirty_background_ratio=5" >> /etc/sysctl.conf

sysctl -p

# ------------------------------
# XRDP Performance Optimization
# ------------------------------
echo "Optimizing XRDP..."

sed -i 's/max_bpp=32/max_bpp=24/' /etc/xrdp/xrdp.ini || true

systemctl restart xrdp

# ------------------------------
# Enable software rendering
# ------------------------------
echo "Enabling software rendering..."

echo "export LIBGL_ALWAYS_SOFTWARE=1" >> /etc/environment

# ------------------------------
# Remove Firefox Snap
# ------------------------------
echo "Removing snap Firefox..."

apt remove firefox -y || true
apt purge firefox -y || true
snap remove firefox || true
apt autoremove -y

# ------------------------------
# Install Firefox (Mozilla repo)
# ------------------------------
echo "Installing Firefox..."

install -d -m 0755 /etc/apt/keyrings

wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg
gpg --dearmor repo-signing-key.gpg
mv repo-signing-key.gpg.gpg /etc/apt/keyrings/mozilla.gpg

echo "deb [signed-by=/etc/apt/keyrings/mozilla.gpg] https://packages.mozilla.org/apt mozilla main" > /etc/apt/sources.list.d/mozilla.list

echo -e "Package: firefox*\nPin: origin packages.mozilla.org\nPin-Priority: 1000" > /etc/apt/preferences.d/mozilla

apt update
apt install firefox --allow-downgrades -y

# ------------------------------
# Install Google Chrome
# ------------------------------
echo "Installing Google Chrome..."

wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg

echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list

apt update
apt install google-chrome-stable -y

# ------------------------------
# Monitoring tools
# ------------------------------
echo "Installing monitoring tools..."

apt install -y htop

# ------------------------------
# Install Tailscale
# ------------------------------
echo "Installing Tailscale..."

curl -fsSL https://tailscale.com/install.sh | sh

# ------------------------------
# Finish
# ------------------------------
echo "================================="
echo " VPS SETUP COMPLETE"
echo "================================="
echo "User: aman"
echo "Password: (the one you created)"
echo ""
echo "Next steps:"
echo "1. Run: tailscale up"
echo "2. Connect RDP via tailscale IP"
echo "3. Reboot manually when ready"
echo "================================="
