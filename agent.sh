#!/bin/bash
export LC_ALL=C
set -u

# 1. Hostname
HOSTNAME=$(hostname | tr -d '\n')

# 2. Load Avg
LOAD=$(cat /proc/loadavg | awk '{print $1}' | tr -d '\n')

# 3. RAM %
MEM=$(free | awk '/Mem:/ {print int($3/$2 * 100)}' | tr -d '\n')

# 4. Temperature
# Try standard path first, then fallback to hwmon (Ryzen/Intel)
TEMP_RAW=""
if [ -d "/sys/class/thermal" ]; then
    # Standard thermal zones
    for zone in /sys/class/thermal/thermal_zone*; do
        TYPE=$(cat "$zone/type" 2>/dev/null || echo "")
        if [[ "$TYPE" =~ x86_pkg_temp|acpitz ]]; then
             TEMP_RAW=$(cat "$zone/temp" 2>/dev/null)
             break
        fi
    done
fi

if [ -z "$TEMP_RAW" ] || [ "$TEMP_RAW" -eq 0 ]; then
    # Fallback to hwmon (k10temp for Ryzen, coretemp for Intel)
    for hw in /sys/class/hwmon/hwmon*; do
        NAME=$(cat "$hw/name" 2>/dev/null || echo "")
        if [[ "$NAME" =~ k10temp|coretemp ]] && [ -e "$hw/temp1_input" ]; then
            TEMP_RAW=$(cat "$hw/temp1_input" 2>/dev/null)
            break
        fi
    done
fi

if [ -z "$TEMP_RAW" ]; then TEMP_RAW=0; fi
TEMP=$(( TEMP_RAW / 1000 ))

# 5. Disk Usage (Root)
DISK=$(df / | awk 'NR==2 {print $5}' | tr -d '%' | tr -d '\n')

# 6. Proxmox Guests
VM_COUNT=0
if [ -x /usr/sbin/qm ]; then
    VM_COUNT=$(/usr/sbin/qm list 2>/dev/null | grep -c running || echo 0)
fi
VM_COUNT=$(echo "$VM_COUNT" | tr -d '\n')

CT_COUNT=0
if [ -x /usr/sbin/pct ]; then
    CT_COUNT=$(/usr/sbin/pct list 2>/dev/null | grep -c running || echo 0)
fi
CT_COUNT=$(echo "$CT_COUNT" | tr -d '\n')

# 7. Uptime
UPTIME=$(uptime -p | sed 's/up //;s/ days,/d/;s/ hours,/h/;s/ minutes/m/' | tr -d '\n')

# Output formatted string
echo "$HOSTNAME|$LOAD|$MEM|$TEMP|$DISK|$VM_COUNT|$CT_COUNT|$UPTIME"
