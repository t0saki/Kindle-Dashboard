#!/bin/sh

# ================= Fix 1: 免疫死亡信号 =================
# 1 = SIGHUP (挂起), 15 = SIGTERM (终止)
# 这行命令让脚本在这个信号到来时"什么都不做"，从而存活下来
trap "" 1 15

# ================= 配置 =================
IMG_URL="https://i.tsk.im/file/1769529502784_131031517_p0_kindle.png"
# IMG_URL="http://192.168.x.x:8000/kindle.png" 
INTERVAL=3600
BASE_DIR="/mnt/us/extensions/Kindle-Dashboard"
FBINK_CMD="${BASE_DIR}/bin/fbink"
TMP_FILE="/tmp/dashboard_download.png"
LOG="/tmp/dashboard.log"
# =======================================

echo "[Daemon] Started with PID $$ (Trapped)" > "$LOG"

# 1. 停止 Framework (此时脚本会收到 SIGTERM 但会忽略)
echo "[Daemon] Stopping framework..." >> "$LOG"
stop framework
sleep 2

# 2. 疯狂猎杀 (新增 tar 和 gzip)
echo "[Daemon] Hunting processes..." >> "$LOG"

kill_process_by_keyword() {
    # 排除 grep 自身
    PIDS=$(ps aux | grep "$1" | grep -v grep | awk '{print $2}')
    if [ -n "$PIDS" ]; then
        echo " -> Killing $1 (PIDs: $PIDS)" >> "$LOG"
        for pid in $PIDS; do
            kill -9 $pid
        done
    fi
}

# 循环清洗 5 轮，确保杀掉所有复活怪
for i in 1 2 3 4 5; do
    # 基础 UI
    killall cvm
    killall KPPMainAppV2
    killall mesquite
    killall awesome
    
    # ================= Fix 2: 杀掉高 CPU/IO 进程 =================
    # 你的 ps 显示 gzip 占用了 90% CPU，必须杀
    killall gzip 
    killall tar
    
    # 杀掉崩溃转储脚本
    kill_process_by_keyword "dump-stack"
    kill_process_by_keyword "dmcc.sh"
    
    # 杀掉锁屏睡眠
    kill_process_by_keyword "sleep 180"
    
    # 强制清屏
    $FBINK_CMD -k -f -q
    sleep 1
done

echo "[Daemon] Cleanup done. Loop starting..." >> "$LOG"

# 3. 保持唤醒
lipc-set-prop com.lab126.powerd preventScreenSaver 1

# 4. 主循环
while true; do
    lipc-set-prop com.lab126.wifid enable 1
    sleep 5
    
    # 下载
    curl -k -L -s --fail --connect-timeout 20 --retry 2 "${IMG_URL}" -o "$TMP_FILE"
    RET=$?

    if [ $RET -eq 0 ] && [ -f "$TMP_FILE" ]; then
        $FBINK_CMD -q -W gc16 -f -g file="$TMP_FILE"
    else
        $FBINK_CMD -q -x 0 -y 0 "Err $RET"
    fi

    sleep "$INTERVAL"
done