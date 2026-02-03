#!/bin/bash
# =============================================================================
# SKRYPT: healthcheck.sh (V5.1 - GOD MODE)
# OPIS:   Proxmox Awareness, Log Sentinel, Security Watch, Hardware ID.
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# --- COLORS ---
BOLD='\033[1m'
DIM='\033[2m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# --- SYMBOLS ---
BLOCK=$'\xe2\x96\xa0'
DOT=$'\xc2\xb7'

# --- HELPERS ---

separator() {
    echo -e "${DIM}─────────────────────────────────────────────────────────────────────${NC}"
}

get_bar() {
    local pct="${1:-0}"
    local width="${2:-10}"
    pct=${pct%.*} # int cast
    
    [[ "$pct" =~ ^[0-9]+$ ]] || pct=0
    [ "$pct" -gt 100 ] && pct=100

    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    
    local color=$GREEN
    [ "$pct" -ge 70 ] && color=$YELLOW
    [ "$pct" -ge 90 ] && color=$RED

    local bar_str=""
    for ((i=0; i<filled; i++)); do bar_str+="$BLOCK"; done
    local empty_str=""
    for ((i=0; i<empty; i++)); do empty_str+="$DOT"; done
    
    echo -e "${color}${bar_str}${DIM}${empty_str}${NC}"
}

# --- SECTIONS ---

check_hud() {
    # Hardware ID (Product Name)
    local model="Unknown"
    if [ -f /sys/class/dmi/id/product_name ]; then
        model=$(cat /sys/class/dmi/id/product_name)
    fi

    echo -e "${BOLD}${CYAN}>> OVERSEER: $(hostname) <<${NC} ${DIM}| $model | $(uptime -p)${NC}"
    separator

    local cores=$(nproc)
    local load=$(awk '{print $1}' /proc/loadavg)
    local cpu_pct=$(awk -v l="$load" -v c="$cores" 'BEGIN { printf "%.0f", (l/c)*100 }')
    local ram_pct=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
    
    local temp="0"
    if [ -d "/sys/class/thermal" ]; then
        for zone in /sys/class/thermal/thermal_zone*; do
            [[ "$(cat "$zone/type" 2>/dev/null)" =~ x86_pkg_temp|acpitz ]] && temp=$(( $(cat "$zone/temp") / 1000 )) && break
        done
    fi
    if [ "$temp" -eq 0 ] || [ -z "$temp" ]; then
        for hw in /sys/class/hwmon/hwmon*; do
            [[ "$(cat "$hw/name" 2>/dev/null)" =~ k10temp|coretemp ]] && [ -e "$hw/temp1_input" ] && temp=$(( $(cat "$hw/temp1_input") / 1000 )) && break
        done
    fi

    local bar_cpu=$(get_bar "$cpu_pct" 10)
    local bar_ram=$(get_bar "$ram_pct" 10)
    local bar_tmp=$(get_bar "$temp" 10)

    printf " CPU [%-10s] %3s%%  ${DIM}|${NC}  RAM [%-10s] %3s%%  ${DIM}|${NC}  TMP [%-10s] %3s°C\n" \
           "$bar_cpu" "$cpu_pct" \
           "$bar_ram" "$ram_pct" \
           "$bar_tmp" "$temp"
}

check_proxmox() {
    # Tylko jeśli mamy komendy proxmoxa
    if command -v pveversion >/dev/null; then
        # CT Stats (grep -c counts matches; || true prevents crash on 0 matches under set -e)
        local ct_running=$(pct list 2>/dev/null | grep -c "running" || true)
        local ct_stopped=$(pct list 2>/dev/null | grep -c "stopped" || true)
        
        # VM Stats
        local vm_running=$(qm list 2>/dev/null | grep -c "running" || true)
        local vm_stopped=$(qm list 2>/dev/null | grep -c "stopped" || true)

        # Formatting colors
        local ct_color=$GREEN
        # Force integer context for safety
        if (( ct_stopped > 0 )); then ct_color=$YELLOW; fi
        
        local vm_color=$GREEN
        if (( vm_stopped > 0 )); then vm_color=$YELLOW; fi

        separator
        echo -e " ${BOLD}GUESTS:${NC}  CT: ${ct_color}${ct_running} RUN${NC} / ${DIM}${ct_stopped} STOP${NC}   |   VM: ${vm_color}${vm_running} RUN${NC} / ${DIM}${vm_stopped} STOP${NC}"
    fi
}

check_storage() {
    separator
    if command -v zpool >/dev/null; then
        if ! zpool list >/dev/null 2>&1; then
             echo -e " ${DIM}[ZFS] NONE${NC}"
        else
             local zstat=$(zpool status -x 2>&1)
             if [[ "$zstat" == "all pools are healthy" ]]; then
                 echo -e " ${GREEN}[ZFS]${NC} OK"
             elif [[ "$zstat" == *"no pools available"* ]]; then
                 echo -e " ${DIM}[ZFS] NONE${NC}"
             else
                 echo -e " ${RED}[ZFS] ALERT:${NC} $zstat"
             fi
        fi
    fi

    df -h | grep '^/' | grep -v '/loop' | awk -v green="$GREEN" -v yellow="$YELLOW" -v red="$RED" -v nc="$NC" -v dim="$DIM" \
    -v block=$'\xe2\x96\xa0' -v dot=$'\xc2\xb7' '\
    function draw_bar(pct, width, filled, empty, bar, i, color) {
        width=12
        pct=pct+0
        if(pct>100) pct=100
        filled=int(pct * width / 100)
        empty=width - filled
        color=green
        if(pct>=70) color=yellow
        if(pct>=90) color=red
        bar=color
        for(i=0; i<filled; i++) bar=bar block
        bar=bar dim
        for(i=0; i<empty; i++) bar=bar dot
        bar=bar nc
        return bar
    }
    {
        pct=$5
        gsub("%", "", pct)
        bar=draw_bar(pct)
        printf " %-12s [%s] %3s%% %s(%s/%s)%s\n", substr($6,1,12), bar, pct, dim, $3, $2, nc
    }'
}

check_sentinel() {
    separator
    local failed=$(SYSTEMD_COLORS=0 systemctl --failed --no-legend --plain | wc -l)
    local ntp="NO"
    timedatectl | grep -q "System clock synchronized: yes" && ntp="YES"
    local ports=$(ss -tuln | grep '0.0.0.0' | awk '{print $5}' | cut -d: -f2 | sort -u | xargs || true)
    local users=$(who | wc -l)
    
    local err_logs=0
    if command -v journalctl >/dev/null; then
        err_logs=$(journalctl -p 3 -S "1 hour ago" 2>/dev/null | wc -l || echo 0)
    fi

    local sys_color=$GREEN
    [ "$failed" -gt 0 ] && sys_color=$RED
    local log_color=$GREEN
    [ "$err_logs" -gt 0 ] && log_color=$RED
    local user_color=$GREEN
    [ "$users" -gt 1 ] && user_color=$YELLOW
    local ntp_color=$GREEN
    [ "$ntp" == "NO" ] && ntp_color=$RED

    echo -e " SYS: ${sys_color}${failed} FAIL${NC} | LOGS(1h): ${log_color}${err_logs} ERR${NC} | USERS: ${user_color}${users}${NC} | NTP: ${ntp_color}${ntp}${NC}"

    if [ "$failed" -gt 0 ]; then
        echo -e "${RED} FAILED UNITS:${NC}"
        SYSTEMD_COLORS=0 systemctl --failed --no-legend --plain | awk '{print "  -> " $1}'
    fi
    if [ -n "$ports" ]; then
         echo -e " ${DIM}PORTS:${NC} $ports"
    fi
}

check_hogs() {
    # Disable pipefail to allow 'ps' to receive SIGPIPE from 'head' without killing the script
    set +o pipefail
    
    separator
    # CPU
    echo -e " ${DIM}CPU TOP 3:${NC}"
    ps -eo pid,%cpu,cmd --sort=-%cpu | grep -v "systemd-timedated" | head -n 4 | tail -n +2 | \
    awk -v dim="$DIM" -v nc="$NC" '{printf "  %s%5s%s %5s%%  %.45s\n", dim, $1, nc, $2, $3}'

    # RAM
    echo -e " ${DIM}RAM TOP 3:${NC}"
    ps -eo pid,%mem,cmd --sort=-%mem | head -n 4 | tail -n +2 | \
    awk -v dim="$DIM" -v nc="$NC" '{printf "  %s%5s%s %5s%%  %.45s\n", dim, $1, nc, $2, $3}'
    
    set -o pipefail
}

# --- RUN ---
check_hud
check_proxmox
check_storage
check_sentinel
check_hogs
echo ""