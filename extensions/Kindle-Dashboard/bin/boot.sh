#!/bin/sh

LOG="/tmp/dashboard.log"
echo "========================================" > "$LOG"
echo "[Boot-1] Triggered at $(date)" >> "$LOG"

BASE_DIR="/mnt/us/extensions/Kindle-Dashboard"
DAEMON="$BASE_DIR/bin/run_daemon.sh"

if [ ! -f "$DAEMON" ]; then
    echo "[Boot-Error] Daemon script not found!" >> "$LOG"
    exit 1
fi

echo "[Boot-2] Preparing to detach..." >> "$LOG"

# 双重 Fork 结构
(
    (
        echo "[Boot-3] Child process waiting 5s for UI release..." >> "$LOG"
        sleep 5
        
        echo "[Boot-4] Launching daemon: $DAEMON" >> "$LOG"
        # 使用 exec 替换当前 shell，节省资源
        exec /bin/sh "$DAEMON" >> "$LOG" 2>&1
    ) &
)

echo "[Boot-5] Parent exiting immediately." >> "$LOG"
exit 0