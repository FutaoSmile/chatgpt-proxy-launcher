#!/bin/bash
# ChatGPT Proxy Launcher (macOS)
# 解决 ChatGPT/Codex 桌面版 (com.openai.codex) 每次新建对话卡在
# "正在重新连接 x/5 / request timed out" 的问题。
#
# 原理：ChatGPT 桌面版的 Rust 核心进程部分请求不走 macOS 系统代理而直连外网，
# 在国内网络环境下会撞上 DNS 投毒的假 IP 并因直连被墙而超时。
# 本启动器只为该 App 注入代理环境变量，强制其所有请求走本地代理。
#
# 自定义代理地址：CHATGPT_PROXY=http://127.0.0.1:7890 ./launcher.sh

PROXY_ADDR="${CHATGPT_PROXY:-http://127.0.0.1:10808}"
APP_BIN="/Applications/ChatGPT.app/Contents/MacOS/ChatGPT"

if [ ! -x "$APP_BIN" ]; then
  echo "错误：未找到 $APP_BIN，请确认已安装 ChatGPT 桌面版" >&2
  exit 1
fi

export HTTP_PROXY="$PROXY_ADDR"
export HTTPS_PROXY="$PROXY_ADDR"
export ALL_PROXY="$PROXY_ADDR"
export NO_PROXY="localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12"

exec "$APP_BIN" "$@"
