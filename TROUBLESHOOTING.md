# VoiceFlow 트러블슈팅 가이드

실제 개발 과정에서 겪은 이슈와 해결 방법 정리.

---

## 1. Ctrl 더블탭이 안 먹힘

### 증상
- 앱 실행은 되지만 Ctrl 더블탭에 반응 없음
- 로그에 `Event tap started successfully!` 는 나오지만 `flagsChanged` 로그 없음
- `CGEvent.tapCreate`가 성공해도 실제 이벤트를 안 받음

### 원인: 접근성(Accessibility) 권한
macOS는 event tap을 **생성은 허용**하지만, 접근성 권한이 없으면 **이벤트를 전달하지 않는다.**
→ `tapCreate` 성공 ≠ 이벤트 수신 가능

### 해결
**시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용**에서 VoiceFlow.app 추가.

### ⚠️ 주의사항

#### 실행 방식에 따라 권한이 다르게 적용됨
| 실행 방식 | 접근성 권한 주체 |
|-----------|-----------------|
| `open VoiceFlow.app` | **VoiceFlow.app** 자체 |
| 터미널에서 바이너리 직접 실행 | **해당 터미널 앱** (Ghostty, Terminal 등) |
| Moltbot/Node에서 실행 | **node 바이너리** |

→ **`open VoiceFlow.app`으로 실행하는 게 정석.** 앱 자체에 권한 부여하면 됨.

#### `tccutil reset` 절대 사용 금지
```bash
# ❌ 이거 하면 접근성 권한 완전 삭제 — 복구 어려움
tccutil reset Accessibility com.voiceflow.app
```
실행하면 시스템 설정에서도 목록이 사라지고, 재부팅해야 재추가 가능할 수 있음.

---

## 2. 빌드 후 더블탭이 안 먹힘

### 증상
- 이전 빌드에서는 잘 되던 더블탭이 새 빌드 후 안 됨
- 접근성 설정에 VoiceFlow가 있고 활성화 상태인데도 안 됨

### 원인: 코드사인 변경
xcodebuild로 새로 빌드하면 바이너리가 바뀌면서 코드사인(CDHash)이 변경됨.
macOS는 접근성 권한을 **코드사인 기준**으로 매칭하므로, 새 빌드 = 다른 앱으로 인식.

### 해결
빌드 후 **손쉬운 사용에서 VoiceFlow 토글 off → on** (또는 삭제 후 재추가).

---

## 3. 앱 복사 시 코드사인이 날아감

### 증상
- xcodebuild 결과물을 프로젝트 디렉토리에 복사 후 접근성 권한 안 먹힘
- `codesign -dv`로 확인하면 `Identifier=VoiceFlow, TeamIdentifier=not set`

### 원인: `cp -R` 사용
`cp -R`은 macOS 코드사인을 보존하지 않음.

```bash
# ❌ 코드사인 날아감
cp -R DerivedData/.../VoiceFlow.app ./VoiceFlow.app

# ✅ 코드사인 보존됨
ditto DerivedData/.../VoiceFlow.app ./VoiceFlow.app
```

### 확인 방법
```bash
codesign -dv VoiceFlow.app 2>&1 | grep "Identifier\|TeamIdentifier"

# 정상: Identifier=com.voiceflow.app, TeamIdentifier=J2Y925QHNV
# 비정상: Identifier=VoiceFlow, TeamIdentifier=not set
```

### 해결
`scripts/build.sh` 사용 — 내부적으로 `ditto`로 복사함.

---

## 4. 효과음(Tink/Pop)이 안 들림

### 증상
- 더블탭은 되고 녹음도 되지만 소리가 안 남
- `afplay`로 직접 재생하면 소리 나옴

### 원인: AVCaptureSession이 오디오 출력 스트림을 비활성화
AudioRecorder가 캡처 세션을 시작하면 시스템 로그에:
```
SetStreamUsage: Output stream enables: Stream 0 is DISABLED
```
→ NSSound, AVAudioPlayer 모두 출력 불가

### 시도한 방법과 결과
| 방법 | 결과 |
|------|------|
| NSSound | ❌ 출력 스트림 비활성화로 안 됨 |
| AVAudioPlayer | ❌ 동일 |
| AudioServicesPlaySystemSound | ✅ 캡처 세션과 독립된 경로 |
| Process + afplay | ❌ Hardened Runtime이 서브프로세스 실행 차단 |

### 해결
`AudioServicesPlaySystemSound` 사용. 시스템 사운드 서브시스템은 AVCaptureSession과 완전히 독립적.

```swift
import AudioToolbox

var soundID: SystemSoundID = 0
AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
AudioServicesPlaySystemSound(soundID)
```

---

## 5. ASR 서버 연결 실패

### 증상
- 로그에 `Connection refused` 반복
- 음성인식이 안 됨

### 원인
ASR 서버(Python, ws://localhost:9876)가 안 떠있음.

### 해결
앱이 ASR 서버를 자동으로 시작함 (AppDelegate에서 Process로 실행).
서버 시작까지 ~5초 소요되므로 WebSocket 연결은 2초 지연 후 시도.

수동 실행이 필요한 경우:
```bash
/Users/brucechoe/clawd/.venvs/qwen3-asr/bin/python3 /Users/brucechoe/Projects/voiceflow/server/main.py
```

---

## 빌드 & 배포 체크리스트

```bash
# 1. 빌드 + 배포
scripts/build.sh

# 2. 기존 앱 종료
pkill -x VoiceFlow

# 3. 앱 실행
open VoiceFlow.app

# 4. 접근성 재승인 (빌드 후 필요)
# 시스템 설정 → 손쉬운 사용 → VoiceFlow 토글 off → on

# 5. Ctrl 더블탭으로 테스트
```

---

## 디버깅 팁

### 로그 확인
```bash
# Ghostty에서 직접 실행하면 NSLog가 터미널에 출력됨
/Users/brucechoe/Projects/voiceflow/VoiceFlow.app/Contents/MacOS/VoiceFlow

# 시스템 로그 (open으로 실행한 경우)
log show --predicate 'processImagePath contains "VoiceFlow"' --last 5m --style compact
```

### 접근성 권한 확인
```swift
import ApplicationServices
print(AXIsProcessTrusted()) // true면 정상
```

### 코드사인 확인
```bash
codesign -dv VoiceFlow.app 2>&1 | grep "Identifier\|TeamIdentifier\|Runtime"
```
