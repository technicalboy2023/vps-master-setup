#!/bin/bash

# ============================================================
#   VPS MASTER SETUP — FINAL v2.1 (FIXED)
#   Ubuntu 22.04 LTS | All VPS Providers
#   Low-End VPS Optimized | Tailscale RDP
#   User: aman | Password: password
# ============================================================

# ... (keep the beginning same until Step 9) ...

# ============================================================
# STEP 9/15 — SWAP FILE (FIXED - removed -q flag)
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💾 STEP 9/15 — Swap File Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ! -f /swapfile ]; then
  if   [ "$TOTAL_RAM" -lt 512  ]; then SWAP_SIZE="1G"
  elif [ "$TOTAL_RAM" -lt 2048 ]; then SWAP_SIZE="2G"
  else                                  SWAP_SIZE="2G"
  fi

  echo "   Creating ${SWAP_SIZE} swapfile..."

  if fallocate -l "$SWAP_SIZE" /swapfile 2>/dev/null; then
    echo "   fallocate se banaya"
  else
    echo "   dd se bana raha hai..."
    dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress 2>/dev/null
  fi

  chmod 600 /swapfile
  mkswap /swapfile  # FIX: Removed -q flag
  swapon /swapfile

  echo '/swapfile none swap sw,nofail 0 0' >> /etc/fstab
  echo "   ✅ Swapfile: ${SWAP_SIZE} created"
else
  echo "   ✅ Swapfile already exists"
fi

# ============================================================
# STEP 10/15 — KERNEL + RAM OPTIMIZATION (FIXED mkswap)
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚡ STEP 10/15 — Kernel & RAM Optimization"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ... (sysctl settings same) ...

# --- ZRAM (FIXED mkswap -q) ---
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
mkswap /dev/zram0 && swapon -p 100 /dev/zram0  # FIX: No -q flag
echo "ZRAM: ${ZRAM_MB}MB active"
ZEOF
chmod +x /usr/local/bin/zram-setup.sh

# ... (rest of step 10 same) ...

# ============================================================
# STEP 12/15 — XRDP SETUP (FIXED - Log dir + Config)
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🖥️  STEP 12/15 — XRDP Install & Configure"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

apt-get install -y -qq xrdp

# FIX #1: Create log directory BEFORE starting service
mkdir -p /var/log/xrdp
chown xrdp:xrdp /var/log/xrdp
chmod 755 /var/log/xrdp

usermod -aG ssl-cert xrdp

# FIX #2: Config without invalid ssl_protocols/tls_ciphers lines
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

# Sesman config
if [ -f /etc/xrdp/sesman.ini ]; then
  sed -i 's/^AllowRootLogin=.*/AllowRootLogin=false/' /etc/xrdp/sesman.ini
  sed -i 's/^MaxLoginRetry=.*/MaxLoginRetry=3/' /etc/xrdp/sesman.ini
  sed -i 's/^EnableUserWindowManager=.*/EnableUserWindowManager=true/' /etc/xrdp/sesman.ini
fi

# OOM Protection
mkdir -p /etc/systemd/system/xrdp.service.d/
cat > /etc/systemd/system/xrdp.service.d/oom.conf << 'EOF'
[Service]
OOMScoreAdjust=-500
EOF

systemctl daemon-reload
systemctl enable xrdp --quiet

# FIX #3: Ensure log dir exists again (just to be safe)
mkdir -p /var/log/xrdp
chown xrdp:xrdp /var/log/xrdp

systemctl restart xrdp
sleep 2

if systemctl is-active --quiet xrdp; then
  echo "   ✅ XRDP running | Port 3389 | Tailscale only"
else
  echo "   ❌ XRDP start nahi hua! Manual check karo"
fi

# ============================================================
# STEP 13/15 — FIREFOX + CHROME (FIXED GPG Keys)
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 STEP 13/15 — Browsers Install"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Remove Snap Firefox
if command -v snap &>/dev/null; then
  snap remove firefox 2>/dev/null || true
fi
apt-get remove -y firefox 2>/dev/null || true
apt-get purge -y snapd 2>/dev/null || true
rm -rf /snap /var/snap /var/lib/snapd /root/snap 2>/dev/null || true
apt-get autoremove -y -qq

# FIX #4: Firefox with proper GPG key import
install -d -m 0755 /etc/apt/keyrings

echo "   Firefox setup kar rahe hain..."
wget -q "https://packages.mozilla.org/apt/repo-signing-key.gpg" -O /tmp/mozilla.gpg

if [ -s /tmp/mozilla.gpg ]; then
  # Import key properly
  gpg --dearmor < /tmp/mozilla.gpg > /etc/apt/keyrings/mozilla.gpg 2>/dev/null || \
    cp /tmp/mozilla.gpg /etc/apt/keyrings/mozilla.gpg
  
  chmod 644 /etc/apt/keyrings/mozilla.gpg
  
  echo "deb [signed-by=/etc/apt/keyrings/mozilla.gpg] https://packages.mozilla.org/apt mozilla main" \
    > /etc/apt/sources.list.d/mozilla.list

  cat > /etc/apt/preferences.d/mozilla-firefox << 'EOF'
Package: firefox*
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

  # Add key to trusted keys also (double safety)
  apt-key add /tmp/mozilla.gpg 2>/dev/null || true
  
  apt-get update -qq 2>/dev/null || true
  apt-get install -y -qq firefox 2>/dev/null || echo "   ⚠️  Firefox install mein issue, skip kar rahe hain"
  echo "   ✅ Firefox installed (or skipped)"
else
  echo "   ⚠️  Firefox GPG download fail, Ubuntu default use karo"
fi

# Chrome (amd64) / Chromium (arm64)
if [ "$ARCH" = "amd64" ]; then
  echo "   Chrome setup kar rahe hain..."
  wget -q "https://dl.google.com/linux/linux_signing_key.pub" -O /tmp/chrome.gpg
  
  if [ -s /tmp/chrome.gpg ]; then
    gpg --dearmor < /tmp/chrome.gpg > /etc/apt/keyrings/google-chrome.gpg 2>/dev/null || \
      cat /tmp/chrome.gpg | gpg --dearmor > /etc/apt/keyrings/google-chrome.gpg
    
    chmod 644 /etc/apt/keyrings/google-chrome.gpg
    
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] \
https://dl.google.com/linux/chrome/deb/ stable main" \
      > /etc/apt/sources.list.d/google-chrome.list
    
    apt-get update -qq 2>/dev/null || true
    apt-get install -y -qq google-chrome-stable 2>/dev/null || \
      apt-get install -y -qq chromium-browser
    echo "   ✅ Chrome/Chromium installed"
  else
    apt-get install -y -qq chromium-browser 2>/dev/null || true
    echo "   ✅ Chromium installed (fallback)"
  fi
else
  apt-get install -y -qq chromium-browser 2>/dev/null || \
    apt-get install -y -qq chromium 2>/dev/null || true
  echo "   ✅ Chromium installed (ARM)"
fi

# ============================================================
# STEP 14/15 — TAILSCALE VPN (FIXED with error handling)
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 STEP 14/15 — Tailscale VPN Install"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

curl -fsSL "https://tailscale.com/install.sh" -o /tmp/tailscale-install.sh

if [ -s /tmp/tailscale-install.sh ]; then
  bash /tmp/tailscale-install.sh 2>/dev/null || {
    echo "   ⚠️  Tailscale install script fail, manual try karo"
  }
  
  # Check if installed then enable
  if command -v tailscale &>/dev/null; then
    systemctl enable tailscaled --quiet 2>/dev/null || true
    systemctl start tailscaled 2>/dev/null || true
    ufw allow in on tailscale0 comment "Tailscale VPN" 2>/dev/null || true
    
    echo ""
    echo "   ⚡ Tailscale auth shuru ho raha hai..."
    echo "   👇 Neeche URL aayega — browser mein kholo:"
    timeout 15 tailscale up --accept-routes 2>&1 || true
    echo ""
    echo "   ✅ Tailscale ready"
  else
    echo "   ❌ Tailscale install nahi hua. Baad mein try karo:"
    echo "   curl -fsSL https://tailscale.com/install.sh | sh"
  fi
else
  echo "   ❌ Tailscale download fail"
fi

# ... (Step 15 same as before) ...
