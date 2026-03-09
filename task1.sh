#!/opt/homebrew/bin/bash

LOG_FILE="system_monitor_log.txt"
ARCHIVE_DIR="ArchiveLogs"
STORAGE_THRESHOLD_GB=1

log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# ── MENU ──────────────────────────────────────────────────────────────────────
show_menu() {
    echo ""
    echo "========================================"
    echo "   University Data Centre Monitor"
    echo "========================================"
    echo "1. View Running Processes"
    echo "2. Terminate a Process"
    echo "3. Disk Inspection and Log Archiving"
    echo "4. View System Monitor Log"
    echo "5. Bye"
    echo "========================================"
    echo -n "Select an option [1-5]: "
}

# ── PROCESS MONITOR ───────────────────────────────────────────────────────────
view_processes() {
    echo ""
    echo "--- Running Processes ---"
    ps aux --sort=-%cpu 2>/dev/null || ps aux | sort -rk3
    log_action "Viewed running processes."
}

# ── SAFE TERMINATION ──────────────────────────────────────────────────────────
CRITICAL_PROCESSES=("init" "systemd" "kernel" "launchd" "bash" "zsh")

is_critical() {
    local name="$1"
    for critical in "${CRITICAL_PROCESSES[@]}"; do
        if [[ "$name" == "$critical" ]]; then
            return 0
        fi
    done
    return 1
}

terminate_process() {
    echo ""
    read -rp "Enter the PID to terminate: " pid

    if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        echo "Invalid PID. Please enter a number."
        log_action "Failed termination attempt - invalid PID input: '$pid'."
        return
    fi

    if ! ps -p "$pid" > /dev/null 2>&1; then
        echo "No process found with PID $pid."
        log_action "Failed termination attempt - PID $pid not found."
        return
    fi

    proc_name=$(ps -p "$pid" -o comm= 2>/dev/null)

    if is_critical "$proc_name"; then
        echo "Cannot terminate critical process: $proc_name (PID $pid)."
        log_action "Blocked termination of critical process: $proc_name (PID $pid)."
        return
    fi

    echo "⚠️  You are about to terminate: $proc_name (PID $pid)"
    read -rp "Are you sure? (Y/N): " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        kill "$pid" && echo "Process $pid terminated." || echo "Failed to terminate PID $pid."
        log_action "Terminated process: $proc_name (PID $pid)."
    else
        echo "Termination cancelled."
        log_action "Termination of PID $pid cancelled by user."
    fi
}

# ── DISK INSPECTION ───────────────────────────────────────────────────────────
disk_inspection() {
    echo ""
    echo "--- Disk Usage ---"
    df -h
    echo ""

    # Check if storage exceeds threshold
    used_gb=$(df -g / | awk 'NR==2 {print $3}')
    if (( used_gb > STORAGE_THRESHOLD_GB )); then
        echo "⚠️  WARNING: Disk usage exceeds ${STORAGE_THRESHOLD_GB}GB threshold (currently ${used_gb}GB used)."
        log_action "WARNING: Disk usage is ${used_gb}GB, exceeds threshold of ${STORAGE_THRESHOLD_GB}GB."
    fi

    # Find large log files (>1MB) in current directory and /var/log
    echo "--- Searching for large log files (>1MB) ---"
    large_files=$(find . /var/log -name "*.log" -size +1M 2>/dev/null)

    if [[ -z "$large_files" ]]; then
        echo "No large log files found."
        log_action "Disk inspection completed. No large log files found."
        return
    fi

    echo "$large_files"
    echo ""
    read -rp "Archive these log files? (Y/N): " archive_confirm

    if [[ "$archive_confirm" =~ ^[Yy]$ ]]; then
        mkdir -p "$ARCHIVE_DIR"
        timestamp=$(date '+%Y%m%d_%H%M%S')
        archive_name="${ARCHIVE_DIR}/archive_${timestamp}.tar.gz"
        echo "$large_files" | xargs tar -czf "$archive_name" 2>/dev/null
        echo "Files archived to $archive_name"
        log_action "Archived large log files to $archive_name."
    else
        echo "Archiving cancelled."
        log_action "Disk inspection completed. Archiving cancelled by user."
    fi
}

# ── VIEW LOG ──────────────────────────────────────────────────────────────────
view_log() {
    echo ""
    if [[ -f "$LOG_FILE" ]]; then
        echo "--- System Monitor Log ---"
        cat "$LOG_FILE"
    else
        echo "No log file found yet."
    fi
}

# ── MAIN LOOP ─────────────────────────────────────────────────────────────────
log_action "System monitor started."

while true; do
    show_menu
    read -r choice

    case "$choice" in
        1) view_processes ;;
        2) terminate_process ;;
        3) disk_inspection ;;
        4) view_log ;;
        5)
            read -rp "Are you sure you want to exit? (Y/N): " exit_confirm
            if [[ "$exit_confirm" =~ ^[Yy]$ ]]; then
                log_action "System monitor exited by user."
                echo "Bye!"
                exit 0
            else
                echo "Exit cancelled."
            fi
            ;;
        *)
            echo "Invalid option. Please select 1-5."
            log_action "Invalid menu input: '$choice'."
            ;;
    esac
done