# Overseer 👁️

A lightweight, agentless monitoring solution for Proxmox/Linux clusters. Built as a "hard way" learning project to master Bash scripting and Linux internals.

## Overview
Overseer collects system metrics by injecting a Bash agent via SSH and parsing the `/proc` filesystem directly. No remote installation or persistent agents required.

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

## Learning Goals
This project was created to explore:
- **Bash & SSH**: Streaming scripts to remote shells without leaving a footprint.
- **Linux Internals**: Manual parsing of `/proc/loadavg`, `/proc/meminfo`, and thermal zones.
- **Automation**: Handling cluster-wide status checks without high-level tools.

---
*Part of my DevOps Journey 2026. Built to learn, not to replace Prometheus.*
