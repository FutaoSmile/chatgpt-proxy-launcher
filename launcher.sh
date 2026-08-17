#!/bin/bash
# ChatGPT Proxy Launcher (macOS)
# 解决 ChatGPT/Codex 桌面版 (com.openai.codex) 每次新建对话卡在
# "正在重新连接 x/5 / request timed out" 的问题。
#
# 原理：ChatGPT 桌面版的 Rust 核心进程部分请求不走 macOS 系统代理而直连外网，
# 在国内网络环境下会撞上 DNS 投毒的假 IP 并因直连被墙而超时。
# 本启动器只为该 App 注入代理环境变量，强制其所有请求走本地代理。
#
# 代理地址确定顺序（优先级从高到低）：
#   1. CHATGPT_PROXY 环境变量
#   2. 配置文件 ~/.chatgpt-proxy-launcher.conf（内容如：CHATGPT_PROXY=http://127.0.0.1:7890）
#   3. 自动检测 macOS 系统代理设置（scutil --proxy，HTTPS -> HTTP -> SOCKS）
#   4. 兜底默认值 http://127.0.0.1:10808
#
# 用法：
#   ./launcher.sh             # 检测并使用代理启动 ChatGPT
#   ./launcher.sh --check     # 仅打印将使用的代理地址与可达性，不启动 App
#   CHATGPT_PROXY=http://127.0.0.1:7890 ./launcher.sh

APP_BIN="/Applications/ChatGPT.app/Contents/MacOS/ChatGPT"

# --- 读取配置文件（可选） ---
CONF_FILE="$HOME/.chatgpt-proxy-launcher.conf"
[ -f "$CONF_FILE" ] && . "$CONF_FILE"

# --- 自动检测系统代理 ---
detect_system_proxy() {
  local out host port
  out=$(scutil --proxy 2>/dev/null) || return 1

  # 依次尝试 HTTPS -> HTTP -> SOCKS
  if echo "$out" | grep -q 'HTTPSEnable *: *1'; then
    host=$(echo "$out" | awk -F': ' '/HTTPSProxy/ {gsub(/^ +| +$/,"",$2); print $2; exit}')
    port=$(echo "$out" | awk -F': ' '/HTTPSPort/  {gsub(/^ +| +$/,"",$2); print $2; exit}')
    [ -n "$host" ] && [ -n "$port" ] && { echo "http://$host:$port"; return 0; }
  fi
  if echo "$out" | grep -q 'HTTPEnable *: *1'; then
    host=$(echo "$out" | awk -F': ' '/HTTPProxy/ {gsub(/^ +| +$/,"",$2); print $2; exit}')
    port=$(echo "$out" | awk -F': ' '/HTTPPort/  {gsub(/^ +| +$/,"",$2); print $2; exit}')
    [ -n "$host" ] && [ -n "$port" ] && { echo "http://$host:$port"; return 0; }
  fi
  if echo "$out" | grep -q 'SOCKSEnable *: *1'; then
    host=$(echo "$out" | awk -F': ' '/SOCKSProxy/ {gsub(/^ +| +$/,"",$2); print $2; exit}')
    port=$(echo "$out" | awk -F': ' '/SOCKSPort/  {gsub(/^ +| +$/,"",$2); print $2; exit}')
    [ -n "$host" ] && [ -n "$port" ] && { echo "socks5://$host:$port"; return 0; }
  fi
  return 1
}

# --- 代理地址确定 ---
PROXY_ADDR="${CHATGPT_PROXY:-$(detect_system_proxy)}"
PROXY_ADDR="${PROXY_ADDR:-http://127.0.0.1:10808}"

# --- TCP 可达性检查 ---
check_reachable() {
  local url="$1" host port
  host="${url#*://}"; host="${host%%:*}"
  port="${url##*:}";  port="${port%%/*}"
  if [ -n "$host" ] && [[ "$port" =~ ^[0-9]+$ ]]; then
    (exec 3<>"/dev/tcp/$host/$port") 2>/dev/null && return 0
  fi
  return 1
}

# --- --check 模式：只打印代理信息 ---
if [ "$1" = "--check" ]; then
  echo "代理地址: $PROXY_ADDR"
  if check_reachable "$PROXY_ADDR"; then
    echo "代理状态: 可达 ✓"
  else
    echo "代理状态: 不可达 ✗（请确认代理客户端已启动，或用 CHATGPT_PROXY 指定正确地址）"
  fi
  exit 0
fi

if [ ! -x "$APP_BIN" ]; then
  echo "错误：未找到 $APP_BIN，请确认已安装 ChatGPT 桌面版" >&2
  exit 1
fi

if ! check_reachable "$PROXY_ADDR"; then
  echo "警告：代理 $PROXY_ADDR 不可达，ChatGPT 可能仍会重连超时。" >&2
  echo "请确认代理客户端已启动，或用 CHATGPT_PROXY 指定正确的 IP 和端口。" >&2
fi

export HTTP_PROXY="$PROXY_ADDR"
export HTTPS_PROXY="$PROXY_ADDR"
export ALL_PROXY="$PROXY_ADDR"
export NO_PROXY="localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12"

echo "ChatGPT Proxy: 使用代理 $PROXY_ADDR" >&2
exec "$APP_BIN" "$@"
