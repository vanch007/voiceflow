# VoiceFlow Plugin API Reference

Complete technical reference for the VoiceFlow Plugin API, covering both Swift and Python implementations.

---

## Table of Contents

- [Overview](#overview)
- [Swift Plugin API](#swift-plugin-api)
  - [VoiceFlowPlugin Protocol](#voiceflowplugin-protocol)
  - [PluginManifest](#pluginmanifest)
  - [PluginPlatform](#pluginplatform)
  - [PluginError](#pluginerror)
  - [PluginState](#pluginstate)
  - [PluginInfo](#plugininfo)
- [Python Plugin API](#python-plugin-api)
  - [VoiceFlowPlugin Class](#voiceflowplugin-class)
  - [PluginManifest Dataclass](#pluginmanifest-dataclass)
  - [PluginPlatform Enum](#pluginplatform-enum)
  - [Error Classes](#error-classes)
  - [PluginState Enum](#pluginstate-enum)
  - [PluginInfo Dataclass](#plugininfo-dataclass)
- [Manifest Schema](#manifest-schema)
- [Permissions Reference](#permissions-reference)
- [Lifecycle Hooks](#lifecycle-hooks)
- [Error Handling](#error-handling)
- [Best Practices](#best-practices)

---

## Overview

The VoiceFlow Plugin API provides a standardized interface for extending VoiceFlow with custom functionality. Plugins can be written in Swift (for macOS-native integrations) or Python (for text processing and ML tasks).

### Core Concepts

- **Plugin**: A self-contained module that extends VoiceFlow functionality
- **Manifest**: JSON file describing plugin metadata and requirements
- **Lifecycle Hooks**: Methods called at specific points in the plugin's lifecycle
- **Permissions**: Declared capabilities required by the plugin
- **Platform**: Target runtime environment (Swift, Python, or both)

---

## Swift Plugin API

Swift plugins run in the macOS VoiceFlow app process and have access to native macOS APIs.

### VoiceFlowPlugin Protocol

All Swift plugins must implement the `VoiceFlowPlugin` protocol.

```swift
protocol VoiceFlowPlugin: AnyObject {
    var pluginID: String { get }
    var manifest: PluginManifest { get }
    func onLoad()
    func onTranscription(_ text: String) -> String
    func onUnload()
}
```

#### Properties

##### `pluginID`

```swift
var pluginID: String { get }
```

**Description:** Unique identifier for the plugin instance.

**Returns:** String matching the `id` field in the plugin's manifest.

**Usage:**
```swift
var pluginID: String {
    return manifest.id
}
```

##### `manifest`

```swift
var manifest: PluginManifest { get }
```

**Description:** Plugin metadata and configuration.

**Returns:** `PluginManifest` struct containing plugin information.

**Usage:**
```swift
var manifest: PluginManifest {
    return PluginManifest(
        id: "com.example.myplugin",
        name: "My Plugin",
        version: "1.0.0",
        author: "Your Name",
        description: "Plugin description",
        entrypoint: "MyPlugin.bundle",
        permissions: ["text.read", "text.modify"],
        platform: .swift
    )
}
```

#### Methods

##### `onLoad()`

```swift
func onLoad()
```

**Description:** Called when the plugin is loaded and enabled.

**Parameters:** None

**Returns:** Void

**When Called:**
- When the plugin is first discovered and enabled
- When VoiceFlow starts with the plugin already enabled

**Use Cases:**
- Initialize resources
- Load configuration
- Establish connections
- Set up internal state

**Example:**
```swift
func onLoad() {
    NSLog("[MyPlugin] Plugin loaded")
    // Initialize resources
    self.config = loadConfiguration()
    self.cache = Dictionary<String, String>()
}
```

##### `onTranscription(_:)`

```swift
func onTranscription(_ text: String) -> String
```

**Description:** Called when transcription text is available for processing.

**Parameters:**
- `text`: The transcribed text from the ASR system or previous plugin in the chain

**Returns:** Processed text (can be the same as input if no transformation needed)

**When Called:**
- After the ASR engine completes transcription
- Before the text is injected into the active application
- For each enabled plugin in sequence

**Use Cases:**
- Transform text (case conversion, formatting)
- Add punctuation or grammar corrections
- Filter or replace content
- Analyze text and apply conditional transformations

**Example:**
```swift
func onTranscription(_ text: String) -> String {
    let transformed = text.uppercased()
    NSLog("[MyPlugin] Transformed: '\(text)' -> '\(transformed)'")
    return transformed
}
```

**Important Notes:**
- Must return quickly (< 100ms recommended)
- Returning empty string will result in no text injection
- Exceptions should be caught and logged; return original text on error

##### `onUnload()`

```swift
func onUnload()
```

**Description:** Called when the plugin is disabled or unloaded.

**Parameters:** None

**Returns:** Void

**When Called:**
- When the plugin is disabled via the UI
- When VoiceFlow exits
- When the plugin is being reloaded

**Use Cases:**
- Clean up resources
- Close connections
- Save state
- Flush caches

**Example:**
```swift
func onUnload() {
    NSLog("[MyPlugin] Plugin unloading")
    // Clean up resources
    self.cache?.removeAll()
    self.config = nil
}
```

---

### PluginManifest

```swift
struct PluginManifest: Codable {
    let id: String
    let name: String
    let version: String
    let author: String
    let description: String
    let entrypoint: String
    let permissions: [String]
    let platform: PluginPlatform
}
```

**Description:** Immutable struct containing plugin metadata.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | Unique plugin identifier (reverse domain notation) |
| `name` | `String` | Human-readable plugin name |
| `version` | `String` | Semantic version string (e.g., "1.0.0") |
| `author` | `String` | Plugin author or organization |
| `description` | `String` | Brief description of functionality |
| `entrypoint` | `String` | Entry point file (e.g., "MyPlugin.bundle") |
| `permissions` | `[String]` | Array of required permissions |
| `platform` | `PluginPlatform` | Target platform |

**Conformance:**
- `Codable`: Can be encoded/decoded from JSON

---

### PluginPlatform

```swift
enum PluginPlatform: String, Codable {
    case swift
    case python
    case both
}
```

**Description:** Enumeration of supported plugin platforms.

**Cases:**

| Case | Raw Value | Description |
|------|-----------|-------------|
| `swift` | `"swift"` | Swift-only plugin |
| `python` | `"python"` | Python-only plugin |
| `both` | `"both"` | Cross-platform plugin |

---

### PluginError

```swift
enum PluginError: Error {
    case loadFailed(String)
    case manifestInvalid(String)
    case permissionDenied(String)
    case executionFailed(String)
}
```

**Description:** Errors that can occur during plugin operations.

**Cases:**

##### `loadFailed(String)`

**When Thrown:** Plugin bundle cannot be loaded or principal class not found

**Message:** Description of the loading failure

**Example:**
```swift
throw PluginError.loadFailed("Bundle not found at path: \(bundlePath)")
```

##### `manifestInvalid(String)`

**When Thrown:** Manifest JSON is malformed or missing required fields

**Message:** Description of validation failure

**Example:**
```swift
throw PluginError.manifestInvalid("Missing required field: id")
```

##### `permissionDenied(String)`

**When Thrown:** Plugin attempts operation without required permission

**Message:** Description of permission violation

**Example:**
```swift
throw PluginError.permissionDenied("network.http permission required")
```

##### `executionFailed(String)`

**When Thrown:** Plugin code throws an exception during execution

**Message:** Description of execution failure

**Example:**
```swift
throw PluginError.executionFailed("Failed to process text: \(error)")
```

---

### PluginState

```swift
enum PluginState {
    case loaded
    case enabled
    case disabled
    case failed(Error)
}
```

**Description:** Current state of a plugin in its lifecycle.

**Cases:**

| State | Description |
|-------|-------------|
| `loaded` | Plugin discovered and manifest loaded, but not active |
| `enabled` | Plugin loaded and actively processing text |
| `disabled` | Plugin loaded but not processing text |
| `failed(Error)` | Plugin failed to load or execute; contains error details |

---

### PluginInfo

```swift
final class PluginInfo {
    let manifest: PluginManifest
    var state: PluginState
    var plugin: VoiceFlowPlugin?

    var isEnabled: Bool {
        if case .enabled = state {
            return true
        }
        return false
    }

    init(manifest: PluginManifest, state: PluginState = .loaded)
}
```

**Description:** Runtime information about a loaded plugin.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `manifest` | `PluginManifest` | Plugin metadata (immutable) |
| `state` | `PluginState` | Current plugin state (mutable) |
| `plugin` | `VoiceFlowPlugin?` | Plugin instance (nil if not loaded) |
| `isEnabled` | `Bool` | Computed property: true if state is `.enabled` |

---

## Python Plugin API

Python plugins run in the ASR server process and have access to Python's extensive ecosystem.

### VoiceFlowPlugin Class

All Python plugins must inherit from the `VoiceFlowPlugin` abstract base class.

```python
from abc import ABC, abstractmethod

class VoiceFlowPlugin(ABC):
    def __init__(self, manifest: PluginManifest)

    @property
    def plugin_id(self) -> str

    @property
    def manifest(self) -> PluginManifest

    @abstractmethod
    async def on_load(self) -> None

    @abstractmethod
    async def on_transcription(self, text: str) -> str

    @abstractmethod
    async def on_unload(self) -> None
```

#### Constructor

##### `__init__(manifest)`

```python
def __init__(self, manifest: PluginManifest)
```

**Description:** Initialize the plugin with its manifest.

**Parameters:**
- `manifest` (`PluginManifest`): Plugin metadata and configuration

**Example:**
```python
def __init__(self, manifest: PluginManifest):
    super().__init__(manifest)
    self._enabled = False
    self._config = {}
```

#### Properties

##### `plugin_id`

```python
@property
def plugin_id(self) -> str
```

**Description:** Unique identifier for the plugin.

**Returns:** String matching the `id` field in the manifest.

**Example:**
```python
@property
def plugin_id(self) -> str:
    return self._plugin_id
```

##### `manifest`

```python
@property
def manifest(self) -> PluginManifest
```

**Description:** Plugin metadata and configuration.

**Returns:** `PluginManifest` dataclass instance.

**Example:**
```python
@property
def manifest(self) -> PluginManifest:
    return self._manifest
```

#### Methods

##### `on_load()`

```python
@abstractmethod
async def on_load(self) -> None
```

**Description:** Async hook called when the plugin is loaded and enabled.

**Parameters:** None

**Returns:** None

**Raises:** `PluginError` if initialization fails

**When Called:**
- When the plugin is first discovered and enabled
- When the ASR server starts with the plugin already enabled

**Use Cases:**
- Initialize async resources
- Load configuration files
- Establish network connections
- Set up ML models

**Example:**
```python
async def on_load(self) -> None:
    logger.info(f"[{self.plugin_id}] Loading plugin")
    self._enabled = True
    # Initialize async resources
    self._client = await self._init_http_client()
    logger.info(f"[{self.plugin_id}] Plugin loaded successfully")
```

**Important Notes:**
- Must be declared with `async def`
- Should complete quickly (< 5 seconds recommended)
- Use `logger` for debugging output
- Raise `PluginError` if initialization fails

##### `on_transcription(text)`

```python
@abstractmethod
async def on_transcription(self, text: str) -> str
```

**Description:** Async hook called when transcription text is available.

**Parameters:**
- `text` (`str`): The transcribed text from the ASR system or previous plugin

**Returns:** Processed text as a string

**Raises:** `PluginError` if text processing fails

**When Called:**
- After the ASR engine completes transcription
- Before the text is sent to the macOS app
- For each enabled plugin in sequence

**Use Cases:**
- Transform text (punctuation, capitalization)
- Apply NLP processing
- Translate text
- Filter or sanitize content

**Example:**
```python
async def on_transcription(self, text: str) -> str:
    if not self._enabled:
        return text

    try:
        processed = text.strip()
        # Apply transformations
        processed = self._add_punctuation(processed)
        logger.debug(f"[{self.plugin_id}] '{text}' -> '{processed}'")
        return processed
    except Exception as e:
        error_msg = f"Failed to process text: {str(e)}"
        logger.error(f"[{self.plugin_id}] {error_msg}")
        raise PluginError(error_msg) from e
```

**Important Notes:**
- Must be declared with `async def`
- Should complete quickly (< 100ms recommended)
- Return original text if processing fails (with logging)
- Can use `await` for async operations

##### `on_unload()`

```python
@abstractmethod
async def on_unload(self) -> None
```

**Description:** Async hook called when the plugin is disabled or unloaded.

**Parameters:** None

**Returns:** None

**Raises:** `PluginError` if cleanup fails

**When Called:**
- When the plugin is disabled via the UI
- When the ASR server exits
- When the plugin is being reloaded

**Use Cases:**
- Close async connections
- Clean up resources
- Save state to disk
- Flush caches

**Example:**
```python
async def on_unload(self) -> None:
    logger.info(f"[{self.plugin_id}] Unloading plugin")
    self._enabled = False
    # Clean up async resources
    if self._client:
        await self._client.close()
    logger.info(f"[{self.plugin_id}] Plugin unloaded successfully")
```

---

### PluginManifest Dataclass

```python
from dataclasses import dataclass

@dataclass
class PluginManifest:
    id: str
    name: str
    version: str
    author: str
    description: str
    entrypoint: str
    permissions: list[str]
    platform: PluginPlatform

    @classmethod
    def from_dict(cls, data: dict) -> "PluginManifest"
```

**Description:** Immutable dataclass containing plugin metadata.

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | `str` | Unique plugin identifier |
| `name` | `str` | Human-readable plugin name |
| `version` | `str` | Semantic version string |
| `author` | `str` | Plugin author or organization |
| `description` | `str` | Brief description of functionality |
| `entrypoint` | `str` | Entry point file (e.g., "plugin.py") |
| `permissions` | `list[str]` | List of required permissions |
| `platform` | `PluginPlatform` | Target platform enum |

#### Class Methods

##### `from_dict(data)`

```python
@classmethod
def from_dict(cls, data: dict) -> "PluginManifest"
```

**Description:** Create manifest from dictionary (loaded from JSON).

**Parameters:**
- `data` (`dict`): Dictionary containing manifest fields

**Returns:** `PluginManifest` instance

**Example:**
```python
import json

with open("manifest.json") as f:
    manifest_data = json.load(f)
    manifest = PluginManifest.from_dict(manifest_data)
```

---

### PluginPlatform Enum

```python
from enum import Enum

class PluginPlatform(str, Enum):
    SWIFT = "swift"
    PYTHON = "python"
    BOTH = "both"
```

**Description:** Enumeration of supported plugin platforms.

**Values:**

| Value | String | Description |
|-------|--------|-------------|
| `SWIFT` | `"swift"` | Swift-only plugin |
| `PYTHON` | `"python"` | Python-only plugin |
| `BOTH` | `"both"` | Cross-platform plugin |

---

### Error Classes

Python plugins use a hierarchy of exception classes.

#### Base Exception

```python
class PluginError(Exception):
    """Base exception for plugin-related errors."""
    pass
```

#### Derived Exceptions

##### `LoadFailedError`

```python
class LoadFailedError(PluginError):
    """Raised when plugin loading fails."""
    pass
```

**When Raised:** Plugin module cannot be imported or instantiated

**Example:**
```python
raise LoadFailedError(f"Failed to import plugin module: {e}")
```

##### `ManifestInvalidError`

```python
class ManifestInvalidError(PluginError):
    """Raised when plugin manifest is invalid."""
    pass
```

**When Raised:** Manifest JSON is malformed or missing required fields

**Example:**
```python
raise ManifestInvalidError("Missing required field: id")
```

##### `PermissionDeniedError`

```python
class PermissionDeniedError(PluginError):
    """Raised when plugin lacks required permissions."""
    pass
```

**When Raised:** Plugin attempts operation without declared permission

**Example:**
```python
if "network.http" not in self.manifest.permissions:
    raise PermissionDeniedError("network.http permission required")
```

##### `ExecutionFailedError`

```python
class ExecutionFailedError(PluginError):
    """Raised when plugin execution fails."""
    pass
```

**When Raised:** Plugin code raises an exception during execution

**Example:**
```python
raise ExecutionFailedError(f"Text processing failed: {e}")
```

---

### PluginState Enum

```python
from enum import Enum

class PluginState(str, Enum):
    LOADED = "loaded"
    ENABLED = "enabled"
    DISABLED = "disabled"
    FAILED = "failed"
```

**Description:** Current state of a plugin in its lifecycle.

**Values:**

| State | String | Description |
|-------|--------|-------------|
| `LOADED` | `"loaded"` | Plugin discovered, not active |
| `ENABLED` | `"enabled"` | Plugin actively processing text |
| `DISABLED` | `"disabled"` | Plugin loaded but inactive |
| `FAILED` | `"failed"` | Plugin failed to load or execute |

---

### PluginInfo Dataclass

```python
from dataclasses import dataclass
from typing import Optional

@dataclass
class PluginInfo:
    manifest: PluginManifest
    state: PluginState = PluginState.LOADED
    plugin: Optional["VoiceFlowPlugin"] = None
    error: Optional[Exception] = None

    @property
    def is_enabled(self) -> bool
```

**Description:** Runtime information about a loaded plugin.

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `manifest` | `PluginManifest` | Plugin metadata |
| `state` | `PluginState` | Current plugin state (default: LOADED) |
| `plugin` | `VoiceFlowPlugin \| None` | Plugin instance (None if not loaded) |
| `error` | `Exception \| None` | Error details if state is FAILED |

#### Properties

##### `is_enabled`

```python
@property
def is_enabled(self) -> bool
```

**Description:** Check if plugin is currently enabled.

**Returns:** True if state is `ENABLED`, False otherwise

---

## Manifest Schema

Complete schema for plugin `manifest.json` files.

### Required Fields

```json
{
  "id": "string",
  "name": "string",
  "version": "string",
  "author": "string",
  "description": "string",
  "entrypoint": "string",
  "platform": "swift" | "python" | "both"
}
```

#### Field Specifications

##### `id`

- **Type:** `string`
- **Pattern:** `^[a-z0-9.-]+$`
- **Length:** 3-100 characters
- **Description:** Unique identifier (reverse domain notation recommended)
- **Examples:** `"com.example.my-plugin"`, `"dev.voiceflow.uppercase"`

##### `name`

- **Type:** `string`
- **Length:** 1-100 characters
- **Description:** Human-readable plugin name
- **Examples:** `"Uppercase Transform"`, `"Smart Punctuation"`

##### `version`

- **Type:** `string`
- **Pattern:** `^\d+\.\d+\.\d+(-[a-zA-Z0-9.-]+)?$`
- **Description:** Semantic version
- **Examples:** `"1.0.0"`, `"2.1.3-beta"`

##### `author`

- **Type:** `string`
- **Length:** 1-100 characters
- **Description:** Plugin author name or organization
- **Examples:** `"John Doe"`, `"Acme Corporation"`

##### `description`

- **Type:** `string`
- **Length:** 10-500 characters
- **Description:** Brief description of plugin functionality
- **Example:** `"Transforms transcribed text to uppercase for emphasis"`

##### `entrypoint`

- **Type:** `string`
- **Length:** 1-255 characters
- **Description:** Entry point file relative to plugin directory
- **Examples:** `"UppercasePlugin.swift"`, `"plugin.py"`, `"src/main.swift"`

##### `platform`

- **Type:** `string`
- **Enum:** `"swift"`, `"python"`, `"both"`
- **Description:** Target platform for the plugin

### Optional Fields

#### `permissions`

```json
{
  "permissions": [
    "text.read",
    "text.modify"
  ]
}
```

- **Type:** `array` of `string`
- **Default:** `[]`
- **Items:** Must be valid permission identifiers (see Permissions Reference)
- **Unique:** No duplicate permissions allowed

#### `minVoiceFlowVersion`

```json
{
  "minVoiceFlowVersion": "1.0.0"
}
```

- **Type:** `string`
- **Pattern:** `^\d+\.\d+\.\d+$`
- **Description:** Minimum VoiceFlow version required

#### `maxVoiceFlowVersion`

```json
{
  "maxVoiceFlowVersion": "3.0.0"
}
```

- **Type:** `string`
- **Pattern:** `^\d+\.\d+\.\d+$`
- **Description:** Maximum VoiceFlow version supported

#### `homepage`

```json
{
  "homepage": "https://github.com/user/plugin"
}
```

- **Type:** `string`
- **Format:** URI
- **Description:** Plugin homepage or repository URL

#### `license`

```json
{
  "license": "MIT"
}
```

- **Type:** `string`
- **Description:** Plugin license (SPDX identifier recommended)
- **Examples:** `"MIT"`, `"Apache-2.0"`, `"GPL-3.0"`

#### `dependencies`

```json
{
  "dependencies": {
    "swift": [
      {
        "name": "Alamofire",
        "url": "https://github.com/Alamofire/Alamofire.git",
        "version": "5.6.0"
      }
    ],
    "python": [
      "requests>=2.28.0",
      "numpy>=1.24.0"
    ]
  }
}
```

- **Type:** `object`
- **Properties:**
  - `swift`: Array of Swift package dependency objects
  - `python`: Array of Python package requirement strings (pip format)

#### `configuration`

```json
{
  "configuration": {
    "schema": {
      "type": "object",
      "properties": {
        "apiKey": {
          "type": "string"
        }
      }
    },
    "defaults": {
      "apiKey": ""
    }
  }
}
```

- **Type:** `object`
- **Properties:**
  - `schema`: JSON Schema for plugin settings
  - `defaults`: Default configuration values

---

## Permissions Reference

Complete list of supported permissions and their capabilities.

### Text Permissions

#### `text.read`

- **Description:** Read transcribed text from the ASR system
- **Required For:** Receiving text in `onTranscription()` hook
- **Security Impact:** Low - read-only access to user's voice input
- **Recommended:** All text processing plugins

#### `text.modify`

- **Description:** Modify transcribed text before injection
- **Required For:** Returning modified text from `onTranscription()`
- **Security Impact:** Medium - can alter user's intended text
- **Recommended:** Transformation, formatting, and correction plugins

### Network Permissions

#### `network.http`

- **Description:** Make HTTP/HTTPS requests
- **Required For:** API calls, web services, data fetching
- **Security Impact:** High - can send data to external services
- **Use Cases:** Translation APIs, cloud NLP, external validation

#### `network.websocket`

- **Description:** Establish WebSocket connections
- **Required For:** Real-time bidirectional communication
- **Security Impact:** High - persistent connections to external services
- **Use Cases:** Real-time collaboration, streaming services

### File System Permissions

#### `filesystem.read`

- **Description:** Read files from disk (sandboxed to plugin directory)
- **Required For:** Loading configuration, reading data files
- **Security Impact:** Low - restricted to plugin directory
- **Use Cases:** Configuration files, custom dictionaries, ML models

#### `filesystem.write`

- **Description:** Write files to disk (sandboxed to plugin directory)
- **Required For:** Saving state, caching data, logging
- **Security Impact:** Medium - can persist data on disk
- **Use Cases:** Caching, user preferences, offline data

### Clipboard Permissions

#### `clipboard.read`

- **Description:** Read from system clipboard
- **Required For:** Accessing clipboard content
- **Security Impact:** Medium - can access copied data
- **Use Cases:** Context-aware processing, clipboard integration

#### `clipboard.write`

- **Description:** Write to system clipboard
- **Required For:** Copying processed text to clipboard
- **Security Impact:** Medium - can overwrite clipboard content
- **Use Cases:** Alternative text injection methods

### System Permissions

#### `system.notifications`

- **Description:** Display system notifications
- **Required For:** User notifications, alerts
- **Security Impact:** Low - visual notifications only
- **Use Cases:** Status updates, error alerts, completion notifications

---

## Lifecycle Hooks

Detailed sequence of plugin lifecycle events.

### Plugin Discovery

1. **Scan Directory:** VoiceFlow scans `~/Library/Application Support/VoiceFlow/Plugins/`
2. **Find Manifests:** Looks for `manifest.json` files in subdirectories
3. **Validate Schema:** Validates each manifest against `manifest-schema.json`
4. **Create PluginInfo:** Creates `PluginInfo` instance with state `LOADED`

### Plugin Loading

#### Swift Plugins

```
1. PluginLoader.load() called
2. Bundle.load() loads the .bundle
3. Principal class instantiated
4. VoiceFlowPlugin protocol verified
5. Plugin stored in PluginInfo
6. State changed to LOADED
```

#### Python Plugins

```
1. PluginLoader.load_plugin() called
2. importlib.util.spec_from_file_location() locates module
3. Module loaded dynamically
4. VoiceFlowPlugin subclass instantiated
5. Plugin stored in PluginInfo
6. State changed to LOADED
```

### Plugin Activation

```
1. User enables plugin via UI
2. PluginManager.enablePlugin() called
3. Plugin.onLoad() / on_load() executed
4. If successful: state -> ENABLED
5. If failed: state -> FAILED(error)
```

### Text Processing

```
1. ASR engine completes transcription
2. PluginManager.processText() called
3. For each ENABLED plugin in order:
   a. Plugin.onTranscription() / on_transcription() called
   b. Text replaced with returned value
   c. Continue to next plugin
4. Final text sent to TextInjector
```

### Plugin Deactivation

```
1. User disables plugin via UI
2. PluginManager.disablePlugin() called
3. Plugin.onUnload() / on_unload() executed
4. State changed to DISABLED
5. Plugin instance retained in memory
```

### Plugin Unloading

```
1. App exits or plugin removed
2. Plugin.onUnload() / on_unload() executed
3. Plugin instance released
4. PluginInfo removed from registry
```

---

## Error Handling

Best practices for handling errors in plugins.

### Swift Error Handling

```swift
func onTranscription(_ text: String) -> String {
    do {
        // Attempt processing
        let result = try processText(text)
        return result
    } catch {
        // Log error
        NSLog("[MyPlugin] Error processing text: \(error)")

        // Return original text on error
        return text
    }
}
```

**Key Points:**
- Use `do-catch` for error-prone operations
- Log errors with `NSLog()` for debugging
- Return original text on processing failure
- Don't throw errors from lifecycle hooks (catch internally)

### Python Error Handling

```python
async def on_transcription(self, text: str) -> str:
    try:
        # Attempt processing
        result = await self._process_text(text)
        return result
    except Exception as e:
        # Log error
        logger.error(f"[{self.plugin_id}] Error: {e}", exc_info=True)

        # Return original text on error
        return text
```

**Key Points:**
- Use `try-except` for error-prone operations
- Log errors with `logger.error()` and `exc_info=True`
- Return original text on processing failure
- Can raise `PluginError` from hooks to signal failure to manager

### Error Recovery

**Transient Errors:**
- Network timeouts: Implement retry logic with exponential backoff
- Resource temporarily unavailable: Return original text, log warning

**Permanent Errors:**
- Missing configuration: Disable plugin, notify user
- Invalid state: Reset plugin state in `onLoad()`

**Critical Errors:**
- Unrecoverable failure: Raise error from `on_load()` to prevent enabling
- Memory exhaustion: Clean up in `onUnload()`, prevent future loads

---

## Best Practices

### Performance

1. **Fast Processing:**
   - Target < 100ms for `onTranscription()` / `on_transcription()`
   - Use async operations in Python plugins
   - Cache frequently used data

2. **Resource Management:**
   - Initialize heavy resources in `onLoad()` / `on_load()`
   - Clean up resources in `onUnload()` / `on_unload()`
   - Use connection pooling for network requests

3. **Memory Efficiency:**
   - Avoid large in-memory caches
   - Stream large files instead of loading entirely
   - Release unused resources promptly

### Security

1. **Least Privilege:**
   - Request minimum required permissions
   - Validate all input data
   - Sanitize output before returning

2. **Data Privacy:**
   - Don't log sensitive user text
   - Encrypt stored credentials
   - Use HTTPS for all network requests

3. **Error Messages:**
   - Don't expose sensitive information in errors
   - Log detailed errors internally
   - Show user-friendly messages externally

### Code Quality

1. **Type Safety:**
   - Use type hints in Python
   - Avoid force unwrapping in Swift
   - Validate data at boundaries

2. **Testing:**
   - Write unit tests for text processing logic
   - Test error handling paths
   - Verify lifecycle hook behavior

3. **Documentation:**
   - Document public API methods
   - Include usage examples
   - Maintain a changelog

### User Experience

1. **Feedback:**
   - Log successful operations at debug level
   - Log failures at error level
   - Use notifications for important events

2. **Configuration:**
   - Provide sensible defaults
   - Validate configuration on load
   - Document all settings

3. **Compatibility:**
   - Test with multiple VoiceFlow versions
   - Handle API changes gracefully
   - Deprecate features gradually

---

## Appendix

### File Locations

**Plugin Directory:**
```
~/Library/Application Support/VoiceFlow/Plugins/
```

**Plugin Structure:**
```
~/Library/Application Support/VoiceFlow/Plugins/
└── my-plugin/
    ├── manifest.json           # Required
    ├── plugin.py               # Python entrypoint
    ├── MyPlugin.swift          # Swift entrypoint
    ├── requirements.txt        # Python dependencies (optional)
    └── README.md               # Documentation (optional)
```

### Related Documentation

- **Getting Started:** `PLUGIN_DEVELOPMENT.md`
- **Manifest Schema:** `Plugins/manifest-schema.json`
- **Manifest Documentation:** `Plugins/README.md`
- **Example Plugins:** `Plugins/Examples/`

### Version History

- **v1.0.0** (2024): Initial plugin system release
  - Swift and Python plugin support
  - Core lifecycle hooks
  - Permission system
  - Example plugins

---

**API Version:** 1.0.0
**Last Updated:** 2024-02-03
**Maintainer:** VoiceFlow Development Team
