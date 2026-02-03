# Overseer 👁️

A lightweight, agentless monitoring solution for Proxmox/Linux clusters. Built as a "hard way" learning project to master Bash scripting and Linux internals.

## Overview
Overseer collects system metrics by injecting a Bash agent via SSH and parsing the `/proc` filesystem directly. No remote installation or persistent agents required.

## Preview
Example output from `healthcheck.sh`:
```text
--- SCAN 10.0.10.11 ---
>> OVERSEER: proxmox << | 10VHS2BU02 | up 4 hours, 57 minutes
─────────────────────────────────────────────────────────────────────
 CPU [■·········]  16%  |  RAM [■■■■■·····]  56%  |  TMP [■■■■■·····]  50°C
─────────────────────────────────────────────────────────────────────
 GUESTS:  CT: 12 RUN / 1 STOP   |   VM: 2 RUN / 0 STOP
─────────────────────────────────────────────────────────────────────
 [ZFS] NONE
 /            [■■■■■■■■····]  68% (1.1T/1.7T)
 /boot/efi    [■···········]  10% (96M/1022M)
─────────────────────────────────────────────────────────────────────
 SYS: 1 FAIL | LOGS(1h): 3 ERR | USERS: 1 | NTP: YES
 FAILED UNITS:
  -> pve-container@108.service
 PORTS: 111 22 25 8006 2222 ...
─────────────────────────────────────────────────────────────────────
 CPU TOP 3:
   5896  13.3%  /usr/bin/kvm
   1426   3.2%  pvestatd
```

## Key Features
- **Agentless**: Uses SSH pipe injection (`ssh host 'bash -s' < agent.sh`) to run in memory.
- **Zero-Dep**: Remote execution relies only on standard Bash and coreutils.
- **Proxmox Aware**: Automatically detects and monitors LXC/VM guests status.
- **Cyberpunk TUI**: Real-time cluster dashboard using Python and the `rich` library.

## Components
- `agent.sh`: The data collector script executed on remote nodes.
- `healthcheck.sh`: Standalone diagnostic tool for deep local system inspection (ZFS, systemd, etc.).
- `overseer_ui.py`: Python TUI that aggregates data from your cluster.
- `inventory.txt`: Simple list of nodes in `user@host` format.

## Quick Start
1. **Configure Nodes**: Add your servers to `inventory.txt`.
2. **Install UI Deps**:
   ```bash
   pip install rich
   ```
3. **Launch Dashboard**:
   ```bash
   python3 overseer_ui.py
   ```
 or

  **Launch bash healthcheck**
  ```bash
  #local
  bash scripts/healthcheck.sh
  #remote
  ssh root@10.0.10.11 "bash -s" < scripts/healthcheck.sh
   ```

## Learning Goals
This project was created to explore:
- **Bash & SSH**: Streaming scripts to remote shells without leaving a footprint.
- **Linux Internals**: Manual parsing of `/proc/loadavg`, `/proc/meminfo`, and thermal zones.
- **Automation**: Handling cluster-wide status checks without high-level tools.

---
*Part of my DevOps Journey 2026. Built to learn, not to replace Prometheus.*
