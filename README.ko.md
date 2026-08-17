# ChatGPT 프록시 런처 (macOS)

[English](README.md) | [中文](README.zh.md) | [한국어](README.ko.md) | [日本語](README.ja.md)

---

ChatGPT/Codex 데스크톱 앱(`com.openai.codex`)이 **새 대화를 시작할 때마다 "Reconnecting... x/5 / request timed out"**에 걸려 한참 후에야 응답하는 문제를 해결합니다.

## 배경 및 근본 원인

- ChatGPT 데스크톱 앱은 Electron UI 프로세스 + Rust 코어 프로세스로 구성됩니다. **Rust 코어 프로세스의 일부 요청(새 세션 연결 설정 / WebSocket 스트림)은 macOS 시스템 프록시를 거치지 않고 인터넷에 직접 연결합니다.**
- 네트워크 제한 환경(예: 중국 본토)에서는 로컬 DNS가 오염되어(`chatgpt.com`이 쿼리마다 다른 가짜 IP, 예: Facebook 대역으로 해석됨) 직접 연결이 차단됩니다 → 연결이 타임아웃될 때까지 멈춥니다.
- 앱은 `x/5`로 재시도하며 5회를 모두 소진한 후에야 프록시 경로로 폴백합니다 → "새 대화마다 오래 걸림"이 나타납니다.

## 동작 원리

ChatGPT를 시작할 때 **해당 앱에만** 프록시 환경 변수(`HTTP_PROXY / HTTPS_PROXY / ALL_PROXY`)를 주입하는 런처 앱입니다.

- ✅ 다른 앱에 영향 없음(전역 설정이 아님)
- ✅ 추가 프록시 트래픽 없음(ChatGPT 트래픽만 노드를 경유, TUN 불필요)
- ✅ 원본 `ChatGPT.app`은 그대로 유지
- ✅ **프록시 IP/포트 자동 감지** — 수동 설정 불필요, 프록시 클라이언트를 바꿔도 동작

## 프록시 주소 결정 방식

우선순위(높음 → 낮음):

1. **`CHATGPT_PROXY` 환경 변수**: `CHATGPT_PROXY=http://127.0.0.1:7890 ./launcher.sh`
2. **설정 파일 `~/.chatgpt-proxy-launcher.conf`**: `CHATGPT_PROXY=http://127.0.0.1:7890` 한 줄 작성(고정 프록시용, 매번 환경 변수를 입력하지 않아도 됨)
3. **macOS 시스템 프록시 자동 감지**(`scutil --proxy`, HTTPS → HTTP → SOCKS 순서로 시도)
4. **기본값(폴백)** `http://127.0.0.1:10808`

현재 적용되는 프록시 주소와 연결 가능 여부 확인:

```bash
./launcher.sh --check
# 프록시 주소 / Proxy address: http://127.0.0.1:10808
# 프록시 상태 / Proxy status: 연결 가능 / reachable ✓
```

실행 전에 TCP 연결 가능 여부를 검사하며, 프록시가 꺼져 있으면 경고를 표시합니다.

## 설치

```bash
./install.sh
```

또는 수동으로:

```bash
mkdir -p ~/Applications/"ChatGPT Proxy.app"/Contents/{MacOS,Resources}
cp Info.plist ~/Applications/"ChatGPT Proxy.app"/Contents/Info.plist
cp launcher.sh ~/Applications/"ChatGPT Proxy.app"/Contents/MacOS/launcher
chmod +x ~/Applications/"ChatGPT Proxy.app"/Contents/MacOS/launcher
cp /Applications/ChatGPT.app/Contents/Resources/electron.icns \
   ~/Applications/"ChatGPT Proxy.app"/Contents/Resources/ 2>/dev/null
```

## 사용법

1. 원본 ChatGPT를 `Cmd+Q`로 완전히 종료(창을 닫는 것만으로는 부족)
2. `~/Applications/ChatGPT Proxy.app`에서 실행(Dock에 드래그 가능)
3. 새 대화에서 더 이상 "Reconnecting... /5"가 나타나지 않아야 합니다

> 프록시 클라이언트나 포트를 바꿨나요? 설정 변경이 필요 없습니다 — 런처가 시스템 프록시를 자동 감지합니다. 강제로 지정하려면 `CHATGPT_PROXY`를 설정하거나 설정 파일을 작성하세요.

## 제거

```bash
rm -rf ~/Applications/"ChatGPT Proxy.app"
rm -f ~/.chatgpt-proxy-launcher.conf   # 생성한 경우에만
```

## 검증 방법

앱 프로세스의 연결이 모두 프록시를 경유하는지 확인(직접 연결 SYN_SENT 멈춤이 없어야 함):

```bash
lsof -nP -iTCP | grep -E 'codex|ChatGPT' | grep -v 127.0.0.1
```

여전히 직접 연결이 있다면 해당 연결 유형이 환경 변수를 읽지 않는 경우(예: WebSocket)입니다. TUN 모드 + **OpenAI 도메인만 프록시하는 최소 라우팅 규칙**을 고려하세요(기본 TUN이 모든 해외 트래픽을 노드로 보내 트래픽이 폭증하는 것을 방지).

---

## 🤖 Powered by DSH

이 프로젝트는 **DeepSeek Harness (DSH)**가 처음부터 끝까지 자동으로 완성했습니다 — 문제 진단, 솔루션 설계, 구현, GitHub 저장소 생성 및 푸시까지 모두 DSH가 로컬 머신에서 수행했습니다:

- **실측으로 문제 재현**: 연결 안정성 테스트(이전 노드: 8회 중 2회 타임아웃 → 새 노드: 8회 중 0회 실패), DNS 오염 감지(`chatgpt.com`이 쿼리마다 다른 가짜 Facebook 대역 IP로 해석), 프로세스 네트워크 분석(`codex` 프로세스의 `168.143.171.186:443` SYN_SENT 멈춤 포착)
- **근본 원인 파악**: Rust 코어가 시스템 프록시를 우회해 직접 연결 → DNS 오염된 가짜 IP를 만나 차단 → 재연결 타임아웃
- **솔루션 설계 및 구현**: 프록시 런처(시스템 프록시 IP/포트 자동 감지, 해당 앱에만 프록시 환경 변수 주입, TUN 불필요·전역 부작용 없음·추가 트래픽 없음)
- **문서 작성 및 저장소 푸시**

> 같은 "Reconnecting... x/5 / request timed out" 문제를 겪고 있다면 도움이 되길 바랍니다. 이 프로젝트 자체가 DSH가 완전 자동으로 만든 산출물입니다.
