# VoiceFlow Plugin Development Guide

## ⚠️ Security Warning

**IMPORTANT: VoiceFlow uses a trust-based plugin model.** Plugins have full access to transcribed text and can execute arbitrary code with the same permissions as the VoiceFlow application. The permission system is **informational only** and is **not enforced** by the runtime.

**Only install plugins from sources you trust completely.** Malicious plugins can:
- Read and modify all transcribed text
- Access your file system
- Make network requests
- Execute system commands
- Access sensitive data in memory

There is currently **no sandboxing or permission enforcement**. Always review plugin source code before installation.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Architecture Overview](#architecture-overview)
3. [Creating Your First Plugin](#creating-your-first-plugin)
4. [Plugin Manifest Reference](#plugin-manifest-reference)
5. [Swift Plugin Implementation](#swift-plugin-implementation)
6. [Python Plugin Implementation](#python-plugin-implementation)
7. [Debugging Techniques](#debugging-techniques)
8. [Common Pitfalls](#common-pitfalls)
9. [Best Practices](#best-practices)
10. [Next Steps](#next-steps)

---

## Quick Start

**Goal:** Build a working plugin in under 30 minutes.

### Prerequisites

- macOS 14+ (Sonoma or later)
- Xcode 16+ (for Swift plugins)
- Python 3.11+ (for Python plugins)
- VoiceFlow app installed

### Option A: Swift Plugin (5 minutes)

```bash
# 1. Create plugin directory
mkdir -p ~/MyFirstPlugin
cd ~/MyFirstPlugin

# 2. Create manifest.json
cat > manifest.json << 'EOF'
{
  "id": "com.yourname.myfirstplugin",
  "name": "My First Plugin",
  "version": "1.0.0",
  "author": "Your Name",
  "description": "Adds exclamation marks to transcribed text",
  "entrypoint": "plugin.swift",
  "platform": "swift",
  "permissions": ["text.read", "text.modify"]
}
EOF

# 3. Create plugin.swift
cat > plugin.swift << 'EOF'
import Foundation

class MyFirstPlugin: VoiceFlowPlugin {
    var pluginID: String { "com.yourname.myfirstplugin" }
    var manifest: PluginManifest

    init(manifest: PluginManifest) {
        self.manifest = manifest
    }

    func onLoad() {
        print("✅ MyFirstPlugin loaded!")
    }

    func onTranscription(_ text: String) -> String {
        // Add exclamation mark to every sentence
        return text + "!"
    }

    func onUnload() {
        print("👋 MyFirstPlugin unloaded")
    }
}
EOF

# 4. Install plugin
cp -r ~/MyFirstPlugin ~/Library/Application\ Support/VoiceFlow/Plugins/

# 5. Restart VoiceFlow and enable your plugin in settings
```

### Option B: Python Plugin (5 minutes)

```bash
# 1. Create plugin directory
mkdir -p ~/MyFirstPythonPlugin
cd ~/MyFirstPythonPlugin

# 2. Create manifest.json
cat > manifest.json << 'EOF'
{
  "id": "com.yourname.myfirstpythonplugin",
  "name": "My First Python Plugin",
  "version": "1.0.0",
  "author": "Your Name",
  "description": "Converts text to title case",
  "entrypoint": "plugin.py",
  "platform": "python",
  "permissions": ["text.read", "text.modify"]
}
EOF

# 3. Create plugin.py
cat > plugin.py << 'EOF'
class VoiceFlowPlugin:
    def __init__(self, manifest):
        self.manifest = manifest
        self.plugin_id = manifest['id']

    def on_load(self):
        print(f"✅ {self.manifest['name']} loaded!")

    def on_transcription(self, text: str) -> str:
        # Convert to title case
        return text.title()

    def on_unload(self):
        print(f"👋 {self.manifest['name']} unloaded")
EOF

# 4. Install plugin
cp -r ~/MyFirstPythonPlugin ~/Library/Application\ Support/VoiceFlow/Plugins/

# 5. Restart VoiceFlow and enable your plugin in settings
```

**That's it!** You've created a working plugin. Now let's understand how it works.

---

## Architecture Overview

### Plugin System Components

VoiceFlow's plugin architecture consists of four main components:

```
┌─────────────────────────────────────────────────────────┐
│                    VoiceFlow App                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │            PluginManager (Swift)                  │  │
│  │  • Discovers plugins                              │  │
│  │  • Loads manifests                                │  │
│  │  │  • Manages lifecycle                            │  │
│  └──┬───────────────────────────────────────────────┘  │
│     │                                                   │
│     ├─► Swift Plugins (via PluginLoader)              │
│     │   • Loaded as dynamic frameworks                │
│     │   • Run in-process                              │
│     │                                                   │
│     └─► Python Plugins (via ASR Server)               │
│         • Run in Python subprocess                    │
│         • Communicate via WebSocket                   │
└─────────────────────────────────────────────────────────┘
```

### Plugin Lifecycle

Every plugin follows this lifecycle:

1. **Discovery**: VoiceFlow scans `~/Library/Application Support/VoiceFlow/Plugins/`
2. **Validation**: Manifest is validated against schema
3. **Loading**: Plugin is instantiated with manifest data
4. **Initialization**: `onLoad()` / `on_load()` is called
5. **Processing**: `onTranscription()` / `on_transcription()` is called for each transcription
6. **Cleanup**: `onUnload()` / `on_unload()` is called on shutdown or disable

### Text Processing Pipeline

When you speak into VoiceFlow:

```
[Microphone] → [ASR Model] → [Raw Text] → [Plugin Chain] → [Output Text]
                                              ↓
                                         Plugin 1
                                              ↓
                                         Plugin 2
                                              ↓
                                         Plugin N
```

Plugins are **chained sequentially**. Each plugin receives the output of the previous plugin, allowing you to compose multiple transformations.

### Platform Differences

| Feature | Swift Plugins | Python Plugins |
|---------|--------------|----------------|
| Execution | In VoiceFlow process | In ASR server subprocess |
| Performance | Fast (native code) | Moderate (Python interpreter) |
| Dependencies | Swift Package Manager | pip (requirements.txt) |
| Best For | Text transformations, system integration | ML models, complex text processing |
| Debugging | Xcode debugger, Console.app | print() statements, logs |

---

## Creating Your First Plugin

Let's build a more sophisticated plugin step-by-step: a **profanity filter** that replaces bad words with asterisks.

### Step 1: Plan Your Plugin

Ask yourself:
- **What does it do?** Filters profanity from transcribed text
- **Platform?** Python (easier text processing)
- **Permissions needed?** `text.read`, `text.modify`
- **Dependencies?** None (we'll use a simple word list)

### Step 2: Create Directory Structure

```bash
mkdir -p ~/ProfanityFilterPlugin
cd ~/ProfanityFilterPlugin
```

Your plugin directory should contain:
- `manifest.json` (required)
- `plugin.py` or `plugin.swift` (required, name must match `entrypoint`)
- `README.md` (recommended)
- `requirements.txt` (Python only, if dependencies needed)
- Any additional resources (word lists, models, etc.)

### Step 3: Write the Manifest

Create `manifest.json`:

```json
{
  "id": "com.example.profanityfilter",
  "name": "Profanity Filter",
  "version": "1.0.0",
  "author": "Your Name",
  "description": "Filters profanity from transcribed text by replacing bad words with asterisks",
  "entrypoint": "plugin.py",
  "platform": "python",
  "permissions": [
    "text.read",
    "text.modify"
  ],
  "homepage": "https://github.com/yourname/profanityfilter-plugin",
  "license": "MIT",
  "minVoiceFlowVersion": "1.0.0"
}
```

**Key Points:**
- `id` must be unique (use reverse domain notation)
- `version` follows semantic versioning (MAJOR.MINOR.PATCH)
- `entrypoint` filename must match your implementation file
- `platform` must be `"swift"`, `"python"`, or `"both"`

### Step 4: Implement the Plugin

Create `plugin.py`:

```python
import re

class VoiceFlowPlugin:
    """Profanity filter plugin for VoiceFlow."""

    def __init__(self, manifest):
        self.manifest = manifest
        self.plugin_id = manifest['id']
        self.bad_words = []

    def on_load(self):
        """Initialize the plugin when loaded."""
        # Load profanity word list
        self.bad_words = [
            'badword1',
            'badword2',
            'badword3'
            # Add more words as needed
        ]

        # Create regex pattern (case-insensitive)
        self.pattern = re.compile(
            r'\b(' + '|'.join(re.escape(word) for word in self.bad_words) + r')\b',
            re.IGNORECASE
        )

        print(f"✅ {self.manifest['name']} loaded with {len(self.bad_words)} filtered words")

    def on_transcription(self, text: str) -> str:
        """Process transcribed text and filter profanity."""
        if not text:
            return text

        # Replace bad words with asterisks
        def replace_with_asterisks(match):
            word = match.group(0)
            return '*' * len(word)

        filtered_text = self.pattern.sub(replace_with_asterisks, text)

        # Log if filtering occurred
        if filtered_text != text:
            print(f"🚫 Profanity filtered in: {self.plugin_id}")

        return filtered_text

    def on_unload(self):
        """Clean up when plugin is unloaded."""
        print(f"👋 {self.manifest['name']} unloaded")
        self.bad_words = []
```

### Step 5: Test Locally

Before installing, test your plugin:

```python
# test_plugin.py
import json

# Load manifest
with open('manifest.json') as f:
    manifest = json.load(f)

# Import plugin
from plugin import VoiceFlowPlugin

# Initialize
plugin = VoiceFlowPlugin(manifest)
plugin.on_load()

# Test cases
test_inputs = [
    "This is clean text",
    "This has badword1 in it",
    "Multiple badword2 and badword3 here"
]

for text in test_inputs:
    result = plugin.on_transcription(text)
    print(f"Input:  {text}")
    print(f"Output: {result}")
    print()

# Cleanup
plugin.on_unload()
```

Run the test:
```bash
python test_plugin.py
```

### Step 6: Install and Enable

```bash
# Install to VoiceFlow plugins directory
cp -r ~/ProfanityFilterPlugin ~/Library/Application\ Support/VoiceFlow/Plugins/

# Restart VoiceFlow
# Open Settings → Plugins → Enable "Profanity Filter"
```

---

## Plugin Manifest Reference

The manifest is a JSON file that describes your plugin. Here's a complete reference:

### Required Fields

```json
{
  "id": "com.example.myplugin",
  "name": "My Plugin Name",
  "version": "1.0.0",
  "author": "Developer Name or Organization",
  "description": "Brief description of what the plugin does (10-500 characters)",
  "entrypoint": "plugin.swift",
  "platform": "swift"
}
```

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `id` | string | Unique identifier in reverse domain notation | `"com.example.myplugin"` |
| `name` | string | Human-readable plugin name | `"Text Formatter"` |
| `version` | string | Semantic version (MAJOR.MINOR.PATCH) | `"1.2.3"` |
| `author` | string | Plugin author or organization | `"John Doe"` |
| `description` | string | Brief description (10-500 chars) | `"Formats text with proper capitalization"` |
| `entrypoint` | string | Main plugin file (relative path) | `"plugin.swift"` or `"plugin.py"` |
| `platform` | string | Execution platform | `"swift"`, `"python"`, or `"both"` |

### Optional Fields

```json
{
  "permissions": ["text.read", "text.modify", "network.http"],
  "minVoiceFlowVersion": "1.0.0",
  "homepage": "https://github.com/user/plugin",
  "license": "MIT",
  "dependencies": {
    "python": ["requests>=2.28.0", "numpy>=1.24.0"],
    "swift": ["https://github.com/user/SwiftPackage.git"]
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `permissions` | array | Informational list of capabilities used (not enforced) |
| `minVoiceFlowVersion` | string | Minimum VoiceFlow version required |
| `homepage` | string | Plugin documentation or repository URL |
| `license` | string | SPDX license identifier |
| `dependencies` | object | Platform-specific dependencies |

### Permission Types (Informational Only)

| Permission | Description |
|------------|-------------|
| `text.read` | Plugin reads transcribed text |
| `text.modify` | Plugin modifies transcribed text |
| `network.http` | Plugin makes HTTP requests |
| `network.websocket` | Plugin uses WebSocket connections |
| `filesystem.read` | Plugin reads files |
| `filesystem.write` | Plugin writes files |
| `system.execute` | Plugin executes system commands |

**Remember:** Permissions are **not enforced**. They serve as documentation for users to understand what the plugin does.

---

## Swift Plugin Implementation

Swift plugins run directly in the VoiceFlow process, offering native performance.

### Basic Structure

```swift
import Foundation

class MyPlugin: VoiceFlowPlugin {
    // Required: Unique plugin identifier (must match manifest.id)
    var pluginID: String { "com.example.myplugin" }

    // Required: Manifest data passed during initialization
    var manifest: PluginManifest

    // Required: Initialize with manifest
    init(manifest: PluginManifest) {
        self.manifest = manifest
    }

    // Required: Called when plugin is loaded
    func onLoad() {
        print("Plugin loaded: \(manifest.name)")
    }

    // Required: Process transcribed text
    func onTranscription(_ text: String) -> String {
        // Your transformation logic here
        return text
    }

    // Required: Called when plugin is unloaded
    func onUnload() {
        print("Plugin unloaded")
    }
}
```

### VoiceFlowPlugin Protocol

Your plugin class **must** conform to the `VoiceFlowPlugin` protocol:

```swift
protocol VoiceFlowPlugin {
    var pluginID: String { get }
    var manifest: PluginManifest { get }

    init(manifest: PluginManifest)
    func onLoad()
    func onTranscription(_ text: String) -> String
    func onUnload()
}
```

### PluginManifest Type

The manifest is passed as a structured type:

```swift
struct PluginManifest {
    let id: String
    let name: String
    let version: String
    let author: String
    let description: String
    let entrypoint: String
    let platform: String
    let permissions: [String]
    let homepage: String?
    let license: String?
    let minVoiceFlowVersion: String?
}
```

### Example: Number Formatter Plugin

```swift
import Foundation

class NumberFormatterPlugin: VoiceFlowPlugin {
    var pluginID: String { "com.example.numberformatter" }
    var manifest: PluginManifest

    private let numberFormatter = NumberFormatter()

    init(manifest: PluginManifest) {
        self.manifest = manifest
    }

    func onLoad() {
        // Configure number formatter
        numberFormatter.numberStyle = .decimal
        numberFormatter.locale = Locale(identifier: "en_US")

        print("✅ \(manifest.name) v\(manifest.version) loaded")
    }

    func onTranscription(_ text: String) -> String {
        // Convert number words to digits
        // "one hundred twenty three" → "123"

        let wordToNumber: [String: Int] = [
            "zero": 0, "one": 1, "two": 2, "three": 3,
            "four": 4, "five": 5, "six": 6, "seven": 7,
            "eight": 8, "nine": 9, "ten": 10
        ]

        var result = text

        for (word, number) in wordToNumber {
            let pattern = "\\b\(word)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: range,
                    withTemplate: "\(number)"
                )
            }
        }

        return result
    }

    func onUnload() {
        print("👋 \(manifest.name) unloaded")
    }
}
```

### Compiling Swift Plugins

Swift plugins are loaded dynamically, so they must be compiled as frameworks:

```bash
# Compile plugin as dynamic framework
swiftc -emit-library -o MyPlugin.dylib plugin.swift

# Or use Swift Package Manager
swift build -c release
```

For detailed compilation instructions, see the **PLUGIN_PACKAGING.md** guide.

---

## Python Plugin Implementation

Python plugins run in the ASR server subprocess, making them ideal for complex text processing and ML models.

### Basic Structure

```python
class VoiceFlowPlugin:
    """Base class for VoiceFlow Python plugins."""

    def __init__(self, manifest):
        """
        Initialize plugin with manifest data.

        Args:
            manifest (dict): Parsed manifest.json data
        """
        self.manifest = manifest
        self.plugin_id = manifest['id']

    def on_load(self):
        """Called when plugin is loaded. Use for initialization."""
        pass

    def on_transcription(self, text: str) -> str:
        """
        Process transcribed text.

        Args:
            text (str): Input text from ASR or previous plugin

        Returns:
            str: Transformed text
        """
        return text

    def on_unload(self):
        """Called when plugin is unloaded. Use for cleanup."""
        pass
```

### Example: Punctuation Plugin

```python
import re

class VoiceFlowPlugin:
    """Adds smart punctuation to transcribed text."""

    def __init__(self, manifest):
        self.manifest = manifest
        self.plugin_id = manifest['id']
        self.sentence_enders = {}

    def on_load(self):
        """Initialize punctuation rules."""
        # Words that typically end sentences with specific punctuation
        self.sentence_enders = {
            'question': '?',
            'really': '?',
            'seriously': '?',
            'wow': '!',
            'amazing': '!',
            'incredible': '!'
        }

        print(f"✅ {self.manifest['name']} loaded")

    def on_transcription(self, text: str) -> str:
        """Add punctuation based on context."""
        if not text:
            return text

        # Remove existing punctuation for clean slate
        text = text.rstrip('.,!?;:')

        # Check last word for special ending
        words = text.split()
        if words:
            last_word = words[-1].lower()

            # Apply special punctuation if word matches
            for word, punct in self.sentence_enders.items():
                if last_word == word or last_word.endswith(word):
                    return text + punct

        # Default: add period
        return text + '.'

    def on_unload(self):
        """Cleanup resources."""
        print(f"👋 {self.manifest['name']} unloaded")
        self.sentence_enders = {}
```

### Using External Dependencies

If your plugin needs external libraries, specify them in `requirements.txt`:

```txt
# requirements.txt
requests>=2.28.0
beautifulsoup4>=4.11.0
numpy>=1.24.0
```

And reference it in your manifest:

```json
{
  "dependencies": {
    "python": ["requests>=2.28.0", "beautifulsoup4>=4.11.0"]
  }
}
```

VoiceFlow will install these dependencies when the plugin is loaded.

### Async Operations

Python plugins can use async/await for non-blocking operations:

```python
import asyncio
import aiohttp

class VoiceFlowPlugin:
    def __init__(self, manifest):
        self.manifest = manifest
        self.plugin_id = manifest['id']

    def on_load(self):
        print(f"✅ {self.manifest['name']} loaded")

    async def fetch_translation(self, text):
        """Async HTTP request example."""
        async with aiohttp.ClientSession() as session:
            async with session.post('https://api.translate.com', json={'text': text}) as resp:
                return await resp.json()

    def on_transcription(self, text: str) -> str:
        """Sync wrapper for async operations."""
        # Run async code in event loop
        loop = asyncio.get_event_loop()
        result = loop.run_until_complete(self.fetch_translation(text))
        return result.get('translated_text', text)

    def on_unload(self):
        print(f"👋 {self.manifest['name']} unloaded")
```

---

## Debugging Techniques

### Console Logging

**Swift:**
```swift
func onTranscription(_ text: String) -> String {
    print("🔍 [DEBUG] Input: \(text)")
    let result = text.uppercased()
    print("🔍 [DEBUG] Output: \(result)")
    return result
}
```

**Python:**
```python
def on_transcription(self, text: str) -> str:
    print(f"🔍 [DEBUG] Input: {text}")
    result = text.upper()
    print(f"🔍 [DEBUG] Output: {result}")
    return result
```

View logs in **Console.app** (macOS):
1. Open Console.app
2. Filter by "VoiceFlow" or your plugin name
3. Watch real-time logs as you test

### Manifest Validation

Validate your manifest before installation:

```bash
# Using Python jsonschema
python3 << 'EOF'
import json
import jsonschema

# Load schema
with open('Plugins/manifest-schema.json') as f:
    schema = json.load(f)

# Load your manifest
with open('path/to/your/manifest.json') as f:
    manifest = json.load(f)

# Validate
try:
    jsonschema.validate(manifest, schema)
    print("✅ Manifest is valid!")
except jsonschema.ValidationError as e:
    print(f"❌ Validation error: {e.message}")
EOF
```

### Testing Without Installation

Test plugins without installing to VoiceFlow:

**Python Plugin Test Harness:**
```python
#!/usr/bin/env python3
import json
import sys

# Load plugin
sys.path.insert(0, '.')
from plugin import VoiceFlowPlugin

# Load manifest
with open('manifest.json') as f:
    manifest = json.load(f)

# Initialize
plugin = VoiceFlowPlugin(manifest)
plugin.on_load()

# Test cases
tests = [
    ("hello world", "Expected output here"),
    ("test input", "Expected output here"),
]

print("\n🧪 Running tests...")
for input_text, expected in tests:
    result = plugin.on_transcription(input_text)
    status = "✅" if result == expected else "❌"
    print(f"{status} Input: '{input_text}'")
    print(f"   Output: '{result}'")
    print(f"   Expected: '{expected}'")
    print()

# Cleanup
plugin.on_unload()
```

### Error Handling

Always handle errors gracefully:

```python
def on_transcription(self, text: str) -> str:
    try:
        # Your processing logic
        result = self.process_text(text)
        return result
    except Exception as e:
        # Log error and return original text
        print(f"❌ Error in {self.plugin_id}: {e}")
        return text  # Return original text on error
```

### Common Debug Scenarios

| Issue | Symptom | Solution |
|-------|---------|----------|
| Plugin not loading | Not visible in settings | Check manifest.json syntax, validate against schema |
| Wrong output | Text not transformed | Add print statements, check logic flow |
| Crash on load | App crashes when enabling | Check `onLoad()` / `on_load()` for errors |
| Performance issues | Slow transcription | Profile `onTranscription()`, optimize algorithms |
| Import errors (Python) | Module not found | Verify dependencies in requirements.txt |

---

## Common Pitfalls

### 1. Manifest ID Mismatch

**❌ Wrong:**
```json
// manifest.json
{"id": "com.example.plugin"}
```
```swift
// plugin.swift
var pluginID: String { "com.example.different" }  // Doesn't match!
```

**✅ Correct:**
```swift
var pluginID: String { "com.example.plugin" }  // Matches manifest.id
```

### 2. Forgetting to Return Text

**❌ Wrong:**
```python
def on_transcription(self, text: str) -> str:
    processed = text.upper()
    # Forgot to return!
```

**✅ Correct:**
```python
def on_transcription(self, text: str) -> str:
    processed = text.upper()
    return processed  # Always return!
```

### 3. Mutating State Without Cleanup

**❌ Wrong:**
```python
def __init__(self, manifest):
    self.cache = []  # Memory leak if not cleared

def on_transcription(self, text: str) -> str:
    self.cache.append(text)  # Grows forever!
    return text
```

**✅ Correct:**
```python
def __init__(self, manifest):
    self.cache = []

def on_transcription(self, text: str) -> str:
    self.cache.append(text)
    if len(self.cache) > 100:  # Limit size
        self.cache = self.cache[-100:]
    return text

def on_unload(self):
    self.cache = []  # Clean up
```

### 4. Blocking Operations

**❌ Wrong:**
```python
def on_transcription(self, text: str) -> str:
    time.sleep(5)  # Blocks transcription pipeline!
    return text
```

**✅ Correct:**
```python
def on_transcription(self, text: str) -> str:
    # Use async or background threads for long operations
    # Keep this method fast (<100ms)
    return text
```

### 5. Platform Confusion

**❌ Wrong:**
```json
{"platform": "both", "entrypoint": "plugin.swift"}
// Missing plugin.py for Python!
```

**✅ Correct:**
```json
{"platform": "swift", "entrypoint": "plugin.swift"}
// Or provide both plugin.swift AND plugin.py if using "both"
```

---

## Best Practices

### 1. Keep `onTranscription` Fast

- Target: < 100ms processing time
- Offload heavy work to background threads
- Cache expensive computations

### 2. Handle Edge Cases

```python
def on_transcription(self, text: str) -> str:
    # Handle empty/None input
    if not text or not text.strip():
        return text

    # Handle special characters
    # Handle multiple languages
    # Handle very long text

    return processed_text
```

### 3. Version Your Plugins

Use semantic versioning:
- **MAJOR**: Breaking changes to behavior
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes

### 4. Document Your Plugin

Include a README.md:

```markdown
# My Plugin Name

## Description
Brief description of what the plugin does.

## Installation
1. Download plugin archive
2. Extract to `~/Library/Application Support/VoiceFlow/Plugins/`
3. Restart VoiceFlow
4. Enable in Settings → Plugins

## Configuration
If applicable, explain configuration options.

## Examples
Input: "hello world"
Output: "HELLO WORLD"

## License
MIT License
```

### 5. Test Thoroughly

Create a comprehensive test suite:
- Empty input
- Very long input (1000+ words)
- Special characters (emoji, punctuation)
- Multiple languages
- Edge cases specific to your logic

---

## Next Steps

### Learn More

- **[PLUGIN_API_REFERENCE.md](./PLUGIN_API_REFERENCE.md)**: Complete API documentation
- **[PLUGIN_TESTING.md](./PLUGIN_TESTING.md)**: Testing strategies and frameworks
- **[PLUGIN_PACKAGING.md](./PLUGIN_PACKAGING.md)**: Distribution and versioning guide

### Explore Examples

Check out the example plugins in `Plugins/Examples/`:
- **UppercasePlugin** (Swift): Simple text transformation
- **PunctuationPlugin** (Python): Smart punctuation insertion
- **WebhookPlugin** (Swift): HTTP network integration

### Use Development Tools

```bash
# Validate manifest
scripts/plugin-dev-tools.sh validate path/to/plugin

# Run tests
scripts/plugin-dev-tools.sh test path/to/plugin

# Package for distribution
scripts/plugin-dev-tools.sh package path/to/plugin

# Install locally
scripts/plugin-dev-tools.sh install path/to/plugin
```

### Join the Community

- Share your plugins
- Report bugs and request features
- Contribute to documentation

---

## Appendix: Quick Reference

### Lifecycle Methods

| Method | Swift | Python | Purpose |
|--------|-------|--------|---------|
| Initialize | `init(manifest:)` | `__init__(manifest)` | Set up plugin with manifest |
| Load | `onLoad()` | `on_load()` | Initialize resources |
| Process | `onTranscription(_:)` | `on_transcription(text)` | Transform text |
| Unload | `onUnload()` | `on_unload()` | Clean up resources |

### Directory Structure

```
MyPlugin/
├── manifest.json          # Required: Plugin metadata
├── plugin.swift           # Swift implementation (or plugin.py)
├── README.md              # Recommended: User documentation
├── LICENSE                # Recommended: License file
├── requirements.txt       # Python only: Dependencies
└── resources/             # Optional: Additional files
    ├── wordlist.txt
    └── model.pkl
```

### Manifest Template

```json
{
  "id": "com.yourname.pluginname",
  "name": "Plugin Display Name",
  "version": "1.0.0",
  "author": "Your Name",
  "description": "What your plugin does in one sentence",
  "entrypoint": "plugin.swift",
  "platform": "swift",
  "permissions": ["text.read", "text.modify"],
  "homepage": "https://github.com/yourname/plugin",
  "license": "MIT"
}
```

---

**You're now ready to build amazing VoiceFlow plugins!** Start with a simple text transformation, then gradually add complexity as you learn the system. Happy coding! 🚀
