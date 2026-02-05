import Foundation

/// Example plugin demonstrating HTTP webhook integration
/// Sends transcribed text to a configurable webhook endpoint via HTTP POST
class WebhookPlugin: VoiceFlowPlugin {
    var pluginID: String { "dev.voiceflow.examples.webhook" }
    var manifest: PluginManifest

    private var webhookUrl: String?
    private var timeout: TimeInterval = 5.0
    private let session: URLSession

    init(manifest: PluginManifest) {
        self.manifest = manifest

        // Configure URLSession with timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        self.session = URLSession(configuration: config)
    }

    func onLoad() {
        // Extract configuration from manifest
        if let config = manifest.configuration {
            webhookUrl = config["webhookUrl"] as? String
            if let timeoutValue = config["timeout"] as? TimeInterval {
                timeout = timeoutValue
            }
        }

        // Validate webhook URL
        guard let urlString = webhookUrl, let url = URL(string: urlString) else {
            NSLog("[WebhookPlugin] Warning: Invalid or missing webhook URL in configuration")
            return
        }

        NSLog("[WebhookPlugin] Loaded with webhook URL: \(url.absoluteString), timeout: \(timeout)s")
    }

    func onTranscription(_ text: String) -> String {
        // Send transcription to webhook asynchronously (non-blocking)
        guard let urlString = webhookUrl, let url = URL(string: urlString) else {
            NSLog("[WebhookPlugin] Error: Cannot send to webhook - invalid URL")
            return text
        }

        // Prepare HTTP POST request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("VoiceFlow-WebhookPlugin/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout

        // Create JSON payload
        let payload: [String: Any] = [
            "text": text,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "plugin_id": pluginID,
            "plugin_version": manifest.version
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            NSLog("[WebhookPlugin] Error: Failed to serialize JSON payload - \(error.localizedDescription)")
            return text
        }

        // Send request asynchronously
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            self?.handleWebhookResponse(data: data, response: response, error: error, originalText: text)
        }

        task.resume()
        NSLog("[WebhookPlugin] Sent transcription to webhook: \(text.prefix(50))\(text.count > 50 ? "..." : "")")

        // Return original text unchanged (this plugin doesn't modify transcriptions)
        return text
    }

    func onUnload() {
        // Clean up resources
        session.invalidateAndCancel()
        NSLog("[WebhookPlugin] Unloaded and cleaned up network session")
    }

    // MARK: - Private Helper Methods

    private func handleWebhookResponse(data: Data?, response: URLResponse?, error: Error?, originalText: String) {
        // Handle network errors
        if let error = error {
            let errorType = (error as NSError).domain
            let errorCode = (error as NSError).code

            if errorCode == NSURLErrorTimedOut {
                NSLog("[WebhookPlugin] Error: Request timed out after \(timeout)s")
            } else if errorCode == NSURLErrorCannotConnectToHost {
                NSLog("[WebhookPlugin] Error: Cannot connect to webhook host")
            } else if errorCode == NSURLErrorNotConnectedToInternet {
                NSLog("[WebhookPlugin] Error: No internet connection")
            } else {
                NSLog("[WebhookPlugin] Error: Network request failed - \(error.localizedDescription) [\(errorType):\(errorCode)]")
            }
            return
        }

        // Handle HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            NSLog("[WebhookPlugin] Error: Invalid response type")
            return
        }

        let statusCode = httpResponse.statusCode

        // Log response based on status code
        if (200...299).contains(statusCode) {
            // Success
            NSLog("[WebhookPlugin] Success: Webhook responded with status \(statusCode)")

            // Optionally log response body for debugging
            if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                let preview = responseBody.prefix(200)
                NSLog("[WebhookPlugin] Response body: \(preview)\(responseBody.count > 200 ? "..." : "")")
            }
        } else if (400...499).contains(statusCode) {
            // Client error
            NSLog("[WebhookPlugin] Warning: Webhook rejected request with status \(statusCode) (client error)")
            if let data = data, let errorBody = String(data: data, encoding: .utf8) {
                NSLog("[WebhookPlugin] Error details: \(errorBody.prefix(200))")
            }
        } else if (500...599).contains(statusCode) {
            // Server error
            NSLog("[WebhookPlugin] Warning: Webhook server error with status \(statusCode)")
        } else {
            // Unexpected status code
            NSLog("[WebhookPlugin] Warning: Unexpected status code \(statusCode)")
        }
    }
}
