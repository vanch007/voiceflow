# VoiceFlow Plugin Testing Guide

**Version:** 1.0.0
**Last Updated:** 2024

---

## Table of Contents

1. [Overview](#overview)
2. [Testing Philosophy](#testing-philosophy)
3. [Swift Plugin Testing](#swift-plugin-testing)
4. [Python Plugin Testing](#python-plugin-testing)
5. [Mock Frameworks](#mock-frameworks)
6. [Testing Lifecycle Methods](#testing-lifecycle-methods)
7. [Manifest Validation Testing](#manifest-validation-testing)
8. [Debugging Test Failures](#debugging-test-failures)
9. [Continuous Integration](#continuous-integration)
10. [Best Practices](#best-practices)

---

## Overview

Testing is crucial for building reliable VoiceFlow plugins. This guide covers:

- **Unit Testing**: Test individual plugin methods in isolation
- **Integration Testing**: Test plugin behavior within VoiceFlow
- **Validation Testing**: Verify manifest correctness
- **Performance Testing**: Ensure plugins meet performance requirements

### Testing Goals

- ✅ Verify plugin logic correctness
- ✅ Catch regressions before deployment
- ✅ Document expected behavior
- ✅ Ensure compatibility with VoiceFlow API
- ✅ Validate manifest schema compliance

---

## Testing Philosophy

### Test Pyramid

```
         ┌─────────────┐
         │   Manual    │  ← Integration testing with VoiceFlow
         │   Testing   │
         ├─────────────┤
         │ Integration │  ← Test plugin with mock VoiceFlow
         │    Tests    │
         ├─────────────┤
         │    Unit     │  ← Test individual methods
         │    Tests    │  ← Most tests should be here
         └─────────────┘
```

### What to Test

**DO Test:**
- Text transformation logic
- Edge cases (empty input, very long text, special characters)
- Error handling and recovery
- Resource initialization and cleanup
- Performance characteristics

**DON'T Test:**
- VoiceFlow's plugin loading mechanism
- Third-party library internals
- Platform-specific functionality (unless critical)

---

## Swift Plugin Testing

### Setting Up XCTest

Swift plugins use **XCTest**, Apple's native testing framework.

#### Project Structure

```
MyPlugin/
├── Sources/
│   └── plugin.swift           # Plugin implementation
├── Tests/
│   └── MyPluginTests.swift    # Test suite
├── Package.swift              # Swift Package Manager config
└── manifest.json
```

#### Package.swift Configuration

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MyPlugin", targets: ["MyPlugin"])
    ],
    targets: [
        .target(name: "MyPlugin", path: "Sources"),
        .testTarget(
            name: "MyPluginTests",
            dependencies: ["MyPlugin"],
            path: "Tests"
        )
    ]
)
```

### Basic XCTest Example

```swift
import XCTest
@testable import MyPlugin

final class MyPluginTests: XCTestCase {
    var plugin: MyPlugin!
    var mockManifest: PluginManifest!

    override func setUp() {
        super.setUp()

        // Create mock manifest
        mockManifest = PluginManifest(
            id: "com.example.test",
            name: "Test Plugin",
            version: "1.0.0",
            author: "Test Author",
            description: "Test plugin for unit testing",
            entrypoint: "plugin.swift",
            platform: "swift",
            permissions: ["text.read", "text.modify"],
            homepage: nil,
            license: "MIT",
            minVoiceFlowVersion: nil,
            dependencies: nil
        )

        // Initialize plugin
        plugin = MyPlugin(manifest: mockManifest)
    }

    override func tearDown() {
        plugin = nil
        mockManifest = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testPluginInitialization() {
        XCTAssertNotNil(plugin, "Plugin should initialize successfully")
        XCTAssertEqual(plugin.pluginID, "com.example.test")
        XCTAssertEqual(plugin.manifest.name, "Test Plugin")
    }

    // MARK: - onLoad Tests

    func testOnLoad() {
        XCTAssertNoThrow(plugin.onLoad(), "onLoad should not throw")
        // Add assertions for initialized state
    }

    // MARK: - onTranscription Tests

    func testBasicTranscription() {
        plugin.onLoad()

        let input = "hello world"
        let output = plugin.onTranscription(input)

        XCTAssertEqual(output, "HELLO WORLD", "Should convert to uppercase")
    }

    func testEmptyInput() {
        plugin.onLoad()

        let input = ""
        let output = plugin.onTranscription(input)

        XCTAssertEqual(output, "", "Should handle empty string")
    }

    func testLongInput() {
        plugin.onLoad()

        let input = String(repeating: "test ", count: 1000)
        let output = plugin.onTranscription(input)

        XCTAssertFalse(output.isEmpty, "Should handle long input")
    }

    func testSpecialCharacters() {
        plugin.onLoad()

        let input = "hello! @#$ 世界 🌍"
        let output = plugin.onTranscription(input)

        XCTAssertNotNil(output, "Should handle special characters")
    }

    // MARK: - onUnload Tests

    func testOnUnload() {
        plugin.onLoad()
        XCTAssertNoThrow(plugin.onUnload(), "onUnload should not throw")
    }

    func testUnloadWithoutLoad() {
        // Test defensive programming
        XCTAssertNoThrow(plugin.onUnload(), "Should handle unload without load")
    }

    // MARK: - Performance Tests

    func testTranscriptionPerformance() {
        plugin.onLoad()

        measure {
            _ = plugin.onTranscription("test input text")
        }
    }

    func testLargeTextPerformance() {
        plugin.onLoad()
        let largeText = String(repeating: "word ", count: 10000)

        measure {
            _ = plugin.onTranscription(largeText)
        }
    }
}
```

### Running Swift Tests

```bash
# Run all tests
swift test

# Run specific test
swift test --filter MyPluginTests.testBasicTranscription

# Run with verbose output
swift test --verbose

# Generate code coverage
swift test --enable-code-coverage
```

### Advanced XCTest Patterns

#### Testing Async Operations

```swift
func testAsyncOperation() async throws {
    plugin.onLoad()

    let expectation = XCTestExpectation(description: "Async operation completes")

    Task {
        let result = await plugin.processAsync("test")
        XCTAssertNotNil(result)
        expectation.fulfill()
    }

    await fulfillment(of: [expectation], timeout: 5.0)
}
```

#### Testing Error Handling

```swift
func testErrorRecovery() {
    plugin.onLoad()

    // Test that plugin returns original text on error
    let invalidInput = String(bytes: [0xFF, 0xFE], encoding: .utf8) ?? ""
    let output = plugin.onTranscription(invalidInput)

    // Should not crash, should return safe value
    XCTAssertNotNil(output, "Should handle invalid input gracefully")
}
```

---

## Python Plugin Testing

### Setting Up pytest

Python plugins use **pytest**, the most popular Python testing framework.

#### Installation

```bash
# Install pytest
pip install pytest pytest-cov pytest-mock

# Or add to requirements-dev.txt
echo "pytest>=7.4.0" >> requirements-dev.txt
echo "pytest-cov>=4.1.0" >> requirements-dev.txt
echo "pytest-mock>=3.11.0" >> requirements-dev.txt
pip install -r requirements-dev.txt
```

#### Project Structure

```
MyPythonPlugin/
├── plugin.py                  # Plugin implementation
├── tests/
│   ├── __init__.py
│   ├── test_plugin.py         # Test suite
│   └── conftest.py            # Shared fixtures
├── manifest.json
└── requirements.txt
```

### Basic pytest Example

```python
# tests/test_plugin.py
import pytest
import json
from plugin import VoiceFlowPlugin


@pytest.fixture
def mock_manifest():
    """Create a mock manifest for testing."""
    return {
        'id': 'com.example.test',
        'name': 'Test Plugin',
        'version': '1.0.0',
        'author': 'Test Author',
        'description': 'Test plugin for unit testing',
        'entrypoint': 'plugin.py',
        'platform': 'python',
        'permissions': ['text.read', 'text.modify']
    }


@pytest.fixture
def plugin(mock_manifest):
    """Create a plugin instance for testing."""
    p = VoiceFlowPlugin(mock_manifest)
    p.on_load()
    yield p
    p.on_unload()


class TestPluginInitialization:
    """Test plugin initialization."""

    def test_init_with_manifest(self, mock_manifest):
        """Test plugin initializes with manifest."""
        plugin = VoiceFlowPlugin(mock_manifest)

        assert plugin.manifest == mock_manifest
        assert plugin.plugin_id == 'com.example.test'

    def test_init_stores_metadata(self, plugin):
        """Test plugin stores manifest metadata."""
        assert plugin.manifest['name'] == 'Test Plugin'
        assert plugin.manifest['version'] == '1.0.0'


class TestOnLoad:
    """Test on_load lifecycle method."""

    def test_on_load_succeeds(self, mock_manifest):
        """Test on_load executes without errors."""
        plugin = VoiceFlowPlugin(mock_manifest)

        # Should not raise
        plugin.on_load()

    def test_on_load_initializes_resources(self, plugin):
        """Test on_load initializes plugin resources."""
        # Check that resources were initialized
        # Example: assert hasattr(plugin, 'cache')
        pass


class TestOnTranscription:
    """Test on_transcription text processing."""

    def test_basic_transcription(self, plugin):
        """Test basic text transformation."""
        input_text = "hello world"
        output = plugin.on_transcription(input_text)

        assert output == "HELLO WORLD"

    def test_empty_input(self, plugin):
        """Test handling of empty input."""
        output = plugin.on_transcription("")

        assert output == ""

    def test_none_input(self, plugin):
        """Test handling of None input."""
        # Depending on implementation, might return "" or None
        output = plugin.on_transcription(None)

        assert output is not None or output == ""

    def test_whitespace_only(self, plugin):
        """Test handling of whitespace-only input."""
        output = plugin.on_transcription("   \t\n  ")

        # Should preserve or normalize whitespace
        assert isinstance(output, str)

    def test_long_text(self, plugin):
        """Test handling of very long input."""
        long_text = "word " * 10000
        output = plugin.on_transcription(long_text)

        assert len(output) > 0

    def test_special_characters(self, plugin):
        """Test handling of special characters."""
        special_text = "Hello! @#$%^&*() 世界 🌍"
        output = plugin.on_transcription(special_text)

        assert isinstance(output, str)

    def test_unicode_text(self, plugin):
        """Test handling of Unicode text."""
        unicode_text = "Привет мир 你好世界 مرحبا بالعالم"
        output = plugin.on_transcription(unicode_text)

        assert isinstance(output, str)

    def test_multiline_text(self, plugin):
        """Test handling of multiline text."""
        multiline = "line one\nline two\nline three"
        output = plugin.on_transcription(multiline)

        assert isinstance(output, str)

    @pytest.mark.parametrize("input_text,expected", [
        ("hello", "HELLO"),
        ("world", "WORLD"),
        ("test", "TEST"),
    ])
    def test_parametrized_cases(self, plugin, input_text, expected):
        """Test multiple cases with parametrization."""
        assert plugin.on_transcription(input_text) == expected


class TestOnUnload:
    """Test on_unload lifecycle method."""

    def test_on_unload_succeeds(self, plugin):
        """Test on_unload executes without errors."""
        # Should not raise
        plugin.on_unload()

    def test_on_unload_cleans_resources(self, mock_manifest):
        """Test on_unload properly cleans up resources."""
        plugin = VoiceFlowPlugin(mock_manifest)
        plugin.on_load()
        plugin.on_unload()

        # Check that resources were cleaned up
        # Example: assert plugin.cache == {}


class TestErrorHandling:
    """Test error handling and recovery."""

    def test_handles_processing_error(self, plugin, monkeypatch):
        """Test plugin handles processing errors gracefully."""
        def mock_process_error(text):
            raise ValueError("Simulated error")

        # Mock internal method to raise error
        monkeypatch.setattr(plugin, '_process_text', mock_process_error)

        # Should not raise, should return original text
        output = plugin.on_transcription("test")
        assert output == "test"

    def test_invalid_encoding(self, plugin):
        """Test handling of invalid text encoding."""
        # Most cases are handled at Python string level
        # But test any custom encoding logic
        pass


class TestPerformance:
    """Test performance characteristics."""

    def test_transcription_performance(self, plugin, benchmark):
        """Test transcription performance with pytest-benchmark."""
        text = "test input text"

        result = benchmark(plugin.on_transcription, text)
        assert result is not None

    def test_large_text_performance(self, plugin):
        """Test performance with large text."""
        import time

        large_text = "word " * 10000
        start = time.time()

        plugin.on_transcription(large_text)

        elapsed = time.time() - start
        assert elapsed < 0.1, "Should process in under 100ms"
```

### Running pytest

```bash
# Run all tests
pytest

# Run specific test file
pytest tests/test_plugin.py

# Run specific test
pytest tests/test_plugin.py::TestOnTranscription::test_basic_transcription

# Run with verbose output
pytest -v

# Run with coverage
pytest --cov=plugin --cov-report=html

# Run with output capture disabled (see print statements)
pytest -s

# Run only failed tests from last run
pytest --lf

# Run tests matching pattern
pytest -k "test_empty or test_none"
```

### Advanced pytest Patterns

#### Fixtures with Cleanup

```python
# tests/conftest.py
import pytest
import tempfile
import os

@pytest.fixture
def temp_plugin_dir():
    """Create temporary directory for plugin testing."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield tmpdir
    # Automatic cleanup after yield

@pytest.fixture
def plugin_with_config(mock_manifest, temp_plugin_dir):
    """Create plugin with test configuration file."""
    config_path = os.path.join(temp_plugin_dir, 'config.json')
    with open(config_path, 'w') as f:
        json.dump({'test': True}, f)

    plugin = VoiceFlowPlugin(mock_manifest)
    plugin.config_path = config_path
    plugin.on_load()

    yield plugin

    plugin.on_unload()
```

#### Mocking External Dependencies

```python
def test_with_mock_http(plugin, requests_mock):
    """Test plugin with mocked HTTP requests."""
    # Mock external API
    requests_mock.post(
        'https://api.example.com/process',
        json={'result': 'mocked response'}
    )

    output = plugin.on_transcription("test")
    assert output == "mocked response"
```

---

## Mock Frameworks

### Mocking in Swift Tests

#### Creating Mock Manifests

```swift
extension PluginManifest {
    static func mock(
        id: String = "com.example.test",
        name: String = "Test Plugin",
        version: String = "1.0.0"
    ) -> PluginManifest {
        return PluginManifest(
            id: id,
            name: name,
            version: version,
            author: "Test Author",
            description: "Mock manifest for testing",
            entrypoint: "plugin.swift",
            platform: "swift",
            permissions: [],
            homepage: nil,
            license: nil,
            minVoiceFlowVersion: nil,
            dependencies: nil
        )
    }
}

// Usage
let manifest = PluginManifest.mock(name: "Custom Name")
```

#### Mocking Network Calls

```swift
import Foundation

class MockURLProtocol: URLProtocol {
    static var mockData: Data?
    static var mockResponse: HTTPURLResponse?
    static var mockError: Error?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        if let error = MockURLProtocol.mockError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        if let response = MockURLProtocol.mockResponse {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        if let data = MockURLProtocol.mockData {
            client?.urlProtocol(self, didLoad: data)
        }

        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// Usage in tests
func testWithMockNetwork() {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)

    MockURLProtocol.mockData = "{\"result\":\"test\"}".data(using: .utf8)
    MockURLProtocol.mockResponse = HTTPURLResponse(
        url: URL(string: "https://example.com")!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
    )

    // Test plugin with mocked session
}
```

### Mocking in Python Tests

#### Using pytest-mock

```python
def test_with_mock_file_read(plugin, mocker):
    """Test plugin with mocked file reading."""
    mock_open = mocker.patch('builtins.open', mocker.mock_open(read_data='test data'))

    # Plugin reads from file
    result = plugin.load_config()

    mock_open.assert_called_once()
    assert result is not None
```

#### Using unittest.mock

```python
from unittest.mock import Mock, patch, MagicMock

def test_with_mock_http(plugin):
    """Test plugin with mocked HTTP library."""
    with patch('requests.post') as mock_post:
        mock_response = Mock()
        mock_response.json.return_value = {'result': 'success'}
        mock_response.status_code = 200
        mock_post.return_value = mock_response

        output = plugin.on_transcription("test")

        mock_post.assert_called_once()
        assert output == "success"
```

#### Creating Mock Objects

```python
@pytest.fixture
def mock_model():
    """Create mock ML model for testing."""
    model = MagicMock()
    model.predict.return_value = ["prediction"]
    return model

def test_with_mock_model(plugin, mock_model):
    """Test plugin with mocked ML model."""
    plugin.model = mock_model

    output = plugin.on_transcription("input")

    mock_model.predict.assert_called_once()
```

---

## Testing Lifecycle Methods

### Testing onLoad / on_load

#### Swift onLoad Tests

```swift
func testOnLoadInitializesResources() {
    let plugin = MyPlugin(manifest: mockManifest)

    plugin.onLoad()

    // Verify resources initialized
    XCTAssertNotNil(plugin.cache)
    XCTAssertFalse(plugin.wordList.isEmpty)
}

func testOnLoadHandlesError() {
    // Test graceful error handling
    let plugin = MyPlugin(manifest: mockManifest)

    // Should not crash even if resources missing
    XCTAssertNoThrow(plugin.onLoad())
}

func testOnLoadMultipleCalls() {
    let plugin = MyPlugin(manifest: mockManifest)

    // Should be idempotent
    plugin.onLoad()
    plugin.onLoad()

    // Should not cause issues
    XCTAssertNoThrow(plugin.onTranscription("test"))
}
```

#### Python on_load Tests

```python
def test_on_load_initializes_cache(plugin):
    """Test on_load initializes cache."""
    assert hasattr(plugin, 'cache')

def test_on_load_loads_config(plugin, temp_plugin_dir):
    """Test on_load loads configuration."""
    # Create config file
    config_path = os.path.join(temp_plugin_dir, 'config.json')
    with open(config_path, 'w') as f:
        json.dump({'key': 'value'}, f)

    plugin.config_path = config_path
    plugin.on_load()

    assert plugin.config['key'] == 'value'

def test_on_load_handles_missing_resources(plugin, monkeypatch):
    """Test on_load handles missing resources gracefully."""
    # Mock file not found
    def mock_open_error(*args, **kwargs):
        raise FileNotFoundError("Config not found")

    monkeypatch.setattr('builtins.open', mock_open_error)

    # Should not crash
    plugin.on_load()
```

### Testing onTranscription / on_transcription

#### Comprehensive Transcription Tests

```python
class TestTranscriptionEdgeCases:
    """Test edge cases in transcription."""

    test_cases = [
        # (input, description)
        ("", "empty string"),
        ("   ", "whitespace only"),
        ("a", "single character"),
        ("a" * 10000, "very long text"),
        ("Hello\nWorld", "multiline"),
        ("Hello\tWorld", "tabs"),
        ("Hello\r\nWorld", "windows line endings"),
        ("🎉🎊🎈", "emoji only"),
        ("test@example.com", "email address"),
        ("https://example.com", "URL"),
        ("$100.50", "currency"),
        ("2024-01-15", "date format"),
    ]

    @pytest.mark.parametrize("input_text,description", test_cases)
    def test_edge_case(self, plugin, input_text, description):
        """Test transcription handles edge case."""
        output = plugin.on_transcription(input_text)

        # Should not crash and return string
        assert isinstance(output, str), f"Failed on: {description}"
```

#### Testing Idempotency

```python
def test_transcription_idempotent(plugin):
    """Test that running transcription multiple times gives same result."""
    text = "test input"

    result1 = plugin.on_transcription(text)
    result2 = plugin.on_transcription(text)

    assert result1 == result2
```

#### Testing State Independence

```python
def test_transcription_stateless(plugin):
    """Test that transcriptions don't affect each other."""
    text1 = "first input"
    text2 = "second input"

    result1 = plugin.on_transcription(text1)
    result2 = plugin.on_transcription(text2)
    result1_again = plugin.on_transcription(text1)

    assert result1 == result1_again
```

### Testing onUnload / on_unload

#### Swift onUnload Tests

```swift
func testOnUnloadReleasesResources() {
    let plugin = MyPlugin(manifest: mockManifest)
    plugin.onLoad()

    plugin.onUnload()

    // Verify cleanup
    XCTAssertNil(plugin.database)
    XCTAssertTrue(plugin.cache.isEmpty)
}

func testOnUnloadIsIdempotent() {
    let plugin = MyPlugin(manifest: mockManifest)
    plugin.onLoad()

    // Should be safe to call multiple times
    plugin.onUnload()
    plugin.onUnload()

    XCTAssertNoThrow(plugin.onUnload())
}
```

#### Python on_unload Tests

```python
def test_on_unload_clears_cache(plugin):
    """Test on_unload clears cache."""
    plugin.cache = {'key': 'value'}
    plugin.on_unload()

    assert len(plugin.cache) == 0

def test_on_unload_saves_state(plugin, tmp_path):
    """Test on_unload persists state."""
    state_file = tmp_path / "state.json"
    plugin.state_file = str(state_file)
    plugin.state = {'data': 'important'}

    plugin.on_unload()

    assert state_file.exists()

def test_on_unload_handles_errors(plugin, monkeypatch):
    """Test on_unload handles errors gracefully."""
    def mock_close_error():
        raise IOError("Close failed")

    plugin.close_connection = mock_close_error

    # Should not raise
    plugin.on_unload()
```

---

## Manifest Validation Testing

### Testing Manifest Schema

```python
# tests/test_manifest.py
import json
import jsonschema
import pytest

@pytest.fixture
def manifest_schema():
    """Load the manifest schema."""
    with open('Plugins/manifest-schema.json') as f:
        return json.load(f)

@pytest.fixture
def valid_manifest():
    """Create a valid manifest for testing."""
    return {
        "id": "com.example.test",
        "name": "Test Plugin",
        "version": "1.0.0",
        "author": "Test Author",
        "description": "A test plugin for validation testing",
        "entrypoint": "plugin.py",
        "platform": "python"
    }

class TestManifestValidation:
    """Test manifest validation."""

    def test_valid_manifest(self, manifest_schema, valid_manifest):
        """Test that valid manifest passes validation."""
        jsonschema.validate(valid_manifest, manifest_schema)

    def test_missing_required_field(self, manifest_schema, valid_manifest):
        """Test that missing required field fails validation."""
        del valid_manifest['version']

        with pytest.raises(jsonschema.ValidationError):
            jsonschema.validate(valid_manifest, manifest_schema)

    def test_invalid_id_format(self, manifest_schema, valid_manifest):
        """Test that invalid ID format fails validation."""
        valid_manifest['id'] = "INVALID_ID"  # Should be lowercase with dots

        with pytest.raises(jsonschema.ValidationError):
            jsonschema.validate(valid_manifest, manifest_schema)

    def test_invalid_version_format(self, manifest_schema, valid_manifest):
        """Test that invalid version fails validation."""
        valid_manifest['version'] = "1.0"  # Should be MAJOR.MINOR.PATCH

        with pytest.raises(jsonschema.ValidationError):
            jsonschema.validate(valid_manifest, manifest_schema)

    def test_description_too_short(self, manifest_schema, valid_manifest):
        """Test that short description fails validation."""
        valid_manifest['description'] = "short"  # Min 10 chars

        with pytest.raises(jsonschema.ValidationError):
            jsonschema.validate(valid_manifest, manifest_schema)

    def test_invalid_platform(self, manifest_schema, valid_manifest):
        """Test that invalid platform fails validation."""
        valid_manifest['platform'] = "javascript"  # Not supported

        with pytest.raises(jsonschema.ValidationError):
            jsonschema.validate(valid_manifest, manifest_schema)

    def test_optional_fields(self, manifest_schema, valid_manifest):
        """Test that optional fields are validated when present."""
        valid_manifest['permissions'] = ["text.read", "text.modify"]
        valid_manifest['homepage'] = "https://github.com/user/plugin"
        valid_manifest['license'] = "MIT"

        jsonschema.validate(valid_manifest, manifest_schema)

    def test_invalid_permission(self, manifest_schema, valid_manifest):
        """Test that invalid permission fails validation."""
        valid_manifest['permissions'] = ["invalid.permission"]

        with pytest.raises(jsonschema.ValidationError):
            jsonschema.validate(valid_manifest, manifest_schema)
```

### Testing Manifest Loading

```python
def test_load_manifest_from_file(tmp_path):
    """Test loading manifest from file."""
    manifest_file = tmp_path / "manifest.json"
    manifest_data = {
        "id": "com.example.test",
        "name": "Test",
        "version": "1.0.0",
        "author": "Author",
        "description": "Test description here",
        "entrypoint": "plugin.py",
        "platform": "python"
    }

    manifest_file.write_text(json.dumps(manifest_data))

    with open(manifest_file) as f:
        loaded = json.load(f)

    assert loaded == manifest_data

def test_malformed_manifest(tmp_path):
    """Test handling of malformed JSON."""
    manifest_file = tmp_path / "manifest.json"
    manifest_file.write_text("{invalid json")

    with pytest.raises(json.JSONDecodeError):
        with open(manifest_file) as f:
            json.load(f)
```

---

## Debugging Test Failures

### Common Test Failures

#### 1. Plugin Not Initializing

**Symptom:**
```
AttributeError: 'NoneType' object has no attribute 'on_transcription'
```

**Cause:** Plugin not initialized in test setup

**Solution:**
```python
@pytest.fixture
def plugin(mock_manifest):
    p = VoiceFlowPlugin(mock_manifest)
    p.on_load()  # Don't forget this!
    yield p
    p.on_unload()
```

#### 2. Manifest ID Mismatch

**Symptom:**
```
AssertionError: Expected 'com.example.test', got 'com.example.different'
```

**Cause:** `pluginID` doesn't match manifest

**Solution:**
```swift
// Ensure consistency
var pluginID: String { manifest.id }  // Use manifest.id directly
```

#### 3. Resource Not Found

**Symptom:**
```
FileNotFoundError: [Errno 2] No such file or directory: 'config.json'
```

**Cause:** Test running from different directory

**Solution:**
```python
import os

def get_plugin_dir():
    return os.path.dirname(os.path.abspath(__file__))

config_path = os.path.join(get_plugin_dir(), 'config.json')
```

#### 4. State Leaking Between Tests

**Symptom:** Tests pass individually but fail when run together

**Cause:** Shared state not cleaned up

**Solution:**
```python
@pytest.fixture
def plugin(mock_manifest):
    p = VoiceFlowPlugin(mock_manifest)
    p.on_load()
    yield p
    p.on_unload()  # Always cleanup!
    # Clear any module-level state
```

#### 5. Flaky Tests

**Symptom:** Tests pass sometimes, fail other times

**Cause:** Timing issues, external dependencies

**Solution:**
```python
# Mock external dependencies
@patch('time.sleep')  # Mock sleeps
@patch('requests.get')  # Mock network
def test_stable(mock_get, mock_sleep, plugin):
    mock_get.return_value.text = "stable result"
    # Now test is deterministic
```

### Debugging Techniques

#### Enable Verbose Logging

```python
# Add to conftest.py
import logging

@pytest.fixture(autouse=True)
def configure_logging():
    logging.basicConfig(
        level=logging.DEBUG,
        format='%(asctime)s [%(name)s] %(levelname)s: %(message)s'
    )
```

#### Use pytest's Built-in Debugger

```bash
# Drop into debugger on failure
pytest --pdb

# Drop into debugger at start of test
pytest --trace
```

#### Print Debugging

```python
def test_with_debug_output(plugin, capsys):
    """Test with captured output."""
    print(f"DEBUG: Plugin state: {plugin.__dict__}")

    output = plugin.on_transcription("test")

    # Access captured output
    captured = capsys.readouterr()
    print(captured.out)
```

#### Inspect Test Artifacts

```python
@pytest.fixture
def debug_dir(tmp_path):
    """Create directory for test artifacts."""
    debug = tmp_path / "debug"
    debug.mkdir()
    return debug

def test_with_artifacts(plugin, debug_dir):
    """Test that saves debug artifacts."""
    result = plugin.on_transcription("test")

    # Save for inspection
    (debug_dir / "result.txt").write_text(result)
```

---

## Continuous Integration

### GitHub Actions Example

```yaml
# .github/workflows/test.yml
name: Plugin Tests

on: [push, pull_request]

jobs:
  test-python:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ['3.11', '3.12']

    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: ${{ matrix.python-version }}

      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install -r requirements-dev.txt

      - name: Run tests
        run: pytest --cov=plugin --cov-report=xml

      - name: Upload coverage
        uses: codecov/codecov-action@v3

  test-swift:
    runs-on: macos-latest

    steps:
      - uses: actions/checkout@v3

      - name: Set up Swift
        uses: swift-actions/setup-swift@v1
        with:
          swift-version: '5.9'

      - name: Run tests
        run: swift test --enable-code-coverage

      - name: Generate coverage report
        run: |
          xcrun llvm-cov export -format="lcov" \
            .build/debug/MyPluginPackageTests.xctest/Contents/MacOS/MyPluginPackageTests \
            -instr-profile .build/debug/codecov/default.profdata > coverage.lcov
```

### Pre-commit Hooks

```bash
# .git/hooks/pre-commit
#!/bin/bash

echo "Running tests before commit..."

# Run Python tests
pytest
if [ $? -ne 0 ]; then
    echo "❌ Python tests failed"
    exit 1
fi

# Run Swift tests
swift test
if [ $? -ne 0 ]; then
    echo "❌ Swift tests failed"
    exit 1
fi

echo "✅ All tests passed"
```

---

## Best Practices

### 1. Write Tests First (TDD)

```python
# Write test first
def test_uppercase_conversion(plugin):
    """Test converting text to uppercase."""
    assert plugin.on_transcription("hello") == "HELLO"

# Then implement
def on_transcription(self, text: str) -> str:
    return text.upper()
```

### 2. Test One Thing Per Test

```python
# ❌ Bad: Testing multiple things
def test_everything(plugin):
    plugin.on_load()
    output = plugin.on_transcription("test")
    plugin.on_unload()
    assert output == "TEST"

# ✅ Good: Separate tests
def test_on_load(plugin):
    plugin.on_load()
    # Assert load behavior

def test_transcription(plugin):
    assert plugin.on_transcription("test") == "TEST"

def test_on_unload(plugin):
    plugin.on_unload()
    # Assert cleanup
```

### 3. Use Descriptive Test Names

```python
# ❌ Bad
def test1(plugin):
    assert plugin.on_transcription("") == ""

# ✅ Good
def test_empty_input_returns_empty_string(plugin):
    assert plugin.on_transcription("") == ""
```

### 4. Keep Tests Independent

```python
# ❌ Bad: Tests depend on order
class TestPlugin:
    def test_step1(self):
        self.data = "value"

    def test_step2(self):
        assert self.data == "value"  # Fails if run alone

# ✅ Good: Each test is independent
class TestPlugin:
    @pytest.fixture
    def data(self):
        return "value"

    def test_step1(self, data):
        assert data == "value"

    def test_step2(self, data):
        assert data == "value"
```

### 5. Test Error Paths

```python
def test_handles_network_error(plugin, monkeypatch):
    """Test plugin handles network errors."""
    def mock_error(*args, **kwargs):
        raise ConnectionError("Network down")

    monkeypatch.setattr('requests.post', mock_error)

    # Should not crash, should fallback gracefully
    output = plugin.on_transcription("test")
    assert output == "test"  # Returns original on error
```

### 6. Aim for High Coverage

```bash
# Generate coverage report
pytest --cov=plugin --cov-report=term-missing

# Aim for:
# - 80%+ overall coverage
# - 100% coverage of critical paths
# - Test all error handlers
```

### 7. Document Test Intent

```python
def test_transcription_preserves_emoji(plugin):
    """
    Test that emoji are preserved during transcription.

    This is important because some text processing libraries
    strip emoji, which we want to avoid.
    """
    input_text = "Hello 👋 World 🌍"
    output = plugin.on_transcription(input_text)

    assert "👋" in output
    assert "🌍" in output
```

---

## Summary

**Testing Checklist:**

- ✅ Unit tests for all lifecycle methods
- ✅ Edge case tests (empty, long, special characters)
- ✅ Error handling tests
- ✅ Performance tests
- ✅ Manifest validation tests
- ✅ Mock external dependencies
- ✅ CI/CD integration
- ✅ Code coverage > 80%

**Next Steps:**

- Review [PLUGIN_DEVELOPMENT.md](./PLUGIN_DEVELOPMENT.md) for implementation guidance
- Check [PLUGIN_API_REFERENCE.md](./PLUGIN_API_REFERENCE.md) for API details
- Explore example plugins in `Plugins/Examples/`
- Use `scripts/plugin-dev-tools.sh test` for running tests

---

**Remember:** Well-tested plugins are reliable plugins. Invest time in testing to save debugging time later! 🧪
