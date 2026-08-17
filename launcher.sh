#!/bin/bash
# ChatGPT Proxy Launcher (macOS)
# Fixes the ChatGPT/Codex desktop app (com.openai.codex) getting stuck on
# "Reconnecting... x/5 / request timed out" for every new conversation.
#
# Why: the Rust core of the desktop app bypasses the macOS system proxy and
# connects directly, hitting DNS-poisoned fake IPs that are blocked (GFW).
# This launcher injects proxy env vars into the app only.
#
# Proxy address resolution (highest priority first):
#   1. CHATGPT_PROXY env var
#   2. Config file ~/.chatgpt-proxy-launcher.conf (e.g. CHATGPT_PROXY=http://127.0.0.1:7890)
#   3. Auto-detect macOS system proxy (scutil --proxy, HTTPS -> HTTP -> SOCKS)
#   4. Fallback default http://127.0.0.1:10808
#
# Usage:
#   ./launcher.sh             # detect proxy and launch ChatGPT
#   ./launcher.sh --check     # print effective proxy address & reachability only
#   CHATGPT_PROXY=http://127.0.0.1:7890 ./launcher.sh

APP_BIN="/Applications/ChatGPT.app/Contents/MacOS/ChatGPT"

# --- optional config file ---
CONF_FILE="$HOME/.chatgpt-proxy-launcher.conf"
[ -f "$CONF_FILE" ] && . "$CONF_FILE"

# --- detect macOS system proxy ---
detect_system_proxy() {
  local out host port
  out=$(scutil --proxy 2>/dev/null) || return 1

  # try HTTPS -> HTTP -> SOCKS
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

# --- resolve proxy address ---
PROXY_ADDR="${CHATGPT_PROXY:-$(detect_system_proxy)}"
PROXY_ADDR="${PROXY_ADDR:-http://127.0.0.1:10808}"

# --- TCP reachability check ---
check_reachable() {
  local url="$1" host port
  host="${url#*://}"; host="${host%%:*}"
  port="${url##*:}";  port="${port%%/*}"
  if [ -n "$host" ] && [[ "$port" =~ ^[0-9]+$ ]]; then
    (exec 3<>"/dev/tcp/$host/$port") 2>/dev/null && return 0
  fi
  return 1
}

# --- --check mode: print proxy info only ---
if [ "$1" = "--check" ]; then
  echo "Proxy address / 代理地址: $PROXY_ADDR"
  if check_reachable "$PROXY_ADDR"; then
    echo "Proxy status / 代理状态: reachable / 可达 ✓"
  else
    echo "Proxy status / 代理状态: NOT reachable / 不可达 ✗"
    echo "Start your proxy client, or set CHATGPT_PROXY to the correct address."
    echo "请先启动代理客户端，或用 CHATGPT_PROXY 指定正确的 IP 和端口。"
  fi
  exit 0
fi

if [ ! -x "$APP_BIN" ]; then
  echo "Error: $APP_BIN not found. Please install the ChatGPT desktop app first."
  echo "错误：未找到 $APP_BIN，请确认已安装 ChatGPT 桌面版" >&2
  exit 1
fi

if ! check_reachable "$PROXY_ADDR"; then
  echo "Warning: proxy $PROXY_ADDR is not reachable; ChatGPT may still hit reconnect timeouts."
  echo "警告：代理 $PROXY_ADDR 不可达，ChatGPT 可能仍会重连超时。" >&2
  echo "Start your proxy client, or set CHATGPT_PROXY to the correct IP and port."
  echo "请确认代理客户端已启动，或用 CHATGPT_PROXY 指定正确的 IP 和端口。" >&2
fi

export HTTP_PROXY="$PROXY_ADDR"
export HTTPS_PROXY="$PROXY_ADDR"
export ALL_PROXY="$PROXY_ADDR"
export NO_PROXY="localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12"

echo "ChatGPT Proxy: using proxy $PROXY_ADDR / 使用代理 $PROXY_ADDR" >&2
exec "$APP_BIN" "$@"
