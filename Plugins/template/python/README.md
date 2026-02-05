# Python Plugin Template

This is a template for creating VoiceFlow plugins in Python. Use this as a starting point for your custom plugin development.

## Quick Start

### 1. Customize the Manifest

Edit `manifest.json` and replace the placeholder values:

```json
{
  "id": "com.yourcompany.your-plugin-name",  // Change this to your unique ID
  "name": "Your Plugin Name",                 // Human-readable name
  "version": "1.0.0",                         // Your plugin version
  "author": "Your Name",                      // Replace YOUR_NAME
  "description": "What your plugin does",     // Describe your plugin
  "homepage": "https://github.com/..."        // Your project URL
}
```

**Important**: The `id` field must be unique. Use reverse domain notation (e.g., `com.example.myplugin`).

### 2. Customize the Plugin Code

Edit `plugin_template.py`:

1. **Update the docstring** at the top:
   ```python
   """
   Your Plugin Name - What it does
   """
   ```

2. **Update the plugin_id reference** (optional - automatically set from manifest):
   ```python
   # The plugin_id is automatically set from manifest['id']
   # No changes needed unless you want to override it
   ```

3. **Implement your logic** in the `on_transcription()` method:
   ```python
   def on_transcription(self, text: str) -> str:
       # Your custom logic here
       modified_text = text.upper()  # Example
       return modified_text
   ```

4. **Update log messages** to use meaningful descriptions:
   ```python
   self.logger.info("Your descriptive message here")
   ```

### 3. Rename the File (Optional)

If you want to rename the plugin file, also update the `entrypoint` in `manifest.json`:

```bash
mv plugin_template.py your_plugin_name.py
```

Then update `manifest.json`:
```json
{
  "entrypoint": "your_plugin_name.py"
}
```

### 4. Configure Permissions

Update the `permissions` array in `manifest.json` based on what your plugin needs:

```json
{
  "permissions": [
    "text.read",      // Read transcribed text
    "text.modify",    // Modify transcribed text
    "network.http",   // Make HTTP requests
    "filesystem.read" // Read files
  ]
}
```

**Available permissions:**
- `text.read` - Read transcribed text
- `text.modify` - Modify transcribed text
- `network.http` - Make HTTP requests
- `network.websocket` - Use WebSocket connections
- `filesystem.read` - Read files from disk
- `filesystem.write` - Write files to disk
- `clipboard.read` - Read from clipboard
- `clipboard.write` - Write to clipboard
- `system.notifications` - Show system notifications

**Note**: Permissions are informational only and not enforced by the runtime. Always review plugin source code before installation.

### 5. Add Configuration Options (Optional)

If your plugin needs user-configurable settings, edit the `configuration` section in `manifest.json`:

```json
{
  "configuration": {
    "schema": {
      "type": "object",
      "properties": {
        "yourSetting": {
          "type": "string",
          "description": "Description of this setting"
        }
      },
      "required": ["yourSetting"]
    },
    "defaults": {
      "yourSetting": "default value"
    }
  }
}
```

Then read the configuration in your Python code:

```python
def on_load(self):
    config = self.manifest.get('configuration', {}).get('defaults', {})
    your_setting = config.get('yourSetting', 'fallback value')
    self.logger.info(f"Setting: {your_setting}")
```

### 6. Add Dependencies (Optional)

If your plugin requires external Python packages, add them to `requirements.txt`:

```
requests>=2.31.0
nltk>=3.8.0
beautifulsoup4>=4.12.0
```

Then install them:
```bash
pip install -r requirements.txt
```

## Plugin Lifecycle

Your plugin has three lifecycle methods:

### on_load()
Called once when the plugin is loaded. Use this to:
- Read configuration values
- Initialize resources
- Set up network connections
- Load ML models
- Validate settings

```python
def on_load(self):
    # Initialize your plugin
    config = self.manifest.get('configuration', {}).get('defaults', {})
    self.my_setting = config.get('mySetting', 'default')
    self.logger.info("Plugin loaded")
```

### on_transcription(text: str) -> str
Called every time VoiceFlow transcribes speech. Use this to:
- Process or modify transcribed text
- Send data to external services
- Trigger actions based on speech content

**Important**: Return the text you want VoiceFlow to use (modified or original).

```python
def on_transcription(self, text: str) -> str:
    # Process the text
    processed = text.upper()
    return processed
```

### on_unload()
Called when the plugin is unloaded. Use this to:
- Close network connections
- Save state to disk
- Cancel pending operations
- Clean up resources

```python
def on_unload(self):
    # Clean up
    self.logger.info("Plugin unloaded")
```

## Installation

1. Copy your plugin directory to the VoiceFlow plugins folder:
   ```bash
   cp -r your-plugin-directory ~/Library/Application\ Support/VoiceFlow/Plugins/
   ```

2. Restart VoiceFlow

3. Enable your plugin in VoiceFlow settings

4. Check the logs to verify your plugin loaded successfully:
   ```
   Plugin loaded with exampleSetting: ...
   ```

## Testing

### Basic Testing

1. Launch VoiceFlow with the ASR server running
2. Enable your plugin in settings
3. Speak into the microphone
4. Check the console logs for your plugin's output
5. Verify the transcribed text is processed correctly

### Debugging Tips

- Use `self.logger.info()`, `self.logger.debug()`, and `self.logger.error()` for logging
- Check the ASR server logs for Python plugin output
- Test with simple inputs first
- Verify your manifest.json is valid JSON
- Ensure your plugin_id matches between manifest and code (automatically handled)
- Use try-except blocks to catch and log errors

## Examples

### Example 1: Simple Text Transform

```python
def on_transcription(self, text: str) -> str:
    return text.upper()
```

### Example 2: Prefix Addition

```python
def on_transcription(self, text: str) -> str:
    return f"You said: {text}"
```

### Example 3: Conditional Processing

```python
def on_transcription(self, text: str) -> str:
    if "urgent" in text.lower():
        return f"⚠️ {text}"
    return text
```

### Example 4: Using Configuration

```python
def __init__(self, manifest: dict):
    super().__init__(manifest)
    self.prefix = ""

def on_load(self):
    config = self.manifest.get('configuration', {}).get('defaults', {})
    self.prefix = config.get('prefix', '')

def on_transcription(self, text: str) -> str:
    return f"{self.prefix}{text}"
```

### Example 5: Word Replacement

```python
def __init__(self, manifest: dict):
    super().__init__(manifest)
    self.replacements = {}

def on_load(self):
    config = self.manifest.get('configuration', {}).get('defaults', {})
    self.replacements = config.get('replacements', {})

def on_transcription(self, text: str) -> str:
    for old, new in self.replacements.items():
        text = text.replace(old, new)
    return text
```

## Advanced Topics

### Error Handling

Always handle errors gracefully to avoid crashing the ASR server:

```python
def on_transcription(self, text: str) -> str:
    try:
        # Your code that might raise exceptions
        result = self.process_text(text)
        return result
    except Exception as e:
        self.logger.error(f"Error processing text: {e}")
        return text  # Return original text on error
```

### Network Requests

Example using the `requests` library:

```python
import requests

def on_transcription(self, text: str) -> str:
    try:
        response = requests.post(
            'https://api.example.com/endpoint',
            json={'text': text},
            timeout=5
        )
        response.raise_for_status()
        self.logger.info(f"Request successful: {response.status_code}")
    except requests.RequestException as e:
        self.logger.error(f"Network error: {e}")

    return text
```

### File Operations

```python
import json
from pathlib import Path

def on_load(self):
    # Read configuration from file
    config_path = Path.home() / '.voiceflow' / 'my-plugin-config.json'
    if config_path.exists():
        with open(config_path) as f:
            self.config = json.load(f)

def on_unload(self):
    # Save state to file
    state_path = Path.home() / '.voiceflow' / 'my-plugin-state.json'
    state_path.parent.mkdir(parents=True, exist_ok=True)
    with open(state_path, 'w') as f:
        json.dump(self.state, f)
```

### Async Operations

Python plugins support async methods for non-blocking operations:

```python
import asyncio
import aiohttp

async def on_transcription(self, text: str) -> str:
    try:
        async with aiohttp.ClientSession() as session:
            async with session.post(
                'https://api.example.com/endpoint',
                json={'text': text}
            ) as response:
                result = await response.json()
                self.logger.info(f"Async request completed: {result}")
    except Exception as e:
        self.logger.error(f"Async error: {e}")

    return text
```

## Resources

- [Plugin Development Guide](../../docs/PLUGIN_DEVELOPMENT.md)
- [Plugin API Reference](../../docs/PLUGIN_API_REFERENCE.md)
- [Plugin Testing Guide](../../docs/PLUGIN_TESTING.md)
- [WebhookPlugin Example](../Examples/WebhookPlugin/)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Plugin not loading | Check manifest.json is valid, verify id is unique |
| No output in logs | Add logger statements to verify plugin is being called |
| Import errors | Check requirements.txt dependencies are installed |
| Configuration not working | Verify schema matches your config structure |
| Async methods not working | Ensure ASR server supports async plugin execution |

## License

MIT License - Feel free to use this template for any purpose.

## Next Steps

1. ✅ Customize manifest.json with your plugin details
2. ✅ Implement your plugin logic in on_transcription()
3. ✅ Add any dependencies to requirements.txt
4. ✅ Test your plugin thoroughly
5. ✅ Add error handling
6. ✅ Document your plugin's features
7. ✅ Share your plugin with the community!

Happy coding! 🚀
