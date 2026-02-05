# WebhookPlugin - HTTP Integration Example

A VoiceFlow plugin that demonstrates network integration by sending transcribed text to a configurable webhook endpoint via HTTP POST requests.

## Purpose and Use Case

This example plugin showcases how to integrate external services with VoiceFlow through HTTP webhooks. It demonstrates:

- **Network Integration**: Making HTTP POST requests from within a plugin
- **Configuration Management**: Reading custom configuration from the manifest
- **Asynchronous Operations**: Non-blocking network requests that don't interfere with transcription
- **Error Handling**: Comprehensive error handling for network failures, timeouts, and HTTP errors
- **Permission Usage**: Proper declaration and usage of the `network.http` permission

### Real-World Applications

This pattern can be adapted for:
- Logging transcriptions to external analytics platforms
- Triggering webhooks in automation tools (Zapier, IFTTT, n8n)
- Integrating with CRM systems or databases
- Sending notifications to Slack, Discord, or other messaging platforms
- Real-time data synchronization with cloud services

## Configuration

The plugin requires a webhook endpoint URL to send transcriptions to. Configuration is done through the `manifest.json` file.

### Configuration Schema

The plugin accepts the following configuration parameters:

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `webhookUrl` | string (URI) | ✅ Yes | `https://example.com/webhook` | The HTTP endpoint to send transcriptions to |
| `timeout` | number | ❌ No | `5` | Request timeout in seconds |

### Setting Up the Webhook URL

Edit the `manifest.json` file and update the configuration:

```json
{
  "configuration": {
    "defaults": {
      "webhookUrl": "https://your-server.com/voiceflow-webhook",
      "timeout": 10
    }
  }
}
```

**Important**: Replace `https://your-server.com/voiceflow-webhook` with your actual webhook endpoint URL.

## Installation

### Option 1: Development Installation

1. Copy the entire `WebhookPlugin` directory to your VoiceFlow plugins folder:
   ```bash
   cp -r Plugins/Examples/WebhookPlugin ~/Library/Application\ Support/VoiceFlow/Plugins/
   ```

2. Edit the manifest to configure your webhook URL (see Configuration section above)

3. Restart VoiceFlow to load the plugin

### Option 2: User Plugins Directory

If you've packaged this plugin for distribution:

1. Extract the plugin archive to:
   ```
   ~/Library/Application Support/VoiceFlow/Plugins/WebhookPlugin/
   ```

2. Ensure the directory contains:
   - `manifest.json`
   - `WebhookPlugin.swift`
   - `README.md` (this file)

3. Configure the webhook URL in `manifest.json`

4. Restart VoiceFlow

### Verification

After installation, check the VoiceFlow logs for:
```
[WebhookPlugin] Loaded with webhook URL: https://your-server.com/webhook, timeout: 5s
```

## Testing

### Setting Up a Test Webhook Endpoint

You can test this plugin using various webhook testing services or by creating your own endpoint.

#### Option 1: Using webhook.site (Quick Testing)

1. Visit [https://webhook.site](https://webhook.site)
2. Copy the unique URL provided (e.g., `https://webhook.site/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)
3. Update your `manifest.json`:
   ```json
   "webhookUrl": "https://webhook.site/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   ```
4. Restart VoiceFlow and speak into the microphone
5. View received requests on the webhook.site page

#### Option 2: Using RequestBin

1. Create a free account at [https://requestbin.com](https://requestbin.com)
2. Create a new bin and copy the endpoint URL
3. Configure the plugin with your RequestBin URL
4. Monitor incoming requests in real-time

#### Option 3: Local Development Server (Python)

Create a simple webhook receiver for local testing:

```python
# webhook_receiver.py
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/webhook', methods=['POST'])
def webhook():
    data = request.get_json()
    print(f"\n📥 Received webhook:")
    print(f"   Text: {data.get('text')}")
    print(f"   Timestamp: {data.get('timestamp')}")
    print(f"   Plugin ID: {data.get('plugin_id')}")
    print(f"   Version: {data.get('plugin_version')}\n")
    return jsonify({"status": "success"}), 200

if __name__ == '__main__':
    app.run(port=8080, debug=True)
```

Run the server:
```bash
pip install flask
python webhook_receiver.py
```

Configure the plugin:
```json
"webhookUrl": "http://localhost:8080/webhook"
```

## Webhook Payload

The plugin sends the following JSON payload via HTTP POST:

```json
{
  "text": "The transcribed text from VoiceFlow",
  "timestamp": "2024-02-05T13:45:30Z",
  "plugin_id": "dev.voiceflow.examples.webhook",
  "plugin_version": "1.0.0"
}
```

### Payload Fields

| Field | Type | Description |
|-------|------|-------------|
| `text` | string | The transcribed text from the voice input |
| `timestamp` | string | ISO 8601 formatted timestamp (UTC) of when the transcription occurred |
| `plugin_id` | string | The unique identifier of this plugin |
| `plugin_version` | string | The version of the plugin (from manifest) |

### HTTP Headers

The plugin sends the following headers with each request:

- `Content-Type: application/json`
- `User-Agent: VoiceFlow-WebhookPlugin/1.0`

## Error Handling

The plugin includes comprehensive error handling for various network scenarios:

### Network Errors

| Error Type | Log Message | Description |
|------------|-------------|-------------|
| **Timeout** | `Request timed out after Xs` | The webhook didn't respond within the configured timeout period |
| **Connection Failed** | `Cannot connect to webhook host` | Unable to establish connection to the webhook server |
| **No Internet** | `No internet connection` | Device is offline or has no network connectivity |
| **General Network Error** | `Network request failed - [error details]` | Other network-related errors (DNS, SSL, etc.) |

### HTTP Status Code Handling

| Status Range | Behavior | Log Level |
|--------------|----------|-----------|
| **2xx (Success)** | Request succeeded | ✅ Info - Logs response body (first 200 chars) |
| **4xx (Client Error)** | Client-side error (bad request, unauthorized, etc.) | ⚠️ Warning - Logs error details |
| **5xx (Server Error)** | Server-side error | ⚠️ Warning - Logs status code |
| **Other** | Unexpected status code | ⚠️ Warning |

### Configuration Errors

If the webhook URL is invalid or missing:
```
[WebhookPlugin] Warning: Invalid or missing webhook URL in configuration
[WebhookPlugin] Error: Cannot send to webhook - invalid URL
```

### Error Recovery

**All errors are non-fatal** - the plugin will:
1. Log the error with detailed information
2. Return the original transcribed text unchanged
3. Continue processing future transcriptions

This ensures that network issues don't break the transcription pipeline.

## Monitoring and Debugging

### Checking Plugin Status

View VoiceFlow console logs to monitor plugin activity:

**Successful Request:**
```
[WebhookPlugin] Sent transcription to webhook: Hello world
[WebhookPlugin] Success: Webhook responded with status 200
[WebhookPlugin] Response body: {"status":"success"}
```

**Failed Request:**
```
[WebhookPlugin] Sent transcription to webhook: Hello world
[WebhookPlugin] Error: Request timed out after 5s
```

### Troubleshooting

| Issue | Possible Cause | Solution |
|-------|----------------|----------|
| No logs appearing | Plugin not loaded | Check VoiceFlow plugins directory and restart app |
| "Invalid webhook URL" | Malformed URL in config | Verify URL format in `manifest.json` (must start with `http://` or `https://`) |
| Timeout errors | Webhook server slow/down | Increase timeout in config or check webhook server |
| Connection failed | Firewall/network blocking | Check firewall settings, try a public webhook testing service |
| 4xx errors | Webhook expects different format | Check webhook server requirements and modify payload if needed |

## Performance Considerations

- **Non-blocking**: Webhook requests are asynchronous and don't delay transcription processing
- **Timeout Protection**: Configurable timeout prevents hung requests from accumulating
- **Resource Cleanup**: URLSession is properly invalidated on plugin unload
- **Logging Overhead**: Response bodies are truncated to 200 characters in logs

## Security Notes

⚠️ **Important Security Considerations:**

1. **No Sandbox**: Plugins run with full system permissions - only use trusted webhook endpoints
2. **HTTPS Recommended**: Use HTTPS URLs to encrypt data in transit
3. **Sensitive Data**: Be aware that transcribed text may contain sensitive information
4. **Credential Management**: If your webhook requires authentication, consider using environment variables or secure configuration
5. **Permission Declaration**: This plugin declares `network.http` permission - this is informational only and not enforced

## Permissions

This plugin requires the following permissions (declared in `manifest.json`):

- `text.read` - To read transcribed text
- `network.http` - To make HTTP requests to external endpoints

**Note**: VoiceFlow's permission system is currently informational and trust-based. Permissions are not enforced at runtime.

## Customization Ideas

You can extend this plugin for your specific needs:

### Adding Authentication

```swift
// In onLoad(), read API key from configuration
let apiKey = config["apiKey"] as? String

// In onTranscription(), add authorization header
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
```

### Adding Custom Headers

```swift
// Add custom headers to the request
request.setValue("your-value", forHTTPHeaderField: "X-Custom-Header")
```

### Modifying the Payload

```swift
// Add additional fields to the payload
let payload: [String: Any] = [
    "text": text,
    "timestamp": ISO8601DateFormatter().string(from: Date()),
    "plugin_id": pluginID,
    "plugin_version": manifest.version,
    "device_id": "your-device-id",  // Add custom fields
    "user_id": "your-user-id"
]
```

### Filtering Transcriptions

```swift
// Only send non-empty transcriptions
guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
    return text
}
```

## Technical Details

- **Language**: Swift 6.0
- **Platform**: macOS 14.0+
- **Dependencies**: None (uses Foundation framework only)
- **Entrypoint**: `WebhookPlugin.swift`
- **Plugin Protocol**: Implements `VoiceFlowPlugin` from VoiceFlow SDK

## License

MIT License - See the main VoiceFlow project for details

## Support

For issues or questions:
- Review the main [Plugin Development Guide](../../docs/PLUGIN_DEVELOPMENT.md)
- Check the [Plugin API Reference](../../docs/PLUGIN_API_REFERENCE.md)
- Consult the [Plugin Testing Guide](../../docs/PLUGIN_TESTING.md)

## Version History

### 1.0.0 (Initial Release)
- HTTP POST webhook integration
- Configurable endpoint URL and timeout
- Comprehensive error handling
- ISO 8601 timestamp formatting
- Detailed logging for debugging
