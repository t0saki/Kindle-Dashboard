# Kindle Dashboard

[English](README-en.md)

一个简单的 KUAL 插件，能够将你的越狱版 Kindle 变成一个低功耗的电子墨水仪表盘。它会定期自动从指定的 URL 下载图片并显示在屏幕上。

## ✨ 功能特点

*   **独占模式**：自动关闭 Kindle 原生 Framework，防止原生界面干扰或进入休眠，完全接管屏幕控制权。
*   **自动联网**：每次更新前强制唤醒 WiFi，确保图片能够成功下载。
*   **定时刷新**：可自定义刷新间隔（默认 1 小时）。
*   **高质量渲染**：集成 [FBInk](https://github.com/NiLuJe/FBInk)，支持高质量波形刷新 (GC16)，减少残影。
*   **错误处理**：如果网络请求失败，会在屏幕上显示错误提示，而不是黑屏或卡死。
*   **本地时钟叠加**：支持在图片上方叠加显示当前时间，每分钟自动局部刷新，无需联网。
*   **智能休眠**：脚本会自动对齐系统时间，在每分钟的 00 秒唤醒刷新时钟，最大程度节省电量。
*   **图片预处理工具**：附带 Python 脚本，用于将普通图片转换为最适合 Kindle 显示的 16 级灰度抖动图像。

## 🛠️ 前置要求

1.  **Kindle 已越狱**。
2.  已安装 **KUAL** (Kindle Unified Application Launcher)。
3.  (可选) 已安装 MRPI (MobileRead Package Installer) 以便管理提取。

## 📥 安装步骤

1.  将本项目中的 `extensions` 文件夹复制到你的 Kindle 根目录。
    *   如果提示合并，请选择确认。
    *   最终路径结构应为：`Kindle磁盘根目录/extensions/Kindle-Dashboard/...`
2.  断开 USB 连接。

## ⚙️ 配置方法

默认配置位于 `extensions/Kindle-Dashboard/bin/run_daemon.sh` 文件中。你需要修改以下变量：

```bash
# 图片地址 (请修改为你服务端的实际地址)
IMG_URL="https://your-server.com/dashboard.png"

# 图片刷新间隔 (秒)
INTERVAL=300

# 全刷周期 (多少次局刷后执行一次全刷以清除残影)
FULL_REFRESH_CYCLE=12

# 屏幕旋转 (0=0°, 1=90°, 2=180°, 3=270°)
ROTATE=3

# =============== 本地时钟配置 ===============
# 是否开启本地时钟 (1=开启, 0=关闭)
ENABLE_LOCAL_CLOCK=1

# 时钟位置 (坐标取决于你的屏幕方向和分辨率)
CLOCK_X=300
CLOCK_Y=100
CLOCK_SIZE=80

# 字体路径 (可选，留空则使用 fbink 默认字体)
# CLOCK_FONT="${BASE_DIR}/IBMPlexMono-SemiBold.ttf"
```

**建议**：请确保你的服务端生成的图片分辨率与你的 Kindle 屏幕分辨率一致（例如 Kindle Oasis 2/3 为 1264x1680），以获得最佳显示效果。

## 🚀 使用方法

1.  在 Kindle 上打开 **KUAL**。
2.  点击 **Kindle-Dashboard** 菜单。
3.  点击 **Start Dashboard (No GUI)**。
4.  此时 Kindle 的原生界面将会消失，屏幕将开始刷新你的仪表盘图片。

> **⚠️ 注意**：启动时，屏幕可能会多次闪烁，并可能出现一些临时的报错信息（脚本正在清理后台进程）。这是正常现象，请耐心等待约 **1 分钟** 让服务完全启动。

**已验证设备**：本项目已在 **Kindle Oasis 2** 上通过测试。

**如何退出？**
由于脚本杀死了原生 Framework (`stop framework`)，你需要**长按 Kindle 电源键**重启设备才能恢复到正常的阅读模式。

## 🖼️ 图片转换工具

为了在 E-Ink 屏幕上获得最佳显示效果（避免严重的色阶断层），建议使用本仓库提供的 `convert_kindle_image.py` 脚本处理你的图片。

该脚本会自动执行：
1.  调整大小至目标分辨率 (默认 1264x1680)。
2.  转换为 16 级灰度。
3.  应用 Floyd-Steinberg 抖动算法。

**依赖安装：**
```bash
pip install pillow
```

**使用示例：**
```bash
python convert_kindle_image.py your_image.png
# 输出文件将命名为: your_image_k_fixed.png
```

## 📜 鸣谢 & 声明

*   **FBInk**: 本项目使用了 `FBInk` 工具用于屏幕刷新。
    *   文件路径: `extensions/Kindle-Dashboard/bin/fbink`
    *   该二进制文件编译自: [https://github.com/NiLuJe/FBInk](https://github.com/NiLuJe/FBInk)
    *   感谢 **NiLuJe** 开发了这个强大的 E-Ink 屏幕控制库。

## ⚠️ 免责声明

本项目需要越狱设备并修改系统进程。虽然一般来说是安全的，但请自行承担修改系统带来的风险。作者不对设备损坏负责。
