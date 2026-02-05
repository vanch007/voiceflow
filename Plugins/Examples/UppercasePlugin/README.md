# Uppercase Transform Plugin

A simple VoiceFlow plugin that transforms all transcribed text to uppercase.

## Overview

This plugin demonstrates the basic VoiceFlow plugin API by implementing a simple text transformation. It converts all transcribed text to uppercase letters, which can be useful for:

- Emphasis and clarity in transcripts
- Consistent formatting for voice commands
- Teaching purposes (demonstrates plugin basics)

## Installation

### Development
```bash
# The plugin is already in the Examples directory
# VoiceFlow will automatically discover it
```

### User Installation
```bash
# Copy to user plugins directory
cp -r Plugins/Examples/UppercasePlugin ~/Library/Application\ Support/VoiceFlow/Plugins/

# Or use the CLI tool
bash scripts/plugin-dev-tools.sh install Plugins/Examples/UppercasePlugin
```

## Configuration

This plugin requires no configuration. It works out of the box.

### Manifest
- **ID**: `dev.voiceflow.examples.uppercase`
- **Platform**: Swift
- **Permissions**: `text.read`, `text.modify`

## Usage

1. Enable the plugin in VoiceFlow settings
2. Start voice transcription
3. All transcribed text will automatically be converted to uppercase

### Example

**Input (spoken):** "hello world"
**Output (transcribed):** "HELLO WORLD"

## Technical Details

### Implementation
- **Entry Point**: `UppercasePlugin.swift`
- **Protocol**: Implements `VoiceFlowPlugin`
- **Lifecycle**: onLoad → onTranscription → onUnload

### Code Structure
```swift
class UppercasePlugin: VoiceFlowPlugin {
    func onTranscription(_ text: String) -> String {
        return text.uppercased()
    }
}
```

## Permissions

| Permission | Purpose |
|------------|---------|
| `text.read` | Read transcribed text from the ASR engine |
| `text.modify` | Modify the text before final output |

⚠️ **Note**: Permissions are informational only. VoiceFlow uses a trust-based plugin model.

## Development

### Testing
```bash
# Validate manifest
bash scripts/plugin-dev-tools.sh validate Plugins/Examples/UppercasePlugin

# Package for distribution
bash scripts/plugin-dev-tools.sh package Plugins/Examples/UppercasePlugin
```

### Customization

To create your own text transformation plugin based on this example:

1. Copy the plugin directory
2. Update the manifest.json (change ID, name, description)
3. Modify the `onTranscription()` method with your transformation logic
4. Test with the validation tool

## License

MIT License - See project root for details.

## Related Examples

- **PunctuationPlugin** (Python) - Adds smart punctuation
- **WebhookPlugin** (Swift) - Sends transcriptions to webhooks

## Support

For plugin development help, see:
- `docs/PLUGIN_DEVELOPMENT.md` - Getting started guide
- `docs/PLUGIN_API_REFERENCE.md` - Complete API reference
