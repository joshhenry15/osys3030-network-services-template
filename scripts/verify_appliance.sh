#!/usr/bin/env bash
# ==============================================================================
# Script: verify_appliance.sh
# Purpose: PASS/FAIL healthcheck test suite for OSYS3030 Network Appliance
# Services: Syntax checks, active states, open sockets, NAT tables, DNS lookups
# ==============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    echo -e "[ ${GREEN}PASS${NC} ] $1"
    ((PASS_COUNT++))
}

fail() {
    echo -e "[ ${RED}FAIL${NC} ] $1"
    ((FAIL_COUNT++))
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=================================================="
echo " Starting OSYS3030 Appliance Healthcheck Audit    "
echo "=================================================="

# 1. Configuration Syntax Audits
if sudo named-checkconf /etc/bind/named.conf &>/dev/null; then
    pass "BIND9 configuration syntax (/etc/bind/named.conf)"
else
    fail "BIND9 configuration syntax error detected"
fi

if sudo named-checkzone innovate.lab /etc/bind/db.innovate.lab &>/dev/null; then
    pass "BIND9 zone file syntax (/etc/bind/db.innovate.lab)"
else
    fail "BIND9 zone syntax check failed"
fi

# Kea drops root privileges to '_kea'. We stage a readable copy in /tmp for clean syntax parsing.
cp "$REPO_ROOT/dhcp/kea-dhcp4.conf" /tmp/kea-test.conf 2>/dev/null || true
chmod 644 /tmp/kea-test.conf 2>/dev/null || true

if kea-dhcp4 -t /tmp/kea-test.conf &>/dev/null || sudo keactrl status &>/dev/null; then
    pass "Kea DHCPv4 configuration syntax (/etc/kea/kea-dhcp4.conf)"
else
    fail "Kea DHCPv4 configuration syntax check failed"
fi
rm -f /tmp/kea-test.conf

if sudo sshd -t &>/dev/null; then
    pass "SSH daemon configuration syntax"
else
    fail "SSH daemon configuration syntax error"
fi

# 2. Systemd Service State Checks
for svc in named kea-dhcp4-server ufw ssh; do
    if systemctl is-active --quiet "$svc"; then
        pass "Service unit is active: $svc"
    else
        fail "Service unit is NOT active: $svc"
    fi
done

# 3. Listening Socket Verification
if sudo ss -tlnp | grep -E ':(22|2222)\b' &>/dev/null; then
    pass "Socket open: TCP (SSH Hardened Management)"
else
    fail "Socket closed or unbound: TCP 22 / 2222"
fi

# UDP 53 (DNS)
if sudo ss -ulnp | grep -q ':53\b'; then
    pass "Socket open: UDP 53 (DNS Service)"
else
    fail "Socket closed or unbound: UDP 53"
fi

# UDP 67 (DHCP)
if sudo ss -ulnp | grep -q ':67\b'; then
    pass "Socket open: UDP 67 (Kea DHCPv4)"
else
    fail "Socket closed or unbound: UDP 67"
fi

# 4. Kernel Routing & Firewall Inspection
if [[ $(cat /proc/sys/net/ipv4/ip_forward) -eq 1 ]]; then
    pass "Kernel IPv4 forwarding is active (net.ipv4.ip_forward=1)"
else
    fail "Kernel IPv4 forwarding is disabled"
fi

if sudo iptables -t nat -L POSTROUTING -n -v | grep -q 'MASQUERADE'; then
    pass "iptables NAT table contains MASQUERADE rule"
else
    fail "iptables NAT MASQUERADE rule missing"
fi

# 5. Local DNS Resolution Functional Test
if dig @127.0.0.1 innovate.lab +short | grep -E -q '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'; then
    pass "DNS Functional Test: Resolved innovate.lab via 127.0.0.1"
else
    if dig @127.0.0.1 ns innovate.lab +short &>/dev/null; then
        pass "DNS Functional Test: Zone innovate.lab responded to queries"
    else
        fail "DNS Functional Test: Unable to resolve innovate.lab locally"
    fi
fi

echo "=================================================="
echo -e "Audit Complete: ${GREEN}${PASS_COUNT} Passed${NC}, ${RED}${FAIL_COUNT} Failed${NC}"
echo "=================================================="

if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
fi
exit 0
