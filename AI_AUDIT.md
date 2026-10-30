# AI Prompt & Hallucination Audit Log

## 1. Environment & Model Details
- **AI Model Used:** Google Gemini
- **Date:** October 30, 2026
- **Target Platform:** Ubuntu Server 24.04 LTS (x86_64)
- **Role:** OSYS3030 Multi-Homed Network Appliance Automation

---

## 2. AI Prompts Provided

### Deployment Automation Prompt:
> "Act as a Senior Linux DevOps Engineer. Using my working configuration files for SSH hardening, BIND9 DNS, Kea DHCPv4, and UFW with NAT masquerading on Ubuntu 24.04, generate a production-ready Bash script (`scripts/deploy_appliance.sh`). The script must install all packages, back up existing configs with timestamps, deploy custom config files into `/etc/`, set strict file permissions, and start/enable services in the correct dependency order."

### Verification Test Suite Prompt:
> "Write a companion Bash verification script (`scripts/verify_appliance.sh`) with formatted `[ PASS ]` / `[ FAIL ]` indicators that tests every service on the appliance: verifies configuration syntax (`named-checkconf`, `kea-dhcp4 -t`), confirms systemd active states, checks listening ports (UDP 53, UDP 67, TCP 22), validates UFW rules and iptables NAT table entries, and tests local DNS resolution via dig."

---

## 3. Discovered Hallucinations, Edge Cases & Human Debugging

### Issue 1: Hardcoded Default SSH Port Assumption
- **AI Bug:** The initial verification script checked exclusively for `ss -tlnp | grep ':22 '`.
- **System Reality:** The hardened SSH configuration was set to a non-standard port (`2222`), causing an immediate false `[ FAIL ]` on TCP port 22 even though the SSH daemon was active and functional.
- **Human Fix:** 
  1. Updated `scripts/verify_appliance.sh` socket audit regex to evaluate `:(22|2222)\b`.
  2. Updated `scripts/deploy_appliance.sh` firewall rule from `ufw allow 22/tcp` to `ufw allow 2222/tcp` to maintain proper management access.

### Issue 2: Kea DHCPv4 Privilege Dropping & Path Access
- **AI Bug:** The AI script generated `sudo kea-dhcp4 -t /etc/kea/kea-dhcp4.conf` directly.
- **System Reality:** The Kea DHCPv4 test binary drops capabilities to the unprivileged `_kea` user immediately upon execution. When testing repository configuration files stored in standard user home paths (`/home/student/...`) or checking configs where directory traversal is restricted, Kea returns exit code `1` with: `Syntax check failed with: Unable to open file`.
- **Human Fix:** Documented permission boundary; added staging copy handling to `/tmp/kea-test.conf` with world-readable permissions (`644`) during verification passes to allow unprivileged validation.

### Issue 3: Socket Inspection Privilege Requirements
- **AI Bug:** The AI script initially called `ss -tlnp` without `sudo`.
- **System Reality:** Running `ss -tlnp` as standard user `student` hides process names and certain bound sockets, leading to regex pattern misses.
- **Human Fix:** Added `sudo` invocation to socket inspections in the verification script.

---

## 4. Final Audit Conclusion
Both `deploy_appliance.sh` and `verify_appliance.sh` have been human-audited, tested on the live virtual machine, and aligned with the appliance's specific network topology and port allocations.
