#!/usr/bin/env bash
# ==============================================================================
# Script: deploy_appliance.sh
# Purpose: Idempotent automated deployment for OSYS3030 Network Appliance
# Services: SSH Hardening, BIND9 DNS, Kea DHCPv4, UFW NAT Masquerade
# Target OS: Ubuntu Server 24.04 LTS
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1" >&2; }

if [[ $EUID -ne 0 ]]; then
   log_err "This deployment script must be run as root (use sudo)."
   exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="/root/appliance_backups_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
log_info "Configuration backup directory initialized: $BACKUP_DIR"

# 1. Package Installation
log_info "Updating package cache and installing required service packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq bind9 bind9-utils kea-dhcp4-server ufw iptables-persistent net-tools dnsutils

# 2. Kernel IPv4 Forwarding
log_info "Enabling IPv4 forwarding in sysctl..."
sed -i 's/^#*net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf >/dev/null

# 3. SSH Hardening Deployment
log_info "Deploying hardened SSH configuration..."
[[ -f /etc/ssh/sshd_config ]] && cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.bak"
install -m 600 -o root -g root "$REPO_ROOT/hardening/sshd_config" /etc/ssh/sshd_config

if sshd -t; then
    systemctl restart ssh
    log_ok "SSH service restarted with hardened configuration."
else
    log_err "sshd configuration syntax test failed. Restoring backup..."
    [[ -f "$BACKUP_DIR/sshd_config.bak" ]] && cp "$BACKUP_DIR/sshd_config.bak" /etc/ssh/sshd_config
    systemctl restart ssh
    exit 1
fi

# 4. BIND9 DNS Deployment
log_info "Deploying BIND9 DNS configuration and zone records..."
[[ -f /etc/bind/named.conf.local ]] && cp /etc/bind/named.conf.local "$BACKUP_DIR/named.conf.local.bak"
[[ -f /etc/bind/named.conf.options ]] && cp /etc/bind/named.conf.options "$BACKUP_DIR/named.conf.options.bak"
[[ -f /etc/bind/db.innovate.lab ]] && cp /etc/bind/db.innovate.lab "$BACKUP_DIR/db.innovate.lab.bak"

install -m 644 -o root -g bind "$REPO_ROOT/dns/named.conf.local" /etc/bind/named.conf.local
install -m 644 -o root -g bind "$REPO_ROOT/dns/named.conf.options" /etc/bind/named.conf.options
install -m 644 -o root -g bind "$REPO_ROOT/dns/db.innovate.lab" /etc/bind/db.innovate.lab

named-checkconf /etc/bind/named.conf
named-checkzone innovate.lab /etc/bind/db.innovate.lab
systemctl enable --now named
systemctl restart named
log_ok "BIND9 DNS deployed and running."

# 5. Kea DHCPv4 Deployment
log_info "Deploying Kea DHCPv4 configuration..."
[[ -f /etc/kea/kea-dhcp4.conf ]] && cp /etc/kea/kea-dhcp4.conf "$BACKUP_DIR/kea-dhcp4.conf.bak"
install -m 640 -o root -g _kea "$REPO_ROOT/dhcp/kea-dhcp4.conf" /etc/kea/kea-dhcp4.conf

kea-dhcp4 -t /etc/kea/kea-dhcp4.conf
systemctl enable --now kea-dhcp4-server
systemctl restart kea-dhcp4-server
log_ok "Kea DHCPv4 deployed and running."

# 6. UFW & NAT Masquerade Deployment
log_info "Deploying UFW firewall configuration and NAT rules..."
[[ -f /etc/ufw/before.rules ]] && cp /etc/ufw/before.rules "$BACKUP_DIR/before.rules.bak"
install -m 640 -o root -g root "$REPO_ROOT/fw/before.rules" /etc/ufw/before.rules

ufw allow 2222/tcp comment 'SSH Management' >/dev/null
ufw allow in on ens19 to any port 53 comment 'BIND9 DNS LAN' >/dev/null
ufw allow in on ens19 to any port 67 proto udp comment 'Kea DHCP LAN' >/dev/null
ufw default route allow >/dev/null

ufw --force enable
ufw reload
log_ok "UFW and NAT masquerading deployed."

log_ok "Appliance deployment complete. All services enabled and verified."
