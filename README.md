# VoiceFlow

macOS 메뉴바 음성입력 앱. Ctrl 더블탭으로 녹음 시작/종료, Qwen3-ASR로 음성인식 후 텍스트 자동 입력.

## 빌드

```bash
scripts/build.sh
```

xcodebuild → ditto로 앱 복사 (코드사인 보존). **빌드 후 접근성 권한 재승인 필요** (아래 참고).

> `cp -R`은 코드사인을 날려서 접근성 권한이 깨짐. 반드시 `ditto` 사용.

## 실행

```bash
open VoiceFlow.app
```

앱 실행 시 ASR 서버(Python)가 자동으로 같이 뜸. 앱 종료 시 서버도 자동 종료.

## ⚠️ 접근성 권한 (중요!)

Ctrl 더블탭이 안 먹으면 **100% 접근성 권한 문제**.

### 증상
- 앱 실행은 되지만 Ctrl 더블탭이 반응 없음
- 로그에 "Event tap started successfully!" 나오지만 flagsChanged 로그 없음

### 해결
**시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용**에서:
1. VoiceFlow.app이 목록에 없으면 **+ 버튼**으로 추가
   - 경로: `/Users/brucechoe/Projects/voiceflow/VoiceFlow.app`
2. 이미 있으면 **토글 끄고 → 다시 켜기**

### ❗ 빌드 후 재승인 필요
xcodebuild로 새로 빌드하면 **코드사인이 바뀌어서** macOS가 다른 앱으로 인식함.
→ 빌드할 때마다 손쉬운 사용에서 VoiceFlow **토글 off → on** 해줘야 함.

이건 macOS 보안 정책이라 우회 불가. 개발 중엔 어쩔 수 없음.

### 절대 하지 말 것
```bash
tccutil reset Accessibility com.voiceflow.app  # ← 이거 하면 권한 완전 삭제됨
```

## 실행 방식

- **반드시 `open VoiceFlow.app`으로 실행** (Finder 또는 터미널에서)
- 터미널에서 바이너리 직접 실행 (`./VoiceFlow.app/Contents/MacOS/VoiceFlow`) 하면 터미널의 접근성 권한을 따라가서 별도 설정 필요

## 구조

```
VoiceFlow/
├── Sources/
│   ├── App/
│   │   ├── VoiceFlowApp.swift    # 엔트리포인트
│   │   └── AppDelegate.swift     # 메인 로직 + ASR 서버 관리
│   ├── Core/
│   │   ├── HotkeyManager.swift   # Ctrl 더블탭 감지
│   │   ├── AudioRecorder.swift   # 마이크 녹음
│   │   ├── ASRClient.swift       # WebSocket ASR 클라이언트
│   │   └── TextInjector.swift    # 텍스트 주입
│   └── UI/
│       ├── StatusBarController.swift
│       └── OverlayPanel.swift
server/
├── main.py                       # Qwen3-ASR WebSocket 서버
scripts/
├── build.sh                      # 빌드+배포 (ditto로 코드사인 보존)
├── run.sh                        # 실행 스크립트 (레거시)
```

## 효과음

`AudioServicesPlaySystemSound` 사용 (시스템 사운드 경로).
AVAudioPlayer/NSSound는 AVCaptureSession이 출력 스트림을 비활성화해서 안 됨.

- 녹음 시작: Tink.aiff
- 녹음 종료: Pop.aiff
