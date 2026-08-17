# ChatGPT プロキシランチャー (macOS)

[English](README.md) | [中文](README.zh.md) | [한국어](README.ko.md) | [日本語](README.ja.md)

---

ChatGPT/Codex デスクトップアプリ（`com.openai.codex`）が**新しい会話を始めるたびに「Reconnecting... x/5 / request timed out」**で止まり、かなり待ってからようやく応答する問題を解決します。

## 背景と根本原因

- ChatGPT デスクトップアプリは Electron UI プロセス + Rust コアプロセスで構成されています。**Rust コアプロセスの一部のリクエスト（新規セッションの接続確立 / WebSocket ストリーム）は macOS のシステムプロキシを経由せず、インターネットへ直接接続します。**
- ネットワーク制限のある環境（例：中国本土）では、ローカル DNS が汚染され（`chatgpt.com` がクエリごとに異なる偽 IP、例：Facebook 帯域に解決される）、直接接続がブロックされます → 接続がタイムアウトするまでハングします。
- アプリは `x/5` で再試行し、5 回すべて失敗して初めてプロキシ経由のパスにフォールバックします →「新しい会話のたびに時間がかかる」という症状になります。

## 仕組み

ChatGPT を起動するときに**そのアプリにだけ**プロキシ環境変数（`HTTP_PROXY / HTTPS_PROXY / ALL_PROXY`）を注入するランチャーアプリです。

- ✅ 他のアプリに影響なし（グローバル設定ではない）
- ✅ 追加のプロキシ通信なし（ChatGPT の通信だけがノードを経由、TUN 不要）
- ✅ オリジナルの `ChatGPT.app` はそのまま
- ✅ **プロキシの IP/ポートを自動検出** — 手動設定不要、プロキシクライアントを変えても動作

## プロキシアドレスの決定方法

優先順位（高い → 低い）:

1. **`CHATGPT_PROXY` 環境変数**: `CHATGPT_PROXY=http://127.0.0.1:7890 ./launcher.sh`
2. **設定ファイル `~/.chatgpt-proxy-launcher.conf`**: `CHATGPT_PROXY=http://127.0.0.1:7890` の1行を記述（固定プロキシ用、毎回環境変数を入力する必要がない）
3. **macOS システムプロキシの自動検出**（`scutil --proxy`、HTTPS → HTTP → SOCKS の順に試行）
4. **デフォルト値（フォールバック）** `http://127.0.0.1:10808`

現在有効なプロキシアドレスと到達可能性を確認:

```bash
./launcher.sh --check
# プロキシアドレス / Proxy address: http://127.0.0.1:10808
# プロキシ状態 / Proxy status: 到達可能 / reachable ✓
```

起動前に TCP 到達可能性をチェックし、プロキシが起動していない場合は警告を表示します。

## インストール

```bash
./install.sh
```

または手動で:

```bash
mkdir -p ~/Applications/"ChatGPT Proxy.app"/Contents/{MacOS,Resources}
cp Info.plist ~/Applications/"ChatGPT Proxy.app"/Contents/Info.plist
cp launcher.sh ~/Applications/"ChatGPT Proxy.app"/Contents/MacOS/launcher
chmod +x ~/Applications/"ChatGPT Proxy.app"/Contents/MacOS/launcher
cp /Applications/ChatGPT.app/Contents/Resources/electron.icns \
   ~/Applications/"ChatGPT Proxy.app"/Contents/Resources/ 2>/dev/null
```

## 使い方

1. 元の ChatGPT を `Cmd+Q` で完全に終了（ウィンドウを閉じるだけでは不十分）
2. `~/Applications/ChatGPT Proxy.app` から起動（Dock にドラッグ可）
3. 新しい会話で「Reconnecting... /5」が表示されなくなります

> プロキシクライアントやポートを変更しましたか？設定変更は不要です — ランチャーがシステムプロキシを自動検出します。強制的に指定する場合は `CHATGPT_PROXY` を設定するか、設定ファイルを書いてください。

## アンインストール

```bash
rm -rf ~/Applications/"ChatGPT Proxy.app"
rm -f ~/.chatgpt-proxy-launcher.conf   # 作成した場合のみ
```

## 検証方法

アプリの接続がすべてプロキシを経由しているか確認（直接接続の SYN_SENT ハングがないこと）:

```bash
lsof -nP -iTCP | grep -E 'codex|ChatGPT' | grep -v 127.0.0.1
```

それでも直接接続が残る場合は、その接続タイプが環境変数を読まないケース（例：WebSocket）です。TUN モード + **OpenAI ドメインのみをプロキシする最小ルーティングルール**を検討してください（デフォルトの TUN がすべての海外通信をノード経由にして通信量が爆増するのを防ぐ）。

---

## 🤖 Powered by DSH

このプロジェクトは **DeepSeek Harness (DSH)** が最初から最後まで自動で完成させました — 問題診断、ソリューション設計、実装、GitHub リポジトリの作成とプッシュまで、すべて DSH がローカルマシン上で行いました:

- **実測による問題再現**: 接続安定性テスト（旧ノード: 8回中2回タイムアウト → 新ノード: 8回中0回失敗）、DNS 汚染の検出（`chatgpt.com` がクエリごとに異なる偽 Facebook 帯域 IP に解決）、プロセスネットワーク分析（`codex` プロセスの `168.143.171.186:443` への SYN_SENT ハングを捕捉）
- **根本原因の特定**: Rust コアがシステムプロキシを迂回して直接接続 → DNS 汚染された偽 IP に当たってブロック → 再接続タイムアウト
- **ソリューションの設計と実装**: プロキシランチャー（システムプロキシの IP/ポートを自動検出、そのアプリにのみプロキシ環境変数を注入、TUN 不要・グローバル副作用なし・追加通信なし）
- **ドキュメント作成とリポジトリのプッシュ**

> 同じ「Reconnecting... x/5 / request timed out」問題に悩んでいるなら、これが役立つことを願っています。これ自体が DSH が完全自動で生み出した成果物です。
