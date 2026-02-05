# Swift Plugin Template

This is a template for creating VoiceFlow plugins in Swift. Use this as a starting point for your custom plugin development.

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

Edit `PluginTemplate.swift`:

1. **Update the class name** (optional but recommended):
   ```swift
   class YourPluginName: VoiceFlowPlugin {
   ```

2. **Update the pluginID** to match your manifest:
   ```swift
   var pluginID: String { "com.yourcompany.your-plugin-name" }
   ```

3. **Implement your logic** in the `onTranscription()` method:
   ```swift
   func onTranscription(_ text: String) -> String {
       // Your custom logic here
       let modifiedText = text.uppercased()  // Example
       return modifiedText
   }
   ```

4. **Update log messages** to use your plugin name:
   ```swift
   NSLog("[YourPluginName] Your message here")
   ```

### 3. Rename the File (Optional)

If you renamed the class, also rename the file to match:

```bash
mv PluginTemplate.swift YourPluginName.swift
```

Then update the `entrypoint` in `manifest.json`:
```json
{
  "entrypoint": "YourPluginName.swift"
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

Then read the configuration in your Swift code:

```swift
func onLoad() {
    if let config = manifest.configuration {
        let yourSetting = config["yourSetting"] as? String
        NSLog("[YourPlugin] Setting: \(yourSetting ?? "none")")
    }
}
```

## Plugin Lifecycle

Your plugin has three lifecycle methods:

### onLoad()
Called once when the plugin is loaded. Use this to:
- Read configuration values
- Initialize resources
- Set up network connections
- Validate settings

```swift
func onLoad() {
    // Initialize your plugin
    NSLog("[YourPlugin] Plugin loaded")
}
```

### onTranscription(_ text: String) -> String
Called every time VoiceFlow transcribes speech. Use this to:
- Process or modify transcribed text
- Send data to external services
- Trigger actions based on speech content

**Important**: Return the text you want VoiceFlow to use (modified or original).

```swift
func onTranscription(_ text: String) -> String {
    // Process the text
    let processed = text.uppercased()
    return processed
}
```

### onUnload()
Called when the plugin is unloaded. Use this to:
- Close network connections
- Save state to disk
- Cancel pending operations
- Clean up resources

```swift
func onUnload() {
    // Clean up
    NSLog("[YourPlugin] Plugin unloaded")
}
```

## Installation

1. Copy your plugin directory to the VoiceFlow plugins folder:
   ```bash
   cp -r your-plugin-directory ~/Library/Application\ Support/VoiceFlow/Plugins/
   ```

2. Restart VoiceFlow

3. Check the logs to verify your plugin loaded successfully:
   ```
   [YourPlugin] Plugin loaded
   ```

## Testing

### Basic Testing

1. Launch VoiceFlow
2. Speak into the microphone
3. Check the console logs for your plugin's output
4. Verify the transcribed text is processed correctly

### Debugging Tips

- Use `NSLog()` to output debug information
- Check VoiceFlow's console for error messages
- Test with simple inputs first
- Verify your manifest.json is valid JSON
- Ensure your pluginID matches between manifest and code

## Examples

### Example 1: Simple Text Transform

```swift
func onTranscription(_ text: String) -> String {
    return text.uppercased()
}
```

### Example 2: Prefix Addition

```swift
func onTranscription(_ text: String) -> String {
    return "You said: \(text)"
}
```

### Example 3: Conditional Processing

```swift
func onTranscription(_ text: String) -> String {
    if text.lowercased().contains("urgent") {
        return "⚠️ \(text)"
    }
    return text
}
```

### Example 4: Using Configuration

```swift
private var prefix: String = ""

func onLoad() {
    if let config = manifest.configuration {
        prefix = config["prefix"] as? String ?? ""
    }
}

func onTranscription(_ text: String) -> String {
    return "\(prefix)\(text)"
}
```

## Advanced Topics

### Error Handling

Always handle errors gracefully to avoid crashing VoiceFlow:

```swift
func onTranscription(_ text: String) -> String {
    do {
        // Your code that might throw
        let result = try processText(text)
        return result
    } catch {
        NSLog("[YourPlugin] Error: \(error.localizedDescription)")
        return text  // Return original text on error
    }
}
```

### Network Requests

See the WebhookPlugin example for HTTP networking:

```swift
let url = URL(string: "https://api.example.com/endpoint")!
var request = URLRequest(url: url)
request.httpMethod = "POST"

let task = URLSession.shared.dataTask(with: request) { data, response, error in
    // Handle response
}
task.resume()
```

### File Operations

```swift
let fileURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("my-plugin-data.json")

// Write
try? JSONEncoder().encode(myData).write(to: fileURL)

// Read
if let data = try? Data(contentsOf: fileURL) {
    let myData = try? JSONDecoder().decode(MyDataType.self, from: data)
}
```

## Resources

- [Plugin Development Guide](../../docs/PLUGIN_DEVELOPMENT.md)
- [Plugin API Reference](../../docs/PLUGIN_API_REFERENCE.md)
- [Plugin Testing Guide](../../docs/PLUGIN_TESTING.md)
- [WebhookPlugin Example](../Examples/WebhookPlugin/)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Plugin not loading | Check manifest.json is valid, verify pluginID matches |
| No output in logs | Add NSLog statements to verify plugin is being called |
| Compilation errors | Ensure Swift syntax is correct, check imports |
| Configuration not working | Verify schema matches your config structure |

## License

MIT License - Feel free to use this template for any purpose.

## Next Steps

1. ✅ Customize manifest.json with your plugin details
2. ✅ Implement your plugin logic in onTranscription()
3. ✅ Test your plugin thoroughly
4. ✅ Add error handling
5. ✅ Document your plugin's features
6. ✅ Share your plugin with the community!

Happy coding! 🚀
