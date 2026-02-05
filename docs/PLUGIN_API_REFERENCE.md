# VoiceFlow Plugin API Reference

**Version:** 1.0.0
**Last Updated:** 2024

---

## Table of Contents

1. [Overview](#overview)
2. [Swift Plugin API](#swift-plugin-api)
3. [Python Plugin API](#python-plugin-api)
4. [PluginManifest Structure](#pluginmanifest-structure)
5. [Permission Model](#permission-model)
6. [Error Handling](#error-handling)
7. [Lifecycle Hooks](#lifecycle-hooks)
8. [Manifest Schema Reference](#manifest-schema-reference)
9. [Type Definitions](#type-definitions)
10. [Code Examples](#code-examples)

---

## Overview

The VoiceFlow Plugin API provides a standardized interface for extending VoiceFlow's transcription capabilities. Plugins can be written in Swift or Python and follow a consistent lifecycle model.

### Key Concepts

- **Lifecycle**: Plugins go through Discovery → Validation → Loading → Initialization → Processing → Cleanup
- **Text Pipeline**: Plugins receive transcribed text, transform it, and return modified text
- **Chaining**: Multiple plugins execute sequentially, each receiving the output of the previous plugin
- **Platform Support**: Swift (native, in-process) or Python (subprocess via ASR server)

### Security Model

**⚠️ CRITICAL: The VoiceFlow plugin system uses a trust-based security model.**

- Permissions are **declarative only** and **NOT enforced** by the runtime
- Plugins run with full application privileges
- No sandboxing or isolation is provided
- Users must trust plugin authors completely

---

## Swift Plugin API

### VoiceFlowPlugin Protocol

All Swift plugins must conform to the `VoiceFlowPlugin` protocol.

#### Protocol Definition

```swift
public protocol VoiceFlowPlugin {
    /// Unique identifier matching the manifest's "id" field
    var pluginID: String { get }

    /// Manifest data loaded from manifest.json
    var manifest: PluginManifest { get }

    /// Initialize plugin with manifest data
    /// - Parameter manifest: Parsed manifest containing plugin metadata
    init(manifest: PluginManifest)

    /// Called once when the plugin is loaded and enabled
    /// Use this for one-time initialization, resource allocation, configuration
    func onLoad()

    /// Called for each transcribed text segment
    /// - Parameter text: The transcribed text (or output from previous plugin)
    /// - Returns: Transformed text to pass to next plugin or final output
    func onTranscription(_ text: String) -> String

    /// Called when the plugin is disabled or VoiceFlow exits
    /// Use this for cleanup, resource deallocation, persisting state
    func onUnload()
}
```

#### Required Properties

##### `pluginID: String`

**Type:** `String` (read-only computed property)

**Description:** Unique identifier for the plugin. Must match the `id` field in `manifest.json` exactly.

**Format:** Reverse domain notation (e.g., `"com.example.myplugin"`)

**Example:**
```swift
var pluginID: String { "com.example.textformatter" }
```

**Requirements:**
- Must be a constant value
- Must match `manifest.id`
- Should use reverse domain notation
- Must be globally unique

---

##### `manifest: PluginManifest`

**Type:** `PluginManifest` (struct)

**Description:** Contains parsed metadata from the plugin's `manifest.json` file.

**Usage:**
```swift
var manifest: PluginManifest

func onLoad() {
    print("Loading \(manifest.name) v\(manifest.version)")
    print("Author: \(manifest.author)")
}
```

**Available Fields:** See [PluginManifest Structure](#pluginmanifest-structure)

---

#### Required Methods

##### `init(manifest: PluginManifest)`

**Signature:**
```swift
init(manifest: PluginManifest)
```

**Description:** Initializer called when the plugin is first instantiated. Store the manifest and initialize any properties.

**Parameters:**
- `manifest`: Pre-populated `PluginManifest` struct with validated data

**When Called:** During plugin discovery and validation, before `onLoad()`

**Example:**
```swift
class MyPlugin: VoiceFlowPlugin {
    var pluginID: String { "com.example.myplugin" }
    var manifest: PluginManifest

    private var configuration: [String: Any] = [:]

    init(manifest: PluginManifest) {
        self.manifest = manifest
        self.configuration["version"] = manifest.version
    }
}
```

**Best Practices:**
- Keep initialization lightweight
- Don't perform I/O or network operations here
- Defer heavy initialization to `onLoad()`
- Store manifest reference for later use

---

##### `func onLoad()`

**Signature:**
```swift
func onLoad()
```

**Description:** Called once when the plugin is enabled. Perform one-time initialization tasks.

**When Called:**
- When plugin is enabled in VoiceFlow settings
- When VoiceFlow starts with plugin already enabled

**Use Cases:**
- Load configuration files
- Initialize resources (databases, network connections)
- Set up caches or lookup tables
- Validate runtime environment
- Log startup information

**Example:**
```swift
func onLoad() {
    // Load word list from resources
    if let path = Bundle.main.path(forResource: "words", ofType: "txt") {
        wordList = try? String(contentsOfFile: path).components(separatedBy: .newlines)
    }

    // Initialize cache
    cache = NSCache<NSString, NSString>()
    cache.countLimit = 1000

    // Log startup
    print("✅ \(manifest.name) v\(manifest.version) loaded")
}
```

**Error Handling:**
- If initialization fails, log the error but don't crash
- Plugin should gracefully degrade or return unmodified text
- Consider throwing or returning error status in future API versions

**Thread Safety:** Called on main thread; avoid blocking operations

---

##### `func onTranscription(_ text: String) -> String`

**Signature:**
```swift
func onTranscription(_ text: String) -> String
```

**Description:** Process and optionally transform transcribed text. This is the core plugin functionality.

**Parameters:**
- `text`: Input text (from ASR or previous plugin in chain)

**Returns:** Transformed text or original text if no changes

**When Called:** Every time a transcription segment is finalized

**Performance Requirements:**
- Target: < 100ms processing time
- Avoid blocking operations (network I/O, disk I/O)
- Use caching for expensive computations
- Consider async processing for heavy operations

**Example:**
```swift
func onTranscription(_ text: String) -> String {
    // Early return for empty input
    guard !text.isEmpty else { return text }

    // Apply transformation
    var result = text

    // Example: Convert numbers to words
    let numberPattern = try! NSRegularExpression(pattern: "\\d+")
    let range = NSRange(result.startIndex..., in: result)

    numberPattern.enumerateMatches(in: result, range: range) { match, _, _ in
        if let match = match, let range = Range(match.range, in: result) {
            let number = String(result[range])
            if let numValue = Int(number) {
                let word = numberToWord(numValue)
                result.replaceSubrange(range, with: word)
            }
        }
    }

    return result
}
```

**Best Practices:**
- **Always return a value** (return original text if processing fails)
- Handle edge cases (empty, nil, very long text)
- Use error handling to prevent crashes
- Log transformations for debugging
- Optimize for common cases

**Error Handling:**
```swift
func onTranscription(_ text: String) -> String {
    do {
        let transformed = try processText(text)
        return transformed
    } catch {
        print("⚠️ Error in \(pluginID): \(error)")
        return text  // Return original on error
    }
}
```

**Thread Safety:** May be called from background thread; ensure thread-safe operations

---

##### `func onUnload()`

**Signature:**
```swift
func onUnload()
```

**Description:** Called when plugin is disabled or VoiceFlow exits. Clean up resources.

**When Called:**
- When plugin is disabled in settings
- When VoiceFlow quits
- When plugin is being reloaded (after update)

**Use Cases:**
- Close file handles, network connections
- Flush caches or save state
- Release allocated memory
- Cancel background tasks
- Log shutdown information

**Example:**
```swift
func onUnload() {
    // Close database connection
    database?.close()
    database = nil

    // Clear caches
    cache.removeAllObjects()

    // Cancel pending operations
    operationQueue.cancelAllOperations()

    // Log shutdown
    print("👋 \(manifest.name) unloaded")
}
```

**Best Practices:**
- Make cleanup idempotent (safe to call multiple times)
- Don't throw errors (silently handle cleanup failures)
- Keep cleanup fast (< 1 second)
- Persist important state before clearing

**Thread Safety:** Called on main thread

---

## Python Plugin API

### VoiceFlowPlugin Base Class

Python plugins inherit from the `VoiceFlowPlugin` base class.

#### Class Definition

```python
class VoiceFlowPlugin:
    """
    Base class for VoiceFlow Python plugins.

    All Python plugins must inherit from this class and implement
    the lifecycle methods.
    """

    def __init__(self, manifest: dict):
        """
        Initialize plugin with manifest data.

        Args:
            manifest (dict): Parsed manifest.json data
        """
        self.manifest = manifest
        self.plugin_id = manifest['id']

    def on_load(self):
        """
        Called when plugin is loaded and enabled.

        Use this for initialization:
        - Load configuration
        - Initialize resources
        - Set up caches
        - Load ML models
        """
        pass

    def on_transcription(self, text: str) -> str:
        """
        Process transcribed text.

        Args:
            text (str): Input text from ASR or previous plugin

        Returns:
            str: Transformed text or original if no changes
        """
        return text

    def on_unload(self):
        """
        Called when plugin is disabled or unloaded.

        Use this for cleanup:
        - Close connections
        - Save state
        - Free resources
        """
        pass
```

---

#### Methods

##### `__init__(self, manifest: dict)`

**Description:** Constructor called when plugin is instantiated.

**Parameters:**
- `manifest` (dict): Parsed manifest.json containing all metadata

**When Called:** During plugin discovery, before `on_load()`

**Example:**
```python
def __init__(self, manifest):
    """Initialize plugin with manifest data."""
    super().__init__(manifest)

    # Store manifest reference
    self.manifest = manifest
    self.plugin_id = manifest['id']

    # Initialize instance variables
    self.cache = {}
    self.config = {}
    self.is_loaded = False
```

**Available Manifest Fields:**
```python
self.manifest['id']              # str: Unique identifier
self.manifest['name']            # str: Display name
self.manifest['version']         # str: Semantic version
self.manifest['author']          # str: Author name
self.manifest['description']     # str: Description
self.manifest['platform']        # str: "python" or "both"
self.manifest['entrypoint']      # str: Entry file name
self.manifest.get('permissions', [])      # list: Permissions (optional)
self.manifest.get('homepage')             # str: URL (optional)
self.manifest.get('license')              # str: License (optional)
self.manifest.get('minVoiceFlowVersion')  # str: Min version (optional)
```

---

##### `on_load(self)`

**Description:** Called once when plugin is enabled. Initialize resources.

**When Called:**
- Plugin enabled in VoiceFlow settings
- VoiceFlow starts with plugin already enabled

**Example:**
```python
def on_load(self):
    """Initialize plugin resources."""
    # Load configuration from file
    config_path = os.path.join(os.path.dirname(__file__), 'config.json')
    if os.path.exists(config_path):
        with open(config_path) as f:
            self.config = json.load(f)

    # Load ML model
    model_path = os.path.join(os.path.dirname(__file__), 'model.pkl')
    if os.path.exists(model_path):
        with open(model_path, 'rb') as f:
            self.model = pickle.load(f)

    # Initialize cache
    self.cache = {}

    # Set up logging
    logging.info(f"✅ {self.manifest['name']} v{self.manifest['version']} loaded")

    self.is_loaded = True
```

**Best Practices:**
- Use try-except to handle initialization errors gracefully
- Load resources from plugin directory (use `__file__` for paths)
- Initialize external dependencies
- Set up logging for debugging

---

##### `on_transcription(self, text: str) -> str`

**Description:** Process transcribed text. Core plugin functionality.

**Parameters:**
- `text` (str): Input text from ASR or previous plugin

**Returns:**
- `str`: Transformed text or original text if no changes

**When Called:** For every transcription segment

**Performance:** Target < 100ms; avoid blocking I/O

**Example:**
```python
def on_transcription(self, text: str) -> str:
    """
    Transform transcribed text.

    Args:
        text: Input text

    Returns:
        Transformed text
    """
    # Handle empty input
    if not text or not text.strip():
        return text

    try:
        # Check cache first
        if text in self.cache:
            return self.cache[text]

        # Apply transformation
        result = self._process_text(text)

        # Cache result
        self.cache[text] = result

        # Limit cache size
        if len(self.cache) > 1000:
            # Remove oldest entries (simple FIFO)
            keys = list(self.cache.keys())
            for key in keys[:100]:
                del self.cache[key]

        return result

    except Exception as e:
        # Log error and return original text
        logging.error(f"❌ Error in {self.plugin_id}: {e}")
        return text

def _process_text(self, text: str) -> str:
    """Internal processing logic."""
    # Your transformation logic here
    return text.upper()
```

**Error Handling:**
- Always wrap in try-except
- Return original text on error
- Log errors for debugging
- Don't let exceptions propagate

---

##### `on_unload(self)`

**Description:** Called when plugin is disabled. Clean up resources.

**When Called:**
- Plugin disabled in settings
- VoiceFlow exits
- Plugin being reloaded

**Example:**
```python
def on_unload(self):
    """Clean up plugin resources."""
    try:
        # Close database connections
        if hasattr(self, 'db') and self.db:
            self.db.close()
            self.db = None

        # Save cache to disk
        if hasattr(self, 'cache') and self.cache:
            cache_path = os.path.join(os.path.dirname(__file__), 'cache.json')
            with open(cache_path, 'w') as f:
                json.dump(self.cache, f)

        # Clear memory
        self.cache = {}
        self.config = {}

        logging.info(f"👋 {self.manifest['name']} unloaded")

    except Exception as e:
        logging.error(f"Error during cleanup: {e}")
```

**Best Practices:**
- Use try-except to prevent cleanup errors
- Make cleanup idempotent
- Clear references to large objects
- Persist important state

---

### Async Support

Python plugins can use async/await for non-blocking operations:

```python
import asyncio
import aiohttp

class VoiceFlowPlugin:
    def __init__(self, manifest):
        self.manifest = manifest
        self.plugin_id = manifest['id']
        self.session = None

    def on_load(self):
        """Initialize async HTTP session."""
        self.session = aiohttp.ClientSession()
        print(f"✅ {self.manifest['name']} loaded")

    async def _fetch_data(self, text):
        """Async HTTP request example."""
        async with self.session.post(
            'https://api.example.com/process',
            json={'text': text}
        ) as response:
            data = await response.json()
            return data.get('result', text)

    def on_transcription(self, text: str) -> str:
        """Sync wrapper for async processing."""
        try:
            # Run async code
            loop = asyncio.get_event_loop()
            result = loop.run_until_complete(self._fetch_data(text))
            return result
        except Exception as e:
            print(f"❌ Error: {e}")
            return text

    def on_unload(self):
        """Close async session."""
        if self.session:
            loop = asyncio.get_event_loop()
            loop.run_until_complete(self.session.close())
        print(f"👋 {self.manifest['name']} unloaded")
```

---

## PluginManifest Structure

### Swift Type Definition

```swift
public struct PluginManifest {
    /// Unique plugin identifier (reverse domain notation)
    public let id: String

    /// Human-readable plugin name
    public let name: String

    /// Semantic version (MAJOR.MINOR.PATCH)
    public let version: String

    /// Plugin author or organization
    public let author: String

    /// Brief description (10-500 characters)
    public let description: String

    /// Entry point file (relative path)
    public let entrypoint: String

    /// Execution platform: "swift", "python", or "both"
    public let platform: String

    /// Declared permissions (informational only)
    public let permissions: [String]

    /// Homepage or repository URL (optional)
    public let homepage: String?

    /// SPDX license identifier (optional)
    public let license: String?

    /// Minimum VoiceFlow version required (optional)
    public let minVoiceFlowVersion: String?

    /// Platform-specific dependencies (optional)
    public let dependencies: [String: [String]]?
}
```

### Python Type (Dictionary)

```python
manifest = {
    'id': str,                          # Required
    'name': str,                        # Required
    'version': str,                     # Required
    'author': str,                      # Required
    'description': str,                 # Required
    'entrypoint': str,                  # Required
    'platform': str,                    # Required: "swift", "python", or "both"
    'permissions': List[str],           # Optional
    'homepage': str,                    # Optional
    'license': str,                     # Optional
    'minVoiceFlowVersion': str,        # Optional
    'dependencies': Dict[str, List[str]] # Optional
}
```

### Field Specifications

#### `id` (required)

**Type:** `string`

**Format:** Reverse domain notation

**Pattern:** `^[a-z0-9]+(\.[a-z0-9]+)+$`

**Examples:**
- `"com.example.myplugin"`
- `"org.github.username.pluginname"`
- `"dev.voiceflow.examples.uppercase"`

**Requirements:**
- Must be globally unique
- Lowercase letters and numbers only
- At least two segments separated by dots
- Must match `pluginID` in code

---

#### `name` (required)

**Type:** `string`

**Length:** 1-100 characters

**Description:** Human-readable display name shown in VoiceFlow UI

**Examples:**
- `"Uppercase Converter"`
- `"Smart Punctuation"`
- `"Profanity Filter"`

---

#### `version` (required)

**Type:** `string`

**Format:** Semantic Versioning (semver)

**Pattern:** `^\d+\.\d+\.\d+$`

**Examples:**
- `"1.0.0"` - Initial release
- `"2.1.3"` - Major 2, Minor 1, Patch 3

**Versioning Rules:**
- **MAJOR**: Incompatible API changes or behavior
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

---

#### `author` (required)

**Type:** `string`

**Length:** 1-200 characters

**Examples:**
- `"John Doe"`
- `"Acme Corporation"`
- `"john@example.com"`

---

#### `description` (required)

**Type:** `string`

**Length:** 10-500 characters

**Description:** Clear explanation of plugin functionality

**Example:**
```json
"description": "Converts transcribed numbers from words to digits (e.g., 'twenty three' becomes '23')"
```

---

#### `entrypoint` (required)

**Type:** `string`

**Format:** Relative file path from plugin directory

**Examples:**
- `"plugin.swift"` - Swift plugin
- `"plugin.py"` - Python plugin
- `"src/main.swift"` - Nested Swift file

**Requirements:**
- Must exist in plugin directory
- For Swift: `.swift` extension
- For Python: `.py` extension
- For "both" platform: both files must exist

---

#### `platform` (required)

**Type:** `string`

**Allowed Values:**
- `"swift"` - Swift only
- `"python"` - Python only
- `"both"` - Provides both Swift and Python implementations

**Platform Selection Guide:**

| Use Case | Recommended Platform |
|----------|---------------------|
| Simple text transformations | Swift (faster) |
| ML/NLP models | Python (better libraries) |
| System integration | Swift (native APIs) |
| Complex text processing | Python (easier) |
| Cross-platform compatibility | Both |

---

#### `permissions` (optional)

**Type:** `array` of `string`

**Default:** `[]` (empty array)

**Description:** Declarative list of capabilities used by plugin

**⚠️ WARNING: Permissions are informational only and NOT enforced**

**Standard Permissions:**

| Permission | Description | Example Use Case |
|------------|-------------|------------------|
| `text.read` | Reads transcribed text | All plugins that process text |
| `text.modify` | Modifies transcribed text | Text transformers, formatters |
| `network.http` | Makes HTTP/HTTPS requests | Webhook integrations, API calls |
| `network.websocket` | Uses WebSocket connections | Real-time sync services |
| `filesystem.read` | Reads files from disk | Loading word lists, models |
| `filesystem.write` | Writes files to disk | Logging, caching, state persistence |
| `system.execute` | Executes system commands | Shell integration, automation |

**Example:**
```json
"permissions": [
    "text.read",
    "text.modify",
    "network.http"
]
```

---

#### `homepage` (optional)

**Type:** `string`

**Format:** Valid URL (HTTP/HTTPS)

**Example:**
```json
"homepage": "https://github.com/username/plugin-repo"
```

---

#### `license` (optional)

**Type:** `string`

**Format:** SPDX license identifier

**Common Values:**
- `"MIT"`
- `"Apache-2.0"`
- `"GPL-3.0"`
- `"BSD-3-Clause"`
- `"Proprietary"`

**Reference:** https://spdx.org/licenses/

---

#### `minVoiceFlowVersion` (optional)

**Type:** `string`

**Format:** Semantic version

**Example:**
```json
"minVoiceFlowVersion": "1.2.0"
```

**Behavior:** Plugin won't load if VoiceFlow version is lower

---

#### `dependencies` (optional)

**Type:** `object` with platform keys

**Structure:**
```json
"dependencies": {
    "python": ["package>=1.0.0", "another-package"],
    "swift": ["https://github.com/user/SwiftPackage.git"]
}
```

**Python Dependencies:**
- Array of pip package specifiers
- Installed via `pip install -r requirements.txt`

**Swift Dependencies:**
- Array of Swift Package Manager URLs
- Must be valid Git repository URLs

---

## Permission Model

### Overview

VoiceFlow uses a **trust-based permission model**. Permissions declared in the manifest are:

- ✅ **Informational**: Help users understand plugin capabilities
- ✅ **Declarative**: Document what the plugin does
- ❌ **NOT enforced**: Runtime does not validate or restrict access
- ❌ **NOT sandboxed**: Plugins run with full application privileges

### Security Implications

**Plugins can:**
- Access all transcribed text (regardless of `text.read` permission)
- Modify any text (regardless of `text.modify` permission)
- Make network requests (regardless of `network.http` permission)
- Read/write files (regardless of filesystem permissions)
- Execute system commands (regardless of `system.execute` permission)
- Access system keychain, environment variables, user data

**Users must:**
- Only install plugins from trusted sources
- Review plugin source code before installation
- Understand that permissions are documentation only
- Assume plugins have full system access

### Best Practices for Plugin Authors

**DO:**
- Declare all permissions your plugin uses
- Be transparent about data collection
- Document privacy implications
- Use minimal necessary permissions
- Include security warnings in README

**DON'T:**
- Omit permissions to hide behavior
- Collect user data without disclosure
- Make undocumented network requests
- Access resources beyond stated permissions

### Example Permission Declaration

```json
{
  "permissions": [
    "text.read",
    "text.modify",
    "network.http",
    "filesystem.read"
  ]
}
```

**README disclosure:**
```markdown
## Privacy & Security

This plugin:
- ✅ Reads transcribed text to analyze content
- ✅ Modifies text to add punctuation
- ✅ Sends anonymized statistics to analytics.example.com
- ✅ Reads local word list from plugin directory

This plugin does NOT:
- ❌ Store transcriptions permanently
- ❌ Share text with third parties
- ❌ Access files outside plugin directory
```

---

## Error Handling

### Error Philosophy

**Plugins should be resilient and never crash VoiceFlow.**

- Catch all exceptions/errors internally
- Return original text on processing failure
- Log errors for debugging
- Degrade gracefully

### Swift Error Handling

```swift
func onTranscription(_ text: String) -> String {
    guard !text.isEmpty else { return text }

    do {
        // Attempt processing
        let result = try riskyOperation(text)
        return result
    } catch let error as NetworkError {
        // Handle specific error type
        print("⚠️ Network error in \(pluginID): \(error.localizedDescription)")
        return text
    } catch {
        // Handle any other error
        print("❌ Unexpected error in \(pluginID): \(error)")
        return text
    }
}
```

### Python Error Handling

```python
def on_transcription(self, text: str) -> str:
    """Process text with comprehensive error handling."""
    if not text or not text.strip():
        return text

    try:
        # Attempt processing
        result = self._risky_operation(text)
        return result

    except ValueError as e:
        # Handle specific exception
        logging.warning(f"⚠️ Value error in {self.plugin_id}: {e}")
        return text

    except Exception as e:
        # Catch-all for unexpected errors
        logging.error(f"❌ Unexpected error in {self.plugin_id}: {e}")
        logging.error(traceback.format_exc())
        return text
```

### Common Error Scenarios

| Scenario | Handling Strategy |
|----------|------------------|
| Empty input | Early return with original text |
| Network timeout | Return original text, log warning |
| File not found | Use defaults, log warning |
| Parsing error | Return original text, log error |
| Out of memory | Clear caches, return original, log error |
| External API failure | Use cached result or return original |

### Logging Best Practices

**Swift:**
```swift
import os.log

let logger = Logger(subsystem: "com.voiceflow.plugins", category: "MyPlugin")

func onTranscription(_ text: String) -> String {
    logger.debug("Processing text: \(text.prefix(50))...")

    // ... processing ...

    logger.info("Successfully transformed text")
    return result
}
```

**Python:**
```python
import logging

# Configure logging in on_load
def on_load(self):
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s [%(name)s] %(levelname)s: %(message)s'
    )
    self.logger = logging.getLogger(self.plugin_id)

def on_transcription(self, text: str) -> str:
    self.logger.debug(f"Processing text: {text[:50]}...")

    # ... processing ...

    self.logger.info("Successfully transformed text")
    return result
```

---

## Lifecycle Hooks

### Lifecycle State Machine

```
┌─────────────┐
│ Uninstalled │
└──────┬──────┘
       │ (User installs plugin)
       ▼
┌─────────────┐
│ Discovered  │ ─── Manifest validation fails ──► [Error State]
└──────┬──────┘
       │ (Manifest valid)
       ▼
┌─────────────┐
│  Validated  │
└──────┬──────┘
       │ (User enables plugin)
       ▼
┌─────────────┐
│   Loading   │ ◄──┐
└──────┬──────┘    │
       │           │ (Reload)
       │           │
       ▼           │
┌─────────────┐   │
│   Loaded    │ ──┘
│ (onLoad)    │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Active    │ ◄──┐
│(onTranscr.) │    │ (Each transcription)
└──────┬──────┘ ───┘
       │
       │ (User disables or app quits)
       ▼
┌─────────────┐
│  Unloading  │
│ (onUnload)  │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Disabled   │
└─────────────┘
```

### Lifecycle Method Call Order

**On Enable:**
```
1. init(manifest:)         # Instantiate
2. onLoad()               # Initialize
3. [Plugin is now active]
```

**During Use:**
```
[For each transcription]
  onTranscription(text)   # Process text
  → Returns transformed text
  → Passed to next plugin or output
```

**On Disable:**
```
1. onUnload()             # Cleanup
2. [Plugin instance destroyed]
```

### Hook Timing Guarantees

| Hook | Thread | Frequency | Duration Limit |
|------|--------|-----------|----------------|
| `init` | Main | Once per load | < 100ms |
| `onLoad` | Main | Once per enable | < 5s |
| `onTranscription` | Background* | Per transcription | < 100ms |
| `onUnload` | Main | Once per disable | < 1s |

*Swift plugins may be called on background thread; Python plugins run in subprocess.

---

## Manifest Schema Reference

### JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["id", "name", "version", "author", "description", "entrypoint", "platform"],
  "properties": {
    "id": {
      "type": "string",
      "pattern": "^[a-z0-9]+(\\.[a-z0-9]+)+$",
      "description": "Unique identifier in reverse domain notation"
    },
    "name": {
      "type": "string",
      "minLength": 1,
      "maxLength": 100,
      "description": "Human-readable plugin name"
    },
    "version": {
      "type": "string",
      "pattern": "^\\d+\\.\\d+\\.\\d+$",
      "description": "Semantic version (MAJOR.MINOR.PATCH)"
    },
    "author": {
      "type": "string",
      "minLength": 1,
      "maxLength": 200,
      "description": "Plugin author or organization"
    },
    "description": {
      "type": "string",
      "minLength": 10,
      "maxLength": 500,
      "description": "Brief plugin description"
    },
    "entrypoint": {
      "type": "string",
      "pattern": "^.+\\.(swift|py)$",
      "description": "Entry point file (plugin.swift or plugin.py)"
    },
    "platform": {
      "type": "string",
      "enum": ["swift", "python", "both"],
      "description": "Execution platform"
    },
    "permissions": {
      "type": "array",
      "items": {
        "type": "string",
        "enum": [
          "text.read",
          "text.modify",
          "network.http",
          "network.websocket",
          "filesystem.read",
          "filesystem.write",
          "system.execute"
        ]
      },
      "description": "Declared permissions (informational only)"
    },
    "homepage": {
      "type": "string",
      "format": "uri",
      "description": "Plugin homepage or repository URL"
    },
    "license": {
      "type": "string",
      "description": "SPDX license identifier"
    },
    "minVoiceFlowVersion": {
      "type": "string",
      "pattern": "^\\d+\\.\\d+\\.\\d+$",
      "description": "Minimum VoiceFlow version"
    },
    "dependencies": {
      "type": "object",
      "properties": {
        "python": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Python pip packages"
        },
        "swift": {
          "type": "array",
          "items": { "type": "string", "format": "uri" },
          "description": "Swift Package Manager repository URLs"
        }
      },
      "description": "Platform-specific dependencies"
    }
  }
}
```

### Validation

**Command-line validation:**
```bash
# Using jsonschema (Python)
pip install jsonschema

python3 << 'EOF'
import json
import jsonschema

# Load schema
with open('Plugins/manifest-schema.json') as f:
    schema = json.load(f)

# Load manifest
with open('path/to/manifest.json') as f:
    manifest = json.load(f)

# Validate
try:
    jsonschema.validate(manifest, schema)
    print("✅ Manifest is valid")
except jsonschema.ValidationError as e:
    print(f"❌ Validation failed: {e.message}")
    print(f"   At: {' > '.join(str(p) for p in e.path)}")
EOF
```

**Or use the CLI toolkit:**
```bash
scripts/plugin-dev-tools.sh validate path/to/plugin
```

---

## Type Definitions

### Swift Types

```swift
// Main plugin protocol
public protocol VoiceFlowPlugin { /* See Swift API section */ }

// Manifest structure
public struct PluginManifest {
    public let id: String
    public let name: String
    public let version: String
    public let author: String
    public let description: String
    public let entrypoint: String
    public let platform: String
    public let permissions: [String]
    public let homepage: String?
    public let license: String?
    public let minVoiceFlowVersion: String?
    public let dependencies: [String: [String]]?
}

// Plugin error types
public enum PluginError: Error {
    case initializationFailed(String)
    case processingFailed(String)
    case resourceNotFound(String)
    case invalidConfiguration(String)
}

// Plugin state
public enum PluginState {
    case discovered
    case validated
    case loaded
    case active
    case disabled
    case error(Error)
}
```

### Python Types

```python
from typing import Dict, List, Optional

# Manifest type hint
ManifestDict = Dict[str, Any]

# Base plugin class
class VoiceFlowPlugin:
    manifest: ManifestDict
    plugin_id: str

    def __init__(self, manifest: ManifestDict) -> None: ...
    def on_load(self) -> None: ...
    def on_transcription(self, text: str) -> str: ...
    def on_unload(self) -> None: ...

# Optional: Custom exceptions
class PluginError(Exception):
    """Base exception for plugin errors."""
    pass

class InitializationError(PluginError):
    """Raised when plugin initialization fails."""
    pass

class ProcessingError(PluginError):
    """Raised when text processing fails."""
    pass
```

---

## Code Examples

### Example 1: Simple Text Replacement (Swift)

```swift
import Foundation

class TextReplacementPlugin: VoiceFlowPlugin {
    var pluginID: String { "com.example.textreplace" }
    var manifest: PluginManifest

    private var replacements: [String: String] = [:]

    init(manifest: PluginManifest) {
        self.manifest = manifest
    }

    func onLoad() {
        // Define replacements
        replacements = [
            "gonna": "going to",
            "wanna": "want to",
            "gotta": "got to",
            "kinda": "kind of"
        ]

        print("✅ \(manifest.name) loaded with \(replacements.count) replacements")
    }

    func onTranscription(_ text: String) -> String {
        var result = text

        for (informal, formal) in replacements {
            let pattern = "\\b\(informal)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: range,
                    withTemplate: formal
                )
            }
        }

        return result
    }

    func onUnload() {
        replacements.removeAll()
        print("👋 \(manifest.name) unloaded")
    }
}
```

### Example 2: Spell Checker (Python)

```python
import re
from typing import Set

class VoiceFlowPlugin:
    """Spell checker plugin using custom dictionary."""

    def __init__(self, manifest):
        self.manifest = manifest
        self.plugin_id = manifest['id']
        self.dictionary: Set[str] = set()
        self.corrections: dict = {}

    def on_load(self):
        """Load dictionary and common corrections."""
        # Load dictionary
        import os
        dict_path = os.path.join(os.path.dirname(__file__), 'dictionary.txt')

        try:
            with open(dict_path, 'r') as f:
                self.dictionary = set(word.strip().lower() for word in f)
        except FileNotFoundError:
            print(f"⚠️ Dictionary not found, using defaults")
            self.dictionary = set(['the', 'a', 'an', 'and', 'or', 'but'])

        # Common corrections
        self.corrections = {
            'teh': 'the',
            'recieve': 'receive',
            'seperate': 'separate',
        }

        print(f"✅ {self.manifest['name']} loaded with {len(self.dictionary)} words")

    def on_transcription(self, text: str) -> str:
        """Check and correct spelling."""
        if not text:
            return text

        words = text.split()
        corrected_words = []

        for word in words:
            # Clean word
            clean = re.sub(r'[^\w]', '', word.lower())

            # Check if correction exists
            if clean in self.corrections:
                corrected_words.append(self.corrections[clean])
            elif clean in self.dictionary or len(clean) <= 2:
                # Word is valid or too short to check
                corrected_words.append(word)
            else:
                # Unknown word, keep original
                corrected_words.append(word)

        return ' '.join(corrected_words)

    def on_unload(self):
        """Clean up resources."""
        self.dictionary.clear()
        self.corrections.clear()
        print(f"👋 {self.manifest['name']} unloaded")
```

### Example 3: Webhook Integration (Swift)

```swift
import Foundation

class WebhookPlugin: VoiceFlowPlugin {
    var pluginID: String { "com.example.webhook" }
    var manifest: PluginManifest

    private let webhookURL = URL(string: "https://webhook.site/your-unique-url")!
    private let session = URLSession.shared

    init(manifest: PluginManifest) {
        self.manifest = manifest
    }

    func onLoad() {
        print("✅ \(manifest.name) loaded")
        print("📡 Webhook URL: \(webhookURL)")
    }

    func onTranscription(_ text: String) -> String {
        // Send to webhook asynchronously
        sendToWebhook(text: text)

        // Return original text (don't modify)
        return text
    }

    private func sendToWebhook(text: String) {
        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "plugin": pluginID,
            "text": text,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            print("❌ Failed to serialize payload")
            return
        }

        request.httpBody = jsonData

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("⚠️ Webhook error: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ Webhook delivered successfully")
                } else {
                    print("⚠️ Webhook returned status \(httpResponse.statusCode)")
                }
            }
        }

        task.resume()
    }

    func onUnload() {
        session.invalidateAndCancel()
        print("👋 \(manifest.name) unloaded")
    }
}
```

### Example 4: Caching Pattern (Python)

```python
import hashlib
import json
import os
from functools import lru_cache

class VoiceFlowPlugin:
    """Plugin demonstrating caching strategies."""

    def __init__(self, manifest):
        self.manifest = manifest
        self.plugin_id = manifest['id']
        self.cache_file = os.path.join(
            os.path.dirname(__file__),
            'cache.json'
        )
        self.persistent_cache = {}

    def on_load(self):
        """Load persistent cache from disk."""
        if os.path.exists(self.cache_file):
            try:
                with open(self.cache_file, 'r') as f:
                    self.persistent_cache = json.load(f)
                print(f"✅ Loaded {len(self.persistent_cache)} cached entries")
            except Exception as e:
                print(f"⚠️ Failed to load cache: {e}")
                self.persistent_cache = {}

        print(f"✅ {self.manifest['name']} loaded")

    def on_transcription(self, text: str) -> str:
        """Process with multi-level caching."""
        if not text:
            return text

        # Level 1: In-memory LRU cache (fast)
        result = self._process_cached(text)

        # Level 2: Persistent cache (medium)
        cache_key = self._cache_key(text)
        if cache_key not in self.persistent_cache:
            self.persistent_cache[cache_key] = result

        return result

    @lru_cache(maxsize=1000)
    def _process_cached(self, text: str) -> str:
        """Process text with LRU cache decorator."""
        # Expensive processing here
        return text.upper()

    def _cache_key(self, text: str) -> str:
        """Generate cache key from text."""
        return hashlib.md5(text.encode()).hexdigest()

    def on_unload(self):
        """Save persistent cache to disk."""
        try:
            # Limit cache size
            if len(self.persistent_cache) > 10000:
                # Keep most recent 10000 entries
                items = list(self.persistent_cache.items())[-10000:]
                self.persistent_cache = dict(items)

            with open(self.cache_file, 'w') as f:
                json.dump(self.persistent_cache, f)

            print(f"💾 Saved {len(self.persistent_cache)} cache entries")
        except Exception as e:
            print(f"⚠️ Failed to save cache: {e}")

        print(f"👋 {self.manifest['name']} unloaded")
```

---

## Appendix

### Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2024 | Initial API reference release |

### Related Documentation

- **[PLUGIN_DEVELOPMENT.md](./PLUGIN_DEVELOPMENT.md)**: Getting started guide
- **[PLUGIN_TESTING.md](./PLUGIN_TESTING.md)**: Testing strategies
- **[PLUGIN_PACKAGING.md](./PLUGIN_PACKAGING.md)**: Distribution guide

### Support

For plugin development questions:
1. Check example plugins in `Plugins/Examples/`
2. Review this API reference
3. Use development tools: `scripts/plugin-dev-tools.sh`

---

**Last Updated:** 2024
**VoiceFlow Plugin API Version:** 1.0.0
