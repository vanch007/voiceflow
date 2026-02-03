# VoiceFlow Plugin Development Guide

VoiceFlow 플러그인 시스템을 사용하면 음성인식 텍스트를 실시간으로 변환, 분석, 처리할 수 있습니다.

## 목차

- [시작하기](#시작하기)
- [Manifest 구조](#manifest-구조)
- [Plugin API 개요](#plugin-api-개요)
- [Swift 플러그인 개발](#swift-플러그인-개발)
- [Python 플러그인 개발](#python-플러그인-개발)
- [플러그인 테스트](#플러그인-테스트)

---

## 시작하기

### 플러그인 디렉토리

플러그인은 다음 디렉토리에 설치됩니다:

```
~/Library/Application Support/VoiceFlow/Plugins/
```

각 플러그인은 자체 하위 디렉토리에 있어야 하며 `manifest.json` 파일이 필요합니다:

```
~/Library/Application Support/VoiceFlow/Plugins/
├── MyAwesomePlugin/
│   ├── manifest.json
│   └── my_plugin.py (또는 MyPlugin.swift)
└── AnotherPlugin/
    ├── manifest.json
    └── another_plugin.py
```

### 플러그인 설치

1. 플러그인 디렉토리를 `~/Library/Application Support/VoiceFlow/Plugins/`에 복사
2. VoiceFlow 재시작
3. 메뉴바 아이콘 → **Plugins** 메뉴에서 플러그인 활성화

### 빠른 시작: 첫 번째 플러그인 만들기

예제 플러그인을 복사하여 시작하세요:

```bash
# Python 예제
cp -r Plugins/Examples/PunctuationPlugin ~/Library/Application\ Support/VoiceFlow/Plugins/

# Swift 예제
cp -r Plugins/Examples/UppercasePlugin ~/Library/Application\ Support/VoiceFlow/Plugins/
```

---

## Manifest 구조

모든 플러그인에는 `manifest.json` 파일이 필요합니다. 이 파일은 플러그인의 메타데이터와 설정을 정의합니다.

### 필수 필드

```json
{
  "id": "com.example.myplugin",
  "name": "My Plugin",
  "version": "1.0.0",
  "author": "Your Name",
  "description": "Brief description of what your plugin does",
  "entrypoint": "my_plugin.py",
  "platform": "python",
  "permissions": [
    "text.read",
    "text.modify"
  ]
}
```

### 필드 설명

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | string | 플러그인의 고유 식별자 (역방향 도메인 표기법 권장, 예: `com.example.myplugin`) |
| `name` | string | 사용자에게 표시되는 플러그인 이름 |
| `version` | string | 시맨틱 버전 (예: `1.0.0`, `2.1.3`) |
| `author` | string | 플러그인 작성자 이름 또는 조직 |
| `description` | string | 플러그인 기능에 대한 간단한 설명 |
| `entrypoint` | string | Python: 모듈 경로 (예: `my_plugin.py`)<br>Swift: 번들 경로 (예: `MyPlugin.bundle`) |
| `platform` | string | `"python"`, `"swift"`, 또는 `"both"` |
| `permissions` | array | 필요한 권한 목록 (아래 참조) |

### 선택 필드

```json
{
  "minVoiceFlowVersion": "1.0.0",
  "license": "MIT",
  "homepage": "https://github.com/yourname/myplugin",
  "repository": "https://github.com/yourname/myplugin"
}
```

### 권한

플러그인이 요청할 수 있는 권한:

- `text.read`: 음성인식 텍스트 읽기
- `text.modify`: 음성인식 텍스트 수정
- `audio.read`: 오디오 데이터 접근 (향후 지원 예정)
- `network.access`: 네트워크 요청 (향후 지원 예정)

---

## Plugin API 개요

### 플러그인 라이프사이클

플러그인은 세 가지 주요 라이프사이클 훅을 구현합니다:

1. **`onLoad()`**: 플러그인이 로드될 때 호출
   - 리소스 초기화
   - 설정 로드
   - 연결 설정

2. **`onTranscription(text)`**: 음성인식 텍스트가 있을 때 호출
   - 텍스트 변환/분석/수정
   - 메인 처리 로직
   - 처리된 텍스트 반환

3. **`onUnload()`**: 플러그인이 언로드될 때 호출
   - 리소스 정리
   - 연결 종료
   - 상태 저장

### 플러그인 상태

플러그인은 다음 상태 중 하나에 있을 수 있습니다:

- **`loaded`**: 플러그인이 발견되고 manifest가 로드됨
- **`enabled`**: 플러그인이 활성화되어 텍스트를 처리 중
- **`disabled`**: 플러그인이 비활성화됨
- **`failed`**: 플러그인 로드 또는 실행 실패

### 텍스트 처리 파이프라인

활성화된 여러 플러그인이 있으면 텍스트가 순차적으로 처리됩니다:

```
ASR Engine → Plugin 1 → Plugin 2 → Plugin N → Text Injector
```

각 플러그인은 이전 플러그인의 출력을 입력으로 받습니다.

---

## Swift 플러그인 개발

### 요구사항

- Xcode 16+
- macOS 14+ (Sonoma)
- Swift 5.9+

### 프로젝트 설정

1. **새 macOS 번들 프로젝트 생성**

```bash
# Xcode에서: File → New → Project → macOS → Bundle
```

2. **VoiceFlow Plugin API 가져오기**

프로젝트에 `PluginAPI.swift`를 복사하거나 참조하세요:

```swift
import Foundation

protocol VoiceFlowPlugin: AnyObject {
    var pluginID: String { get }
    var manifest: PluginManifest { get }

    func onLoad()
    func onTranscription(_ text: String) -> String
    func onUnload()
}
```

### 플러그인 구현

```swift
import Foundation

final class UppercasePlugin: VoiceFlowPlugin {

    var pluginID: String {
        return manifest.id
    }

    var manifest: PluginManifest {
        return PluginManifest(
            id: "dev.voiceflow.examples.uppercase",
            name: "Uppercase Transform",
            version: "1.0.0",
            author: "VoiceFlow Team",
            description: "Transforms all transcribed text to uppercase",
            entrypoint: "UppercasePlugin.bundle",
            permissions: ["text.read", "text.modify"],
            platform: .swift
        )
    }

    func onLoad() {
        NSLog("[UppercasePlugin] Plugin loaded")
        // 초기화 로직
    }

    func onTranscription(_ text: String) -> String {
        let transformed = text.uppercased()
        NSLog("[UppercasePlugin] Transformed: '\(text)' -> '\(transformed)'")
        return transformed
    }

    func onUnload() {
        NSLog("[UppercasePlugin] Plugin unloaded")
        // 정리 로직
    }
}
```

### 빌드 및 배포

1. **Principal Class 설정**

Xcode에서 Target → Info → Principal Class를 플러그인 클래스 이름으로 설정 (예: `UppercasePlugin`)

2. **빌드**

```bash
xcodebuild -project MyPlugin.xcodeproj -scheme MyPlugin -configuration Release
```

3. **번들 복사**

```bash
cp -r build/Release/MyPlugin.bundle ~/Library/Application\ Support/VoiceFlow/Plugins/MyPlugin/
```

4. **manifest.json 생성**

```bash
cat > ~/Library/Application\ Support/VoiceFlow/Plugins/MyPlugin/manifest.json << 'EOF'
{
  "id": "com.example.myplugin",
  "name": "My Plugin",
  "version": "1.0.0",
  "author": "Your Name",
  "description": "Description of your plugin",
  "entrypoint": "MyPlugin.bundle",
  "platform": "swift",
  "permissions": ["text.read", "text.modify"]
}
EOF
```

### Swift 플러그인 예제: 텍스트 필터링

```swift
final class ProfanityFilterPlugin: VoiceFlowPlugin {

    private var badWords: Set<String> = []

    var pluginID: String {
        return manifest.id
    }

    var manifest: PluginManifest {
        return PluginManifest(
            id: "com.example.profanityfilter",
            name: "Profanity Filter",
            version: "1.0.0",
            author: "Your Name",
            description: "Filters inappropriate language",
            entrypoint: "ProfanityFilterPlugin.bundle",
            permissions: ["text.read", "text.modify"],
            platform: .swift
        )
    }

    func onLoad() {
        // 금지 단어 목록 로드
        badWords = ["badword1", "badword2", "badword3"]
        NSLog("[ProfanityFilter] Loaded \(badWords.count) filtered words")
    }

    func onTranscription(_ text: String) -> String {
        var filtered = text

        for word in badWords {
            let pattern = "\\b\(word)\\b"
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(filtered.startIndex..., in: filtered)

            filtered = regex?.stringByReplacingMatches(
                in: filtered,
                options: [],
                range: range,
                withTemplate: String(repeating: "*", count: word.count)
            ) ?? filtered
        }

        return filtered
    }

    func onUnload() {
        badWords.removeAll()
        NSLog("[ProfanityFilter] Plugin unloaded")
    }
}
```

---

## Python 플러그인 개발

### 요구사항

- Python 3.11+
- VoiceFlow server 디렉토리에 접근 (plugin_api.py 사용)

### 프로젝트 설정

1. **플러그인 디렉토리 생성**

```bash
mkdir -p ~/Library/Application\ Support/VoiceFlow/Plugins/MyPythonPlugin
cd ~/Library/Application\ Support/VoiceFlow/Plugins/MyPythonPlugin
```

2. **Plugin API 가져오기**

```python
#!/usr/bin/env python3
import sys
from pathlib import Path

# VoiceFlow server 디렉토리를 Python 경로에 추가
server_path = Path(__file__).resolve().parent.parent.parent.parent / "server"
sys.path.insert(0, str(server_path))

from plugin_api import VoiceFlowPlugin, PluginManifest, PluginError
```

### 플러그인 구현

```python
#!/usr/bin/env python3
"""PunctuationPlugin - Adds punctuation to transcribed text."""

import logging
import sys
from pathlib import Path

# VoiceFlow server 디렉토리 추가
server_path = Path(__file__).resolve().parent.parent.parent.parent / "server"
sys.path.insert(0, str(server_path))

from plugin_api import VoiceFlowPlugin, PluginManifest, PluginError

logger = logging.getLogger(__name__)


class PunctuationPlugin(VoiceFlowPlugin):
    """Intelligently adds punctuation to transcribed text."""

    def __init__(self, manifest: PluginManifest):
        super().__init__(manifest)
        self._enabled = False

    async def on_load(self) -> None:
        """Called when the plugin is loaded."""
        logger.info(f"[{self.plugin_id}] Loading PunctuationPlugin")
        self._enabled = True
        logger.info(f"[{self.plugin_id}] PunctuationPlugin loaded successfully")

    async def on_transcription(self, text: str) -> str:
        """
        Process transcribed text by adding appropriate punctuation.

        Args:
            text: The transcribed text from the ASR system

        Returns:
            The text with appropriate punctuation added
        """
        if not self._enabled:
            return text

        try:
            # Strip whitespace
            processed = text.strip()

            if not processed:
                return text

            # Capitalize first letter
            processed = processed[0].upper() + processed[1:] if len(processed) > 1 else processed.upper()

            # Check if text already ends with punctuation
            if processed[-1] in {'.', '!', '?', ',', ';', ':'}:
                return processed

            # Detect question patterns
            question_words = {'what', 'where', 'when', 'who', 'why', 'how', 'which'}
            first_word = processed.split()[0].lower() if processed.split() else ''

            # Add question mark for questions, period otherwise
            if first_word in question_words:
                processed += '?'
            else:
                processed += '.'

            logger.debug(f"[{self.plugin_id}] Transformed: '{text}' -> '{processed}'")
            return processed

        except Exception as e:
            error_msg = f"Failed to process text: {str(e)}"
            logger.error(f"[{self.plugin_id}] {error_msg}")
            raise PluginError(error_msg) from e

    async def on_unload(self) -> None:
        """Called when the plugin is unloaded."""
        logger.info(f"[{self.plugin_id}] Unloading PunctuationPlugin")
        self._enabled = False
        logger.info(f"[{self.plugin_id}] PunctuationPlugin unloaded successfully")
```

### manifest.json 생성

```bash
cat > manifest.json << 'EOF'
{
  "id": "com.example.punctuation",
  "name": "Punctuation Plugin",
  "version": "1.0.0",
  "author": "Your Name",
  "description": "Intelligently adds punctuation to transcribed text",
  "entrypoint": "punctuation_plugin.py",
  "platform": "python",
  "permissions": [
    "text.read",
    "text.modify"
  ]
}
EOF
```

### Python 플러그인 예제: 언어 감지 및 번역

```python
#!/usr/bin/env python3
"""TranslationPlugin - Detects language and translates to English."""

import logging
import sys
from pathlib import Path

server_path = Path(__file__).resolve().parent.parent.parent.parent / "server"
sys.path.insert(0, str(server_path))

from plugin_api import VoiceFlowPlugin, PluginManifest, PluginError

logger = logging.getLogger(__name__)


class TranslationPlugin(VoiceFlowPlugin):
    """Detects non-English text and translates to English."""

    def __init__(self, manifest: PluginManifest):
        super().__init__(manifest)
        self._translator = None

    async def on_load(self) -> None:
        """Initialize translation service."""
        logger.info(f"[{self.plugin_id}] Loading TranslationPlugin")

        # 번역 라이브러리 초기화 (예: googletrans, deep_translator 등)
        # self._translator = Translator()

        logger.info(f"[{self.plugin_id}] TranslationPlugin loaded")

    async def on_transcription(self, text: str) -> str:
        """
        Detect language and translate to English if needed.

        Args:
            text: The transcribed text

        Returns:
            Text translated to English if it was in another language
        """
        try:
            # 언어 감지
            # detected_lang = self._translator.detect(text).lang

            # 영어가 아니면 번역
            # if detected_lang != 'en':
            #     translated = self._translator.translate(text, dest='en').text
            #     logger.info(f"[{self.plugin_id}] Translated from {detected_lang}: '{text}' -> '{translated}'")
            #     return translated

            return text

        except Exception as e:
            logger.error(f"[{self.plugin_id}] Translation failed: {e}")
            # 번역 실패 시 원본 텍스트 반환
            return text

    async def on_unload(self) -> None:
        """Clean up translation resources."""
        logger.info(f"[{self.plugin_id}] Unloading TranslationPlugin")
        self._translator = None
```

---

## 플러그인 테스트

### 개발 중 테스트

1. **로깅 활성화**

```bash
# 플러그인 로그 확인
log stream --predicate 'subsystem == "com.voiceflow.app"' --level debug
```

2. **플러그인 재로드**

플러그인을 수정한 후:
- VoiceFlow 메뉴바 → Plugins → 플러그인 비활성화
- 플러그인 비활성화 후 다시 활성화
- 또는 VoiceFlow 재시작

3. **디버깅**

Python 플러그인:
```python
# 플러그인 코드에 추가
import pdb; pdb.set_trace()  # 브레이크포인트
```

Swift 플러그인:
```swift
// Xcode에서 VoiceFlow.app에 attach하여 디버그
```

### 단위 테스트 작성

#### Python 플러그인 테스트

```python
#!/usr/bin/env python3
"""Test PunctuationPlugin."""

import asyncio
import unittest
from pathlib import Path

from plugin_api import PluginManifest, PluginPlatform
from punctuation_plugin import PunctuationPlugin


class TestPunctuationPlugin(unittest.TestCase):
    """Test cases for PunctuationPlugin."""

    def setUp(self):
        """Set up test plugin instance."""
        manifest = PluginManifest(
            id="test.punctuation",
            name="Test Punctuation",
            version="1.0.0",
            author="Test",
            description="Test plugin",
            entrypoint="punctuation_plugin.py",
            permissions=["text.read", "text.modify"],
            platform=PluginPlatform.PYTHON,
        )
        self.plugin = PunctuationPlugin(manifest)
        asyncio.run(self.plugin.on_load())

    def test_add_period(self):
        """Test adding period to statement."""
        result = asyncio.run(self.plugin.on_transcription("hello world"))
        self.assertEqual(result, "Hello world.")

    def test_add_question_mark(self):
        """Test adding question mark to question."""
        result = asyncio.run(self.plugin.on_transcription("what time is it"))
        self.assertEqual(result, "What time is it?")

    def test_preserve_existing_punctuation(self):
        """Test that existing punctuation is preserved."""
        result = asyncio.run(self.plugin.on_transcription("Hello world!"))
        self.assertEqual(result, "Hello world!")

    def tearDown(self):
        """Clean up plugin."""
        asyncio.run(self.plugin.on_unload())


if __name__ == "__main__":
    unittest.main()
```

실행:
```bash
python3 test_punctuation_plugin.py
```

#### Swift 플러그인 테스트

```swift
import XCTest

final class UppercasePluginTests: XCTestCase {

    var plugin: UppercasePlugin!

    override func setUp() {
        super.setUp()
        plugin = UppercasePlugin()
        plugin.onLoad()
    }

    override func tearDown() {
        plugin.onUnload()
        plugin = nil
        super.tearDown()
    }

    func testUppercaseTransform() {
        let input = "hello world"
        let output = plugin.onTranscription(input)
        XCTAssertEqual(output, "HELLO WORLD")
    }

    func testEmptyString() {
        let input = ""
        let output = plugin.onTranscription(input)
        XCTAssertEqual(output, "")
    }

    func testAlreadyUppercase() {
        let input = "ALREADY UPPERCASE"
        let output = plugin.onTranscription(input)
        XCTAssertEqual(output, "ALREADY UPPERCASE")
    }
}
```

실행:
```bash
xcodebuild test -scheme MyPluginTests
```

### 통합 테스트

1. **VoiceFlow 실행**
2. **플러그인 활성화**
3. **Ctrl 더블탭으로 녹음 시작**
4. **음성 입력: "hello world"**
5. **Ctrl 더블탭으로 녹음 종료**
6. **결과 확인**: 플러그인에 따라 "HELLO WORLD" 또는 "Hello world." 등

### 예제 플러그인

프로젝트에 포함된 예제 플러그인을 참고하세요:

- **Swift**: `Plugins/Examples/UppercasePlugin/` - 텍스트를 대문자로 변환
- **Python**: `Plugins/Examples/PunctuationPlugin/` - 지능형 구두점 추가

---

## 모범 사례

### 일반

1. **오류 처리**: 모든 예외를 처리하고 적절한 오류 메시지 제공
2. **로깅**: 디버깅을 위해 적절한 로그 레벨 사용
3. **성능**: 텍스트 처리는 빠르게 (< 100ms 권장)
4. **멱등성**: 동일한 입력에 대해 동일한 출력 보장

### Python 플러그인

1. **비동기 프로그래밍**: 모든 훅은 `async def` 사용
2. **타입 힌트**: 타입 안정성을 위해 타입 힌트 추가
3. **의존성**: `requirements.txt` 생성하여 의존성 관리

### Swift 플러그인

1. **메모리 관리**: 강한 참조 순환 방지
2. **스레드 안전성**: 필요시 동기화 처리
3. **번들 구조**: 올바른 Principal Class 설정 확인

### 보안

1. **권한 최소화**: 필요한 권한만 요청
2. **입력 검증**: 모든 사용자 입력 검증
3. **네트워크**: HTTPS 사용, 자격증명 안전하게 저장
4. **샌드박싱**: 플러그인은 제한된 환경에서 실행됨을 가정

---

## 트러블슈팅

### 플러그인이 로드되지 않음

1. `manifest.json` 유효성 검사:
```bash
python3 -m json.tool ~/Library/Application\ Support/VoiceFlow/Plugins/MyPlugin/manifest.json
```

2. 로그 확인:
```bash
log stream --predicate 'subsystem == "com.voiceflow.app"' --level debug | grep Plugin
```

3. 권한 확인:
```bash
ls -la ~/Library/Application\ Support/VoiceFlow/Plugins/MyPlugin/
```

### Python 플러그인 임포트 오류

```python
# 올바른 경로 설정 확인
import sys
from pathlib import Path

server_path = Path(__file__).resolve().parent.parent.parent.parent / "server"
print(f"Server path: {server_path}")  # 디버깅
sys.path.insert(0, str(server_path))
```

### Swift 플러그인 번들 오류

1. Principal Class 설정 확인 (Xcode → Target → Info)
2. 번들 식별자가 manifest의 `id`와 일치하는지 확인
3. 빌드 설정에서 "Skip Install" = NO 확인

---

## 추가 리소스

- **예제 플러그인**: `Plugins/Examples/`
- **API 문서**: `server/plugin_api.py`, `VoiceFlow/Sources/Core/PluginAPI.swift`
- **트러블슈팅**: `TROUBLESHOOTING.md`

## 커뮤니티

플러그인을 만들었다면 공유해주세요!

- GitHub Issues: 버그 리포트 및 기능 요청
- Pull Requests: 예제 플러그인 기여 환영

---

**Happy Plugin Development! 🎉**
