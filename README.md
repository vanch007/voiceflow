# VoiceFlow

macOS 메뉴바 음성입력 앱. Ctrl 더블탭으로 녹음 시작/종료, Qwen3-ASR로 음성인식 후 텍스트 자동 입력.

## Requirements

- macOS 14+ (Sonoma)
- Xcode 16+ (Command Line Tools 포함)
- Python 3.11+

## Quick Start

```bash
# 1. 클론
git clone https://github.com/anthropics/voiceflow.git
cd voiceflow

# 2. Python 환경 설정 (가상환경 생성 + 의존성 설치)
scripts/setup.sh

# 3. 빌드
scripts/build.sh

# 4. 실행
open VoiceFlow.app
```

> 첫 실행 시 Qwen3-ASR 모델 다운로드에 시간이 걸립니다 (~3.4GB).

## 접근성 권한 설정 (필수)

앱 실행 후 Ctrl 더블탭이 작동하려면 접근성 권한이 필요합니다.

**시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용**에서:
1. VoiceFlow.app이 없으면 **+** 버튼으로 추가
2. 이미 있으면 **토글 off → on**

> 빌드할 때마다 코드사인이 바뀌므로 **매 빌드 후 토글 off → on** 필요. macOS 보안 정책이라 우회 불가.

## 사용법

- **Ctrl 더블탭**: 녹음 시작/종료 토글
- 녹음 종료 시 자동으로 음성인식 → 현재 포커스된 앱에 텍스트 입력
- 메뉴바 아이콘으로 연결 상태 확인

### 마이크 선택

메뉴바 아이콘 클릭 → **마이크** 서브메뉴에서 원하는 입력 장치를 선택할 수 있습니다.

- **시스템 기본값**: macOS 시스템 설정의 기본 입력 장치 사용
- 연결된 오디오 입력 장치 목록에서 직접 선택 가능
- 선택한 장치는 앱 재시작 후에도 유지됨 (UserDefaults 저장)

## 환경 변수

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `VOICEFLOW_PYTHON` | Python 인터프리터 경로 | `<project_root>/.venv/bin/python3` |

## 프로젝트 구조

```
voiceflow/
├── VoiceFlow/                    # Swift 앱
│   ├── Sources/
│   │   ├── App/
│   │   │   ├── VoiceFlowApp.swift    # 엔트리포인트
│   │   │   └── AppDelegate.swift     # 메인 로직 + ASR 서버 관리
│   │   ├── Core/
│   │   │   ├── HotkeyManager.swift   # Ctrl 더블탭 감지
│   │   │   ├── AudioRecorder.swift   # 마이크 녹음 + 장치 선택
│   │   │   ├── ASRClient.swift       # WebSocket ASR 클라이언트
│   │   │   └── TextInjector.swift    # 텍스트 주입
│   │   └── UI/
│   │       ├── StatusBarController.swift  # 메뉴바 UI + 마이크 선택
│   │       └── OverlayPanel.swift
│   └── VoiceFlow.xcodeproj
├── server/
│   ├── main.py                   # Qwen3-ASR WebSocket 서버
│   └── requirements.txt
├── scripts/
│   ├── setup.sh                  # Python 환경 설정
│   └── build.sh                  # 빌드 + 배포 (ditto로 코드사인 보존)
└── TROUBLESHOOTING.md            # 트러블슈팅 가이드
```

## 동작 원리

1. 앱 시작 시 ASR 서버(Python WebSocket, `ws://localhost:9876`)를 자동 실행
2. Ctrl 더블탭 → 마이크 녹음 시작, 오디오 청크를 WebSocket으로 스트리밍
3. 다시 Ctrl 더블탭 → 녹음 종료, 서버에서 Qwen3-ASR로 음성인식
4. 인식 결과를 현재 포커스된 앱에 CGEvent로 텍스트 주입

## 오디오 처리

- AVCaptureSession으로 마이크 입력 캡처 (interleaved / non-interleaved 모두 지원)
- 48kHz → 16kHz 리샘플링 (선형 보간)
- 스테레오 → 모노 변환 (채널 0 추출)
- Float32 PCM으로 WebSocket 전송

## 효과음

`AudioServicesPlaySystemSound` 사용 (시스템 사운드 경로).
AVAudioPlayer/NSSound는 AVCaptureSession이 출력 스트림을 비활성화해서 사용 불가.

- 녹음 시작: Tink.aiff
- 녹음 종료: Pop.aiff

## 실행 방식 주의

- **반드시 `open VoiceFlow.app`으로 실행** (Finder 또는 터미널)
- 바이너리 직접 실행(`./VoiceFlow.app/Contents/MacOS/VoiceFlow`)은 터미널의 접근성 권한을 따라감

## 트러블슈팅

자세한 트러블슈팅은 [TROUBLESHOOTING.md](TROUBLESHOOTING.md) 참고.
