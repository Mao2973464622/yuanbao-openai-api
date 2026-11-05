#!/bin/bash
# 元宝 API 服务启动/重启脚本
# 用法: bash ~/pure_protocol/start.sh  [restart|stop|status]
cd ~/pure_protocol || exit 1

case "$1" in
  stop)
    pkill -f 'yuanbao-server' 2>/dev/null
    echo "[yuanbao] 已停止"
    ;;
  status)
    if pgrep -f 'yuanbao-server' >/dev/null 2>&1; then
      echo "[yuanbao] 运行中 (PID $(pgrep -f 'yuanbao-server' | head -1))"
      curl -s -m 5 http://127.0.0.1:8788/healthz 2>/dev/null && echo
    else
      echo "[yuanbao] 未运行"
    fi
    ;;
  restart)
    pkill -f 'yuanbao-server' 2>/dev/null
    sleep 2
    setsid nohup node yuanbao-server.js > server_pure.log 2>&1 < /dev/null &
    echo $! > server_pure.pid
    sleep 4
    echo "[yuanbao] 已重启 (PID $(cat server_pure.pid))"
    curl -s -m 5 http://127.0.0.1:8788/healthz 2>/dev/null && echo
    ;;
  *)
    # 默认启动（若已在跑则跳过）
    if pgrep -f 'yuanbao-server' >/dev/null 2>&1; then
      echo "[yuanbao] 已在运行 (PID $(pgrep -f 'yuanbao-server' | head -1))"
    else
      setsid nohup node yuanbao-server.js > server_pure.log 2>&1 < /dev/null &
      echo $! > server_pure.pid
      sleep 4
      echo "[yuanbao] 已启动 (PID $(cat server_pure.pid))"
    fi
    curl -s -m 5 http://127.0.0.1:8788/healthz 2>/dev/null && echo
    ;;
esac