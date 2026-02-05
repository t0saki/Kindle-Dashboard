#!/bin/sh

# ================= Fix 1: 免疫死亡信号 =================
# 1 = SIGHUP (挂起), 15 = SIGTERM (终止)
# 这行命令让脚本在这个信号到来时"什么都不做"，从而存活下来
trap "" 1 15

# ================= 配置 =================
IMG_URL="https://i.tsk.im/file/1769588501760_test_output_dashboard.png"
# IMG_URL="http://192.168.x.x:8000/kindle.png"

# 图片刷新间隔 (秒) - 保持你原来的设置
INTERVAL=300

# 全刷间隔
FULL_REFRESH_CYCLE=12
BASE_DIR="/mnt/us/extensions/Kindle-Dashboard"
FBINK_CMD="${BASE_DIR}/bin/fbink"
TMP_FILE="/tmp/dashboard_download.png"
LOG="/tmp/dashboard.log"
SAFETY_LOCK="/mnt/us/STOP_DASH"
PING_TARGET="223.5.5.5" 
ROTATE=3

# =============== [新增] 本地时钟配置 ===============
ENABLE_LOCAL_CLOCK=1
# 坐标需根据图片留白位置调整 (Kindle Oasis 2 分辨率 1680x1264)
# 假设你在左上角留了白
CLOCK_X=40
CLOCK_Y=295
CLOCK_SIZE=80
# 字体路径 (可选，留空则使用 fbink 默认)
CLOCK_FONT="${BASE_DIR}/IBMPlexMono-SemiBold.ttf"
# 时间格式: 12 或 24
TIME_FORMAT=12

# [新增] 连续失败计数器
FAIL_COUNT=0
# [新增] 最大允许失败次数 (比如 5分钟一次，连续失败 12次 = 1小时)
MAX_FAIL_COUNT=6

# =================================================

echo "[Daemon] Started with PID $$ (Trapped)" > "$LOG"

# 1. 停止 Framework
echo "[Daemon] Stopping framework..." >> "$LOG"
stop framework
sleep 2

# 2. 疯狂猎杀
echo "[Daemon] Hunting processes..." >> "$LOG"

kill_process_by_keyword() {
    PIDS=$(ps aux | grep "$1" | grep -v grep | awk '{print $2}')
    if [ -n "$PIDS" ]; then
        echo " -> Killing $1 (PIDs: $PIDS)" >> "$LOG"
        for pid in $PIDS; do
            kill -9 $pid
        done
    fi
}

for i in 1 2 3 4 5; do
    killall cvm
    killall KPPMainAppV2
    killall mesquite
    killall awesome
    
    # Fix 2: 杀掉高 CPU/IO 进程
    killall gzip 
    killall tar
    
    kill_process_by_keyword "dump-stack"
    kill_process_by_keyword "dmcc.sh"
    kill_process_by_keyword "sleep 180"
    
    $FBINK_CMD -k -f -q
    sleep 1
done

echo "[Daemon] Cleanup done. Loop starting..." >> "$LOG"

# 3. 保持唤醒
lipc-set-prop com.lab126.powerd preventScreenSaver 1

# 计数器初始化
COUNT=0
# 确保第一次运行立即下载
NEXT_FETCH_TIME=0

sleep 15

# 4. 主循环
while true; do
    # 安全阀检查
    if [ -f "$SAFETY_LOCK" ]; then
        exit 0
    fi

    CURRENT_EPOCH=$(date +%s)
    
    # [Fix 2] 每次循环强制刷新电源锁，防止 Powerd 24小时后“遗忘”
    lipc-set-prop com.lab126.powerd preventScreenSaver 1
    iw wlan0 set power_save off
    
    echo $ROTATE > /sys/class/graphics/fb0/rotate

    # ================= 网络看门狗逻辑 =================
    # 每次循环都先 ping 一下。
    # 作用1: Keep-Alive (防止网卡休眠)
    # 作用2: Health Check (检测是否断连)
    
    ping -c 3 -W 5 "$PING_TARGET" > /dev/null 2>&1
    PING_RET=$?

    if [ $PING_RET -ne 0 ]; then
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "[Warn] Network lost (Ping $PING_RET). Fail count: $FAIL_COUNT" >> "$LOG"
        
        # 显示一个小的 WiFi 丢失图标或文字 (可选)
        # $FBINK_CMD -q -x 0 -y 0 "WiFi Lost $FAIL_COUNT"

        if [ $FAIL_COUNT -ge $MAX_FAIL_COUNT ]; then
            echo "[Fatal] Network dead for too long. Rebooting device..." >> "$LOG"
            # 绝杀：如果网络挂了1小时，直接重启系统以重置网卡驱动状态
            reboot
        fi

        # --- 第一阶段：尝试温和重连 (L2 Reconnect) ---
        echo "[Fix] Trying wpa_cli reconnect..." >> "$LOG"
        wpa_cli -i wlan0 reconnect
        sleep 5
        
        # --- 第二阶段：强制 DHCP 续约 (L3 Renew) [关键点] ---
        # 很多时候是 IP 丢了而不是 WiFi 断了
        echo "[Fix] Renewing DHCP..." >> "$LOG"
        udhcpc -i wlan0 -n -t 5 -q
        
        # --- 第三阶段：如果还不行，核弹级重置网卡 ---
        # 仅在失败次数较多时执行，避免频繁开关
        if [ $FAIL_COUNT -gt 2 ]; then
             echo "[Fix] Resetting wifid..." >> "$LOG"
             lipc-set-prop com.lab126.wifid enable 0
             sleep 2
             lipc-set-prop com.lab126.wifid enable 1
             sleep 15 # 给够时间重新协商
        fi

    else
        # 网络正常，重置计数器
        FAIL_COUNT=0
    fi

    # ================= 图片下载逻辑 =================
    if [ $CURRENT_EPOCH -ge $NEXT_FETCH_TIME ]; then
        # 只有当网络看起来正常(或刚尝试修复后)才下载
        # 增加 connect-timeout 防止 curl 卡死太久
        curl -k -L -s --fail --connect-timeout 20 --max-time 60 --retry 1 "${IMG_URL}" -o "$TMP_FILE"
        RET=$?

        if [ $RET -eq 0 ] && [ -f "$TMP_FILE" ]; then
            
            COUNT=$((COUNT + 1))
            
            if [ $COUNT -ge $FULL_REFRESH_CYCLE ]; then
                # 【全刷模式】
                $FBINK_CMD -q -W gc16 -f -g file="$TMP_FILE"
                COUNT=0
            else
                # 【局刷模式】
                # 注意：这里图片会覆盖掉屏幕上已有的任何内容（包括旧时钟）
                $FBINK_CMD -q -W gl16 -g file="$TMP_FILE"
            fi
            
            # 更新下次下载时间
            NEXT_FETCH_TIME=$((CURRENT_EPOCH + INTERVAL))
            
            # 下载成功也清零失败计数
            FAIL_COUNT=0
        else
            # 下载失败
            echo "[Err] Curl failed ($RET)" >> "$LOG"
            $FBINK_CMD -q -x 0 -y 0 "Err $RET"
            # 缩短重试时间
            NEXT_FETCH_TIME=$((CURRENT_EPOCH + 60))
        fi
    fi
    # ==========================================================


    # ================= 2. 前景层：本地时钟逻辑 =================
    # 无论刚才是否画了图片，这里都要画时钟。
    # 1. 如果刚才没画图片：这是每分钟的常规更新，覆盖旧时间。
    # 2. 如果刚才画了图片：图片把旧时间盖住了，这里正好把时间“补”在图片上层。
    
    if [ "$ENABLE_LOCAL_CLOCK" -eq 1 ]; then
        # 重新获取当前时间 (确保如果下载耗时很久，时间依然准确)
        if [ "$TIME_FORMAT" -eq 12 ]; then
            TIME_STR=$(date "+%I:%M")
        else
            TIME_STR=$(date "+%H:%M")
        fi
        
        # 绘制时间，空格保证无残留
        $FBINK_CMD -q -t "regular=$CLOCK_FONT,size=$CLOCK_SIZE,left=$CLOCK_X,top=$CLOCK_Y" "$TIME_STR "
    fi
    # =====================================================


    # ================= 3. 智能休眠 =================
    # 计算距离下一分钟 (:00) 还有多久
    NOW=$(date +%s)
    SLEEP_TIME=$((60 - (NOW % 60)))
    [ "$SLEEP_TIME" -le 0 ] && SLEEP_TIME=1
    sleep "$SLEEP_TIME"
    
done
