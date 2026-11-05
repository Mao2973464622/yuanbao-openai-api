#!/bin/bash
# 元宝 API 服务启动/重启脚本（双模式：预览 / 保存）
# 用法:
#   bash start.sh            # 启动（默认预览模式：生图只返回URL，对话里渲染远程图片）
#   bash start.sh preview    # 预览模式：生图只返回 URL，不落盘（对话里直接渲染图片）
#   bash start.sh save       # 保存模式：生图自动下载到 /sdcard/Download/yuanbao-img/
#   bash start.sh restart    # 重启（沿用当前模式）
#   bash start.sh stop       # 停止
#   bash start.sh status     # 状态
cd ~/pure_protocol || exit 1

MODE_FILE=~/.yuanbao_img_mode

set_mode() { echo "$1" > "$MODE_FILE"; }
get_mode() { if [ -f "$MODE_FILE" ]; then cat "$MODE_FILE"; else echo "preview"; fi; }

start_server() {
  local mode; mode=$(get_mode)
  local imgflag; if [ "$mode" = "save" ]; then imgflag="YUANBAO_IMG_SAVE=1"; else imgflag="YUANBAO_IMG_SAVE=0"; fi
  setsid nohup env $imgflag node yuanbao-server.js > server_pure.log 2>&1 < /dev/null &
  echo $! > server_pure.pid
  sleep 4
  echo "[yuanbao] 已启动 (PID $(cat server_pure.pid)) 模式=$mode"
  curl -s -m 5 http://127.0.0.1:8788/healthz 2>/dev/null && echo
}

case "$1" in
  preview)
    set_mode preview
    echo "[yuanbao] 切换到 预览模式：生图只返回 URL，对话里渲染"
    pkill -f 'yuanbao-server' 2>/dev/null; sleep 2
    start_server
    ;;
  save)
    set_mode save
    echo "[yuanbao] 切换到 保存模式：生图自动下载到 /sdcard/Download/yuanbao-img/"
    pkill -f 'yuanbao-server' 2>/dev/null; sleep 2
    start_server
    ;;
  restart)
    pkill -f 'yuanbao-server' 2>/dev/null; sleep 2
    start_server
    ;;
  stop)
    pkill -f 'yuanbao-server' 2>/dev/null
    echo "[yuanbao] 已停止"
    ;;
  status)
    if pgrep -f 'yuanbao-server' >/dev/null 2>&1; then
      echo "[yuanbao] 运行中 (PID $(pgrep -f 'yuanbao-server' | head -1)) 模式=$(get_mode)"
      curl -s -m 5 http://127.0.0.1:8788/healthz 2>/dev/null && echo
    else
      echo "[yuanbao] 未运行"
    fi
    ;;
  *)
    if pgrep -f 'yuanbao-server' >/dev/null 2>&1; then
      echo "[yuanbao] 已在运行 (PID $(pgrep -f 'yuanbao-server' | head -1)) 模式=$(get_mode)"
    else
      start_server
    fi
    curl -s -m 5 http://127.0.0.1:8788/healthz 2>/dev/null && echo
    ;;
esac