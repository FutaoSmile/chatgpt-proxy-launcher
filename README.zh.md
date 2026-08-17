# ChatGPT 代理启动器 (macOS)

[English](README.md) | [中文](README.zh.md) | [한국어](README.ko.md) | [日本語](README.ja.md)

---

解决 ChatGPT/Codex 桌面版（`com.openai.codex`）**每次新建对话卡在「正在重新连接 x/5 / request timed out」，等很久才开始回复** 的问题。

## 背景与根因

- ChatGPT 桌面版由 Electron 界面进程 + Rust 核心进程组成。**Rust 核心进程的部分请求（新建会话时的建连/WebSocket 流）不走 macOS 系统代理，而是直连外网**。
- 国内网络环境下：本地 DNS 被投毒（`chatgpt.com` 被解析成 Facebook 段等假 IP，且每次查询结果不同）+ 直连被墙 → 连接挂起直到超时。
- App 按 `x/5` 重试，5 次全失败后才通过走代理的路径发出请求 → 表现为「每次新对话都要等很久」。

## 原理

通过一个启动器 App，在启动 ChatGPT 时**只为它**注入代理环境变量（`HTTP_PROXY / HTTPS_PROXY / ALL_PROXY`），强制其所有请求走本地代理：

- ✅ 不影响其他应用（非全局设置）
- ✅ 不消耗额外代理流量（只有 ChatGPT 的流量走节点，无需 TUN）
- ✅ 原版 `ChatGPT.app` 保持不动
- ✅ **自动检测代理 IP 和端口**：无需手改配置，换代理客户端也能用

## 代理地址怎么确定

自动按以下优先级取值（高 → 低）：

1. **`CHATGPT_PROXY` 环境变量**：`CHATGPT_PROXY=http://127.0.0.1:7890 ./launcher.sh`
2. **配置文件 `~/.chatgpt-proxy-launcher.conf`**：内容写一行 `CHATGPT_PROXY=http://127.0.0.1:7890`（适合固定代理、不想每次敲环境变量）
3. **自动检测 macOS 系统代理设置**（`scutil --proxy`，依次尝试 HTTPS → HTTP → SOCKS 协议）
4. **兜底默认值** `http://127.0.0.1:10808`

查看当前实际生效的代理地址与可达性：

```bash
./launcher.sh --check
# 代理地址 / Proxy address: http://127.0.0.1:10808
# 代理状态 / Proxy status: 可达 / reachable ✓
```

启动前会做一次 TCP 可达性检查，代理没启动时会给出警告，避免白等。

## 安装

```bash
./install.sh
```

或手动：

```bash
mkdir -p ~/Applications/"ChatGPT Proxy.app"/Contents/{MacOS,Resources}
cp Info.plist ~/Applications/"ChatGPT Proxy.app"/Contents/Info.plist
cp launcher.sh ~/Applications/"ChatGPT Proxy.app"/Contents/MacOS/launcher
chmod +x ~/Applications/"ChatGPT Proxy.app"/Contents/MacOS/launcher
cp /Applications/ChatGPT.app/Contents/Resources/electron.icns \
   ~/Applications/"ChatGPT Proxy.app"/Contents/Resources/ 2>/dev/null
```

## 使用

1. `Cmd+Q` 完全退出原版 ChatGPT（不是关窗口）
2. 从 `~/Applications/ChatGPT Proxy.app` 启动（可拖入 Dock）
3. 新建对话应不再出现「正在重新连接 /5」

> 换了代理客户端或端口？不需要改任何东西——启动器会自动检测系统代理设置；想强制指定就设置 `CHATGPT_PROXY` 或写配置文件。

## 卸载

```bash
rm -rf ~/Applications/"ChatGPT Proxy.app"
rm -f ~/.chatgpt-proxy-launcher.conf   # 如创建过配置文件
```

## 验证方法

启动后检查 App 进程连接是否全部走代理（不再有直连外网的 SYN_SENT 挂起）：

```bash
lsof -nP -iTCP | grep -E 'codex|ChatGPT' | grep -v 127.0.0.1
```

若仍有直连，说明该连接类型不读环境变量（如 WebSocket），可考虑 TUN 模式并配合**只代理 OpenAI 域名的精简路由规则**（避免默认 TUN 把所有境外流量都塞进代理导致流量暴增）。

---

## 🤖 Powered by DSH

本项目由 **DeepSeek Harness (DSH)** 端到端自动完成——从问题诊断、方案设计、代码实现，到 GitHub 仓库的创建与推送，全程由 DSH 在本机上操作，包括：

- **实测复现问题**：连接稳定性测试（旧节点 8 连 2 超时 → 新节点 8 连 0 失败）、DNS 投毒检测（`chatgpt.com` 被解析成 Facebook 段等假 IP 且每次结果不同）、进程网络连接分析（抓到 `codex` 进程直连 `168.143.171.186:443` 的 SYN_SENT 挂起）
- **定位根因**：ChatGPT 桌面版 Rust 核心进程绕过系统代理直连外网，撞上 DNS 投毒假 IP 被墙 → 重连超时
- **设计并实现方案**：代理启动器（自动检测系统代理 IP/端口，只为该 App 注入代理环境变量，无 TUN、无全局副作用、不烧代理流量）
- **编写文档并推送本仓库**

> 如果你也遇到了同样的 "正在重新连接 x/5 / request timed out" 问题，希望这个项目能帮到你；它本身就是 DSH 全自动产出的作品。
