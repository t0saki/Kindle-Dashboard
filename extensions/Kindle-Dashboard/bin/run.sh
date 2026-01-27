#!/bin/sh

# ================= 配置区域 =================
# 图片地址 (请修改为你服务端的实际地址)
IMG_URL="https://i.tsk.im/file/1769529502784_131031517_p0_kindle.png"

# 刷新间隔 (秒)
INTERVAL=3600

# FBInk 路径 (自动定位到当前脚本的上级目录的 bin/fbink)
BASE_DIR="/mnt/us/extensions/Kindle-Dashboard"
FBINK_CMD="${BASE_DIR}/bin/fbink"
TMP_FILE="/tmp/dashboard_download.png"
# ===========================================

# 1. 杀死原生 Framework (必须步骤)
# 这会关闭 Kindle 的原生 UI，释放屏幕控制权
# 注意：执行后 KUAL 界面也会消失，这是正常的
if pidof cvm > /dev/null; then
    stop framework
fi

# 2. 禁止休眠 & 屏幕保护
lipc-set-prop com.lab126.powerd preventScreenSaver 1

# 3. 循环拉取显示
while true; do
    # [关键] 强制唤醒 WiFi
    # Kindle 在不操作时会很快切断 WiFi，这行命令强制保持连接
    lipc-set-prop com.lab126.wifid enable 1
    
    # 等待几秒让 WiFi 也就是 (可选，如果发现拉取失败多，可适当增加)
    sleep 2

    # 下载图片
    # -q: 静默模式
    # -O: 输出文件
    # ?t=$(date +%s): 添加时间戳参数，防止中间代理或路由缓存图片
    # curl -k -L -s --fail "${IMG_URL}?t=$(date +%s)" -o "$TMP_FILE"
    curl -k -L -s --fail "${IMG_URL}" -o "$TMP_FILE"

    # 检查下载是否成功
    if [ $? -eq 0 ] && [ -f "$TMP_FILE" ]; then
        # 渲染图片
        # -W gc16: 使用高质量波形 (注意是大写 W)
        # -f: 强制刷新 (Flash)
        # -g file=...: 图片模式
        $FBINK_CMD -q -W gc16 -f -g file="$TMP_FILE"
    else
        # 如果下载失败 (比如 WiFi 还没连上)，在左上角打印一个小错误提示
        # 不使用 -f 闪屏，避免报错时闪瞎眼
        $FBINK_CMD -q -x 0 -y 0 "WiFi/DL Error: $(date +%H:%M:%S)"
    fi

    # 等待下一次刷新
    sleep "$INTERVAL"
done