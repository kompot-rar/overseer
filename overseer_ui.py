#!/usr/bin/env python3
# =============================================================================
# OVERSEER UI - CYBERPUNK CLUSTER MONITOR
# Requires: pip install rich
# =============================================================================

import sys
import subprocess
import threading
import time
import random
from datetime import datetime

try:
    from rich.console import Console
    from rich.table import Table
    from rich.live import Live
    from rich.panel import Panel
    from rich.layout import Layout
    from rich.text import Text
    from rich.progress import BarColumn, Progress, TextColumn
    from rich import box
except ImportError:
    print("CRITICAL ERROR: 'rich' library missing.")
    print("Run: pip install rich")
    sys.exit(1)

# CONFIG
NODES = ["10.0.10.11", "10.0.10.12", "10.0.10.13"]
SSH_TIMEOUT = 5
SSH_USER = "root"

console = Console()

console = Console()

# ASCII HEADER (Compact)
HEADER = """
   ▄██████▄  ▄█    █▄     ▄████████    ▄████████ 
  ███    ███ ███    ███   ███    ███   ███    ███ 
  ███    ███ ███    ███   ███    █▀    ███    ███ 
  ███    ███ ███    ███  ▄███▄▄▄      ▄███▄▄▄▄██▀ 
  ███    ███ ███    ███ ▀▀███▀▀▀     ▀▀███▀▀▀▀▀   
  ███    ███ ███    ███   ███    █▄  ▀███████████ 
   ▀██████▀   ▀██████▀    ██████████   ███    ███ 
"""

class NodeStatus:
    def __init__(self, ip):
        self.ip = ip
        self.name = "SCANNING..."
        self.cpu = 0.0
        self.ram = 0.0
        self.temp = 0
        self.disk = 0
        self.vm_count = 0
        self.ct_count = 0
        self.uptime = "-"
        self.status = "INIT" # ONLINE, OFFLINE, ERROR
        self.last_update = None

    def update(self):
        """Runs SSH command to fetch stats by piping local agent script"""
        # Strategy: ssh user@host 'bash -s' < scripts/overseer_agent.sh
        # This eliminates all quoting/escaping issues.
        
        agent_path = "agent.sh"
        cmd = ["ssh", "-o", "ConnectTimeout=2", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=no", "-q", f"{SSH_USER}@{self.ip}", "bash -s"]
        
        try:
            with open(agent_path, "rb") as agent_file:
                proc = subprocess.run(cmd, stdin=agent_file, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=SSH_TIMEOUT+2)
            
            output = proc.stdout.decode("utf-8").strip()

            if proc.returncode == 0 and output:
                parts = output.split('|')
                if len(parts) >= 8:
                    self.name = parts[0]
                    self.cpu = float(parts[1].replace(',', '.')) * 10 
                    self.ram = float(parts[2])
                    self.temp = int(parts[3])
                    self.disk = int(parts[4])
                    self.vm_count = int(parts[5])
                    self.ct_count = int(parts[6])
                    self.uptime = parts[7]
                    
                    self.status = "ONLINE"
                    self.last_update = datetime.now()
                else:
                    self.status = "ERROR"
            else:
                self.status = "OFFLINE"

        except Exception as e:
            self.status = "OFFLINE"
            self.name = "UNREACHABLE"

cluster_data = [NodeStatus(ip) for ip in NODES]

def fetch_data_thread(node):
    while True:
        node.update()
        time.sleep(2 + random.random() * 2)

def generate_table():
    table = Table(box=box.HEAVY_EDGE, border_style="bright_cyan", expand=True)
    table.add_column("NODE", style="bold white", ratio=2)
    table.add_column("STATUS", justify="center", ratio=1, no_wrap=True)
    table.add_column("CPU", justify="right", ratio=2, no_wrap=True)
    table.add_column("RAM", justify="right", ratio=2, no_wrap=True)
    table.add_column("TMP", justify="right", ratio=1, no_wrap=True)
    table.add_column("DISK", justify="right", ratio=1, no_wrap=True)
    table.add_column("GUESTS", justify="center", ratio=2)
    table.add_column("UPTIME", style="dim", justify="right", ratio=2)

    for node in cluster_data:
        if node.status == "ONLINE":
            status_style = "[bold green]●[/]"
            
            # Colors
            cpu_c = "green" if node.cpu < 50 else "yellow" if node.cpu < 80 else "red"
            ram_c = "green" if node.ram < 60 else "yellow" if node.ram < 90 else "red"
            tmp_c = "green" if node.temp < 60 else "yellow" if node.temp < 80 else "red"
            disk_c = "green" if node.disk < 70 else "yellow" if node.disk < 90 else "red"
            
            # Bars
            cpu_bar = f"[{cpu_c}]{'█' * int(node.cpu / 10)}{'░' * (10 - int(node.cpu / 10))}[/] {node.cpu:.1f}"
            ram_bar = f"[{ram_c}]{'█' * int(node.ram / 10)}{'░' * (10 - int(node.ram / 10))}[/] {node.ram:.0f}%"
            
            temp_val = f"[{tmp_c}]{node.temp}°C[/]"
            disk_val = f"[{disk_c}]{node.disk}%[/]"
            guests = f"[white]VM:{node.vm_count}[/] [dim]|[/] [white]CT:{node.ct_count}[/]"
            uptime = node.uptime
            
        else:
            status_style = "[bold red]✖[/]" if node.status == "OFFLINE" else "[bold yellow]?[/]"
            cpu_bar = "[dim]---[/]"
            ram_bar = "[dim]---[/]"
            temp_val = "-"
            disk_val = "-"
            guests = "-"
            uptime = "-"

        table.add_row(
            f"[bold cyan]{node.name}[/]\n[dim]{node.ip}[/]",
            status_style,
            cpu_bar,
            ram_bar,
            temp_val,
            disk_val,
            guests,
            uptime
        )
    return table

def main():
    console.clear()
    console.print(Text(HEADER, style="bold magenta"), justify="center")
    console.print(Panel("[bold yellow]SYSTEM INITIALIZED. CONNECTING TO NEURAL NET...[/]", border_style="yellow"))
    
    # Start threads
    for node in cluster_data:
        t = threading.Thread(target=fetch_data_thread, args=(node,), daemon=True)
        t.start()
        time.sleep(0.5) # Stagger start to avoid SSH congestion

    # Main Loop
    with Live(generate_table(), refresh_per_second=4, console=console) as live:
        while True:
            # Glitch effect: Randomly change border color
            border_color = random.choice(["bright_cyan", "magenta", "green"])
            table = generate_table()
            table.border_style = border_color
            
            # Title with clock
            title = f" OVERSEER v2.0 | {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} | MODE: WATCHER "
            live.update(Panel(table, title=title, border_style=border_color))
            time.sleep(0.25)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n[!] CONNECTION TERMINATED.")
