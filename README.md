# ChatGPT Proxy Launcher (macOS)

[English](README.md) | [中文](README.zh.md) | [한국어](README.ko.md) | [日本語](README.ja.md)

---

Fixes the ChatGPT/Codex desktop app (`com.openai.codex`) getting stuck on **"Reconnecting... x/5 / request timed out"** every time a new conversation starts, taking a long time before it finally replies.

## Background & Root Cause

- The ChatGPT desktop app consists of an Electron UI process plus a Rust core process. **Some requests from the Rust core (new-session connection setup / WebSocket streams) bypass the macOS system proxy and connect to the internet directly.**
- In network-restricted environments (e.g. mainland China): local DNS is poisoned (`chatgpt.com` resolves to fake IPs such as Facebook ranges, different on every query) and direct connections are blocked → connections hang until timeout.
- The app retries with `x/5` and only falls back to the proxied path after exhausting all 5 retries → "every new conversation takes forever".

## How It Works

A launcher app that, when starting ChatGPT, **injects proxy environment variables only for that app** (`HTTP_PROXY / HTTPS_PROXY / ALL_PROXY`), forcing all its requests through a local proxy:

- ✅ No effect on other apps (not a global setting)
- ✅ No extra proxy traffic (only ChatGPT's traffic goes through the node; no TUN needed)
- ✅ The original `ChatGPT.app` stays untouched
- ✅ **Auto-detects the proxy IP and port** — no manual config, works even if you switch proxy clients

## How the Proxy Address Is Determined

Priority (highest → lowest):

1. **`CHATGPT_PROXY` env var**: `CHATGPT_PROXY=http://127.0.0.1:7890 ./launcher.sh`
2. **Config file `~/.chatgpt-proxy-launcher.conf`**: write a line like `CHATGPT_PROXY=http://127.0.0.1:7890` (for a fixed proxy, no need to type the env var every time)
3. **Auto-detect the macOS system proxy** (`scutil --proxy`, trying HTTPS → HTTP → SOCKS in order)
4. **Fallback default** `http://127.0.0.1:10808`

Check the currently effective proxy address and reachability:

```bash
./launcher.sh --check
# Proxy address / 代理地址: http://127.0.0.1:10808
# Proxy status / 代理状态: reachable / 可达 ✓
```

A TCP reachability check runs before launch; it warns you if the proxy is not running, so you don't wait for nothing.

## Installation

```bash
./install.sh
```

Or manually:

```bash
mkdir -p ~/Applications/"ChatGPT Proxy.app"/Contents/{MacOS,Resources}
cp Info.plist ~/Applications/"ChatGPT Proxy.app"/Contents/Info.plist
cp launcher.sh ~/Applications/"ChatGPT Proxy.app"/Contents/MacOS/launcher
chmod +x ~/Applications/"ChatGPT Proxy.app"/Contents/MacOS/launcher
cp /Applications/ChatGPT.app/Contents/Resources/electron.icns \
   ~/Applications/"ChatGPT Proxy.app"/Contents/Resources/ 2>/dev/null
```

## Usage

1. `Cmd+Q` to fully quit the original ChatGPT (closing the window is not enough)
2. Launch from `~/Applications/ChatGPT Proxy.app` (drag it to the Dock if you like)
3. New conversations should no longer show "Reconnecting... /5"

> Switched proxy clients or ports? No changes needed — the launcher auto-detects the system proxy. To force a specific one, set `CHATGPT_PROXY` or write the config file.

## Uninstall

```bash
rm -rf ~/Applications/"ChatGPT Proxy.app"
rm -f ~/.chatgpt-proxy-launcher.conf   # only if you created it
```

## Verification

Check that the app's connections all go through the proxy (no direct SYN_SENT hangs):

```bash
lsof -nP -iTCP | grep -E 'codex|ChatGPT' | grep -v 127.0.0.1
```

If direct connections remain, that connection type does not read env vars (e.g. WebSocket). Consider TUN mode with a **minimal routing rule that proxies only OpenAI domains** (avoids the default TUN routing all overseas traffic through the node and burning through your quota).

---

## 🤖 Powered by DSH

This project was built end-to-end by **DeepSeek Harness (DSH)** — problem diagnosis, solution design, implementation, and repository creation & push, all performed by DSH on the local machine, including:

- **Reproducing the issue with real measurements**: connection stability tests (old node: 2/8 timeouts → new node: 0/8 failures), DNS poisoning detection (`chatgpt.com` resolving to fake Facebook-range IPs, different on each query), process network analysis (caught the `codex` process with a stuck SYN_SENT to `168.143.171.186:443`)
- **Root cause**: the Rust core bypasses the system proxy and connects directly, hitting DNS-poisoned fake IPs that are blocked → reconnect timeouts
- **Design & implementation**: a proxy launcher (auto-detects the system proxy IP/port; injects proxy env vars for this app only; no TUN, no global side effects, no extra proxy traffic)
- **Writing docs & pushing this repository**

> If you hit the same "Reconnecting... x/5 / request timed out" issue, hope this helps — it is itself a fully DSH-generated work.
