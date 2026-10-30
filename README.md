# OSYS3030 - Linux Network Appliance Documentation

> **Student Name:** Josh
> **Student ID / VMID:** w0524697
> **Repository:** https://github.com/joshhenry15/osys3030-network-services-template 
> **Instructor:** Matt Redmond  
> **Course:** OSYS3030 - Network Services Using Linux  

---

## 1. Appliance Overview
A high-level summary of your multi-homed Linux server appliance, its purpose, and its role as a gateway/router for the private internal network.

* **Operating System:** Ubuntu Server 24.04 LTS (Noble Numbat)
* **Hostname:** `server-[YourID]` (e.g., `robserver`)
* **Primary Roles:**
  * Router & Firewall (UFW + iptables NAT masquerading)
  * Recursive & Authoritative DNS (BIND9)
  * Dynamic Host Configuration Protocol (Kea DHCPv4)
  * Secure Remote Administration (OpenSSH)

---

## 2. Network Topology & Interfaces

```text
              +------------------------------------------+
              |           WAN / NSCC Network             |
              |             10.20.0.0/23                 |
              +---------------------+--------------------+
                                    |
                                    | (DHCP / Static IP)
                                 [ens18]
                       +------------+------------+
                       |   OSYS3030 Linux Server |
                       |      (Your Appliance)   |
                       +------------+------------+
                                 [ens19]
                                    | (10.<ID>.0.250/24)
                                    |
              +---------------------+--------------------+
              |        Isolated Private VLAN (vmbr5)      |
              |             10.<ID>.0.0/24               |
              +---------------------+--------------------+
                                    |
                                    | (DHCP: 10.<ID>.0.10 - .200)
                                 [eth0]
                       +------------+------------+
                       |    Alpine Client VM     |
                       |       (VM 91<ID>)       |
                       +-------------------------+
```

| Interface | Network Zone | IP Address / Subnet | Purpose |
| :--- | :--- | :--- | :--- |
| `ens18` | WAN / External | `10.20.1.<ID>/23` | Upstream internet & SSH management |
| `ens19` | LAN / Internal | `10.<ID>.0.250/24` | Default gateway & service binding for clients |

---

## 3. Implemented Services

| Directory | Service | Daemon | Listening Ports | Description |
| :--- | :--- | :--- | :--- | :--- |
| [`hardening/`](./hardening/) | SSH / Host Security | `sshd` | TCP 22 | Hardened SSH configuration, root restrictions |
| [`dns/`](./dns/) | BIND9 DNS | `named` | UDP/TCP 53 | Authoritative for `innovate.lab` & recursive forwarder |
| [`dhcp/`](./dhcp/) | Kea DHCPv4 | `kea-dhcp4` | UDP 67 | Scoped dynamic IP lease allocation for LAN |
| [`fw/`](./fw/) | UFW Firewall & NAT | `ufw` / `iptables` | N/A | State-tracking firewall & packet masquerading |
| [`scripts/`](./scripts/) | Automation | Bash | N/A | Automated deployment and verification scripts |

---

## 4. Base OS & Netplan Prerequisites
Document any one-time operating system setup steps, package manager configurations, and your `/etc/netplan/*.yaml` static interface definitions required before services can be installed.

---

## 5. Automated Recovery & Verification

This appliance includes automated deployment and verification scripts located in [`scripts/`](./scripts/):

* **Deployment / Disaster Recovery:**
  ```bash
  sudo ./scripts/deploy_appliance.sh
  ```
* **Automated Health Check & Verification:**
  ```bash
  sudo ./scripts/verify_appliance.sh
  ```

See [`AI_AUDIT.md`](./AI_AUDIT.md) for documentation on how these scripts were generated using AI and audited for accuracy.

---

## 6. Peer Review Audit

* **Audited Classmate:** Eric https://github.com/WhiskersWatson/osys3030-network-services-template
* **Classmate Appliance Subnet:** `10.110.0.0/24`
* **Audit Summary:** [2–3 sentences summarizing your review of your peer's repository, configs, and recovery documentation].
Eric is a reliable student, im sure everything worked great, i didnt see any issues! He also helped me a bit on this lab
