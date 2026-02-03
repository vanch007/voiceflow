# VoiceFlow Plugin System

⚠️ **CRITICAL SECURITY WARNING**

**VoiceFlow plugins run with FULL APPLICATION PRIVILEGES and have UNRESTRICTED access to your system.**

- ❌ **NO SANDBOXING**: Plugins can access any file, execute any code, make any network request
- ❌ **NO PERMISSION ENFORCEMENT**: Manifest permissions are informational only, NOT enforced
- ⚠️ **TRUST-BASED MODEL**: Only install plugins from sources you completely trust

**Before installing ANY plugin:**
1. ✅ Review the source code if available
2. ✅ Verify the author is trustworthy
3. ✅ Check what permissions are requested
4. ✅ Understand that plugins can do ANYTHING your user account can do

See `.auto-claude/specs/019-/SECURITY_VERIFICATION.md` for complete security analysis.

---

This directory contains the plugin system documentation and schema for VoiceFlow.

## Overview

VoiceFlow supports a plugin architecture that allows developers to extend the application with custom functionality. Plugins can process transcribed text, integrate with external services, and add new features to VoiceFlow.

## Plugin Manifest

Every plugin must include a `manifest.json` file that describes the plugin's metadata, requirements, and capabilities.

### Manifest Schema

The manifest follows the JSON schema defined in `manifest-schema.json`. All plugin manifests are validated against this schema during loading.

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier (reverse domain notation recommended, e.g., `com.example.my-plugin`) |
| `name` | string | Human-readable plugin name |
| `version` | string | Plugin version (semantic versioning recommended, e.g., `1.0.0`) |
| `author` | string | Plugin author name or organization |
| `description` | string | Brief description of plugin functionality (10-500 characters) |
| `entrypoint` | string | Entry point file relative to plugin directory |
| `platform` | string | Target platform: `swift`, `python`, or `both` |

### Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `permissions` | array | List of required permissions (see Permissions section) |
| `minVoiceFlowVersion` | string | Minimum VoiceFlow version required |
| `maxVoiceFlowVersion` | string | Maximum VoiceFlow version supported |
| `homepage` | string | Plugin homepage or repository URL |
| `license` | string | Plugin license (SPDX identifier recommended) |
| `dependencies` | object | Plugin dependencies (Swift packages or Python packages) |
| `configuration` | object | Plugin configuration schema and defaults |

### Example Manifest

```json
{
  "id": "com.example.uppercase-plugin",
  "name": "Uppercase Transform",
  "version": "1.0.0",
  "author": "John Doe",
  "description": "Transforms transcribed text to uppercase for emphasis",
  "entrypoint": "UppercasePlugin.swift",
  "permissions": [
    "text.read",
    "text.modify"
  ],
  "platform": "swift",
  "minVoiceFlowVersion": "1.0.0",
  "homepage": "https://github.com/example/uppercase-plugin",
  "license": "MIT"
}
```

## Platform Support

VoiceFlow plugins can be written in two languages:

### Swift Plugins

- Target platform: `swift`
- Used for macOS-native integrations
- Must implement the `VoiceFlowPlugin` protocol defined in `VoiceFlow/Sources/Core/PluginAPI.swift`
- Loaded dynamically via `Bundle.load()`
- Entrypoint should be a `.swift` file

### Python Plugins

- Target platform: `python`
- Used for text processing and ML integrations
- Must inherit from the `VoiceFlowPlugin` base class defined in `server/plugin_api.py`
- Loaded via `importlib` dynamic module loading
- Entrypoint should be a `.py` file

### Cross-Platform Plugins

- Target platform: `both`
- Provide both Swift and Python implementations
- Useful for plugins that need to run on both the macOS app and ASR server
- Must provide separate entrypoints for each platform

## Permissions Model

Plugins must declare required permissions in their manifest. The following permissions are supported:

| Permission | Description |
|------------|-------------|
| `text.read` | Read transcribed text |
| `text.modify` | Modify transcribed text before injection |
| `network.http` | Make HTTP/HTTPS requests |
| `network.websocket` | Establish WebSocket connections |
| `filesystem.read` | Read files from disk (sandboxed) |
| `filesystem.write` | Write files to disk (sandboxed) |
| `clipboard.read` | Read from system clipboard |
| `clipboard.write` | Write to system clipboard |
| `system.notifications` | Display system notifications |

**Note:** Plugins run in a sandboxed environment. File system access is restricted to the plugin's own directory and VoiceFlow's designated plugin data directory.

## Plugin Lifecycle

Plugins go through the following lifecycle:

1. **Discovery** - VoiceFlow scans the plugins directory for valid `manifest.json` files
2. **Validation** - Manifests are validated against the schema
3. **Loading** - Plugin code is loaded into memory
4. **Initialization** - `onLoad()` hook is called
5. **Active** - Plugin processes text via `onTranscription()` hook
6. **Shutdown** - `onUnload()` hook is called when plugin is disabled or app exits

## Plugin Installation

Plugins should be installed to:

**macOS:**
```
~/Library/Application Support/VoiceFlow/Plugins/
```

Each plugin should be in its own directory with the following structure:

```
~/Library/Application Support/VoiceFlow/Plugins/
└── my-plugin/
    ├── manifest.json
    ├── PluginCode.swift  (or plugin.py)
    └── ... (additional files)
```

## Development

For detailed plugin development guides, see:

- `docs/PLUGIN_DEVELOPMENT.md` - Getting started with plugin development
- `docs/PLUGIN_API_REFERENCE.md` - Complete API reference

For example plugins, see:

- `Plugins/Examples/UppercasePlugin/` - Swift example
- `Plugins/Examples/PunctuationPlugin/` - Python example

## Validation

To validate your plugin manifest against the schema, you can use any JSON Schema validator:

```bash
# Using ajv-cli (Node.js)
npm install -g ajv-cli
ajv validate -s manifest-schema.json -d path/to/your/manifest.json

# Using jsonschema (Python)
pip install jsonschema
python -c "import json, jsonschema; \
  schema = json.load(open('manifest-schema.json')); \
  manifest = json.load(open('path/to/your/manifest.json')); \
  jsonschema.validate(manifest, schema); \
  print('Valid!')"
```

## Security Considerations

⚠️ **IMPORTANT: The following security boundaries are ASPIRATIONAL and NOT currently implemented:**

**Current Reality (as of security verification):**
- ❌ Plugins DO NOT run with limited permissions - they have FULL access
- ❌ Network access does NOT require explicit permission - it's unrestricted
- ❌ File system access is NOT sandboxed - plugins can access ANY file
- ❌ Plugins CAN access ALL system resources without restriction
- ✅ Malicious or misbehaving plugins CAN be disabled via the UI
- ✅ ALWAYS review plugin source code and permissions before installation

**Security Model:** Trust-based, no sandboxing or isolation

**See full security analysis:** `.auto-claude/specs/019-/SECURITY_VERIFICATION.md`

## Support

For questions, issues, or feature requests related to the plugin system:

1. Check the documentation in `docs/`
2. Review example plugins in `Plugins/Examples/`
3. Open an issue on the VoiceFlow repository

## License

The VoiceFlow plugin system and this documentation are part of the VoiceFlow project.
Individual plugins may have their own licenses as specified in their manifests.
