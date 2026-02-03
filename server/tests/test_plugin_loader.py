#!/usr/bin/env python3
"""
Unit tests for Plugin Loader (plugin_loader.py)

Tests plugin discovery, loading, lifecycle management, and text processing:
- Plugin discovery
- Manifest loading
- Plugin loading/unloading
- Text processing pipeline
- Error handling
"""

import json
import pytest
import tempfile
from pathlib import Path
from plugin_api import (
    LoadFailedError,
    ManifestInvalidError,
    PluginManifest,
    PluginPlatform,
    PluginState,
    VoiceFlowPlugin,
)
from plugin_loader import PluginLoader


class TestPluginLoader:
    """Test PluginLoader class."""

    @pytest.fixture
    def temp_plugins_dir(self):
        """Create temporary plugins directory."""
        with tempfile.TemporaryDirectory() as tmpdir:
            yield Path(tmpdir)

    @pytest.fixture
    def loader_with_temp_dir(self, temp_plugins_dir):
        """Create PluginLoader with temporary directory."""
        return PluginLoader(plugins_dir=temp_plugins_dir)

    def test_loader_initialization(self, temp_plugins_dir):
        """Test PluginLoader initialization."""
        loader = PluginLoader(plugins_dir=temp_plugins_dir)
        assert loader.plugins_dir == temp_plugins_dir
        assert loader.loaded_plugins == {}

    def test_loader_default_directory(self):
        """Test PluginLoader uses default directory when not specified."""
        loader = PluginLoader()
        expected_dir = (
            Path.home() / "Library" / "Application Support" / "VoiceFlow" / "Plugins"
        )
        assert loader.plugins_dir == expected_dir

    def test_discover_plugins_empty_directory(self, loader_with_temp_dir):
        """Test discovery in empty directory returns empty list."""
        plugin_dirs = loader_with_temp_dir.discover_plugins()
        assert plugin_dirs == []

    def test_discover_plugins_with_valid_plugins(
        self, temp_plugins_dir, loader_with_temp_dir
    ):
        """Test discovery finds plugins with manifest.json."""
        # Create plugin directory with manifest
        plugin1_dir = temp_plugins_dir / "Plugin1"
        plugin1_dir.mkdir()
        (plugin1_dir / "manifest.json").write_text("{}")

        plugin2_dir = temp_plugins_dir / "Plugin2"
        plugin2_dir.mkdir()
        (plugin2_dir / "manifest.json").write_text("{}")

        # Create directory without manifest (should be ignored)
        plugin3_dir = temp_plugins_dir / "NotAPlugin"
        plugin3_dir.mkdir()

        plugin_dirs = loader_with_temp_dir.discover_plugins()

        assert len(plugin_dirs) == 2
        assert plugin1_dir in plugin_dirs
        assert plugin2_dir in plugin_dirs
        assert plugin3_dir not in plugin_dirs

    def test_discover_plugins_nonexistent_directory(self):
        """Test discovery in non-existent directory returns empty list."""
        loader = PluginLoader(plugins_dir=Path("/nonexistent/path"))
        plugin_dirs = loader.discover_plugins()
        assert plugin_dirs == []

    def test_load_manifest_valid(self, temp_plugins_dir, loader_with_temp_dir):
        """Test loading valid manifest."""
        plugin_dir = temp_plugins_dir / "TestPlugin"
        plugin_dir.mkdir()

        manifest_data = {
            "id": "com.test.plugin",
            "name": "Test Plugin",
            "version": "1.0.0",
            "author": "Test Author",
            "description": "A test plugin",
            "entrypoint": "plugin.py",
            "permissions": ["text.read"],
            "platform": "python",
        }

        (plugin_dir / "manifest.json").write_text(json.dumps(manifest_data))

        manifest = loader_with_temp_dir.load_manifest(plugin_dir)

        assert manifest.id == "com.test.plugin"
        assert manifest.name == "Test Plugin"
        assert manifest.version == "1.0.0"
        assert manifest.author == "Test Author"
        assert manifest.platform == PluginPlatform.PYTHON

    def test_load_manifest_missing_file(self, temp_plugins_dir, loader_with_temp_dir):
        """Test loading manifest from directory without manifest.json."""
        plugin_dir = temp_plugins_dir / "NoManifest"
        plugin_dir.mkdir()

        with pytest.raises(ManifestInvalidError) as exc_info:
            loader_with_temp_dir.load_manifest(plugin_dir)

        assert "Manifest not found" in str(exc_info.value)

    def test_load_manifest_invalid_json(self, temp_plugins_dir, loader_with_temp_dir):
        """Test loading manifest with invalid JSON."""
        plugin_dir = temp_plugins_dir / "BadJson"
        plugin_dir.mkdir()

        (plugin_dir / "manifest.json").write_text("{invalid json")

        with pytest.raises(ManifestInvalidError) as exc_info:
            loader_with_temp_dir.load_manifest(plugin_dir)

        assert "Invalid JSON" in str(exc_info.value)

    def test_load_manifest_missing_required_fields(
        self, temp_plugins_dir, loader_with_temp_dir
    ):
        """Test loading manifest with missing required fields."""
        plugin_dir = temp_plugins_dir / "Incomplete"
        plugin_dir.mkdir()

        manifest_data = {
            "id": "com.test.incomplete",
            "name": "Incomplete Plugin",
            # Missing: version, author, description, entrypoint
        }

        (plugin_dir / "manifest.json").write_text(json.dumps(manifest_data))

        with pytest.raises(ManifestInvalidError) as exc_info:
            loader_with_temp_dir.load_manifest(plugin_dir)

        assert "Missing required fields" in str(exc_info.value)

    @pytest.mark.asyncio
    async def test_load_plugin_success(self, temp_plugins_dir, loader_with_temp_dir):
        """Test successfully loading a Python plugin."""
        plugin_dir = temp_plugins_dir / "ValidPlugin"
        plugin_dir.mkdir()

        # Create manifest
        manifest_data = {
            "id": "com.test.valid",
            "name": "Valid Plugin",
            "version": "1.0.0",
            "author": "Test",
            "description": "Valid test plugin",
            "entrypoint": "plugin.py",
            "platform": "python",
        }
        (plugin_dir / "manifest.json").write_text(json.dumps(manifest_data))

        # Create plugin file
        plugin_code = '''
from plugin_api import VoiceFlowPlugin

class ValidPlugin(VoiceFlowPlugin):
    async def on_load(self):
        pass

    async def on_transcription(self, text: str) -> str:
        return text.upper()

    async def on_unload(self):
        pass
'''
        (plugin_dir / "plugin.py").write_text(plugin_code)

        plugin_info = await loader_with_temp_dir.load_plugin(plugin_dir)

        assert plugin_info.manifest.id == "com.test.valid"
        assert plugin_info.state == PluginState.LOADED
        assert plugin_info.plugin is not None
        assert plugin_info.error is None
        assert "com.test.valid" in loader_with_temp_dir.loaded_plugins

    @pytest.mark.asyncio
    async def test_load_plugin_swift_platform_rejected(
        self, temp_plugins_dir, loader_with_temp_dir
    ):
        """Test loading Swift plugin is rejected by Python loader."""
        plugin_dir = temp_plugins_dir / "SwiftPlugin"
        plugin_dir.mkdir()

        manifest_data = {
            "id": "com.test.swift",
            "name": "Swift Plugin",
            "version": "1.0.0",
            "author": "Test",
            "description": "Swift plugin",
            "entrypoint": "Plugin.swift",
            "platform": "swift",
        }
        (plugin_dir / "manifest.json").write_text(json.dumps(manifest_data))

        with pytest.raises(LoadFailedError) as exc_info:
            await loader_with_temp_dir.load_plugin(plugin_dir)

        assert "not a Python plugin" in str(exc_info.value)

    @pytest.mark.asyncio
    async def test_load_plugin_missing_entrypoint(
        self, temp_plugins_dir, loader_with_temp_dir
    ):
        """Test loading plugin with missing entrypoint file."""
        plugin_dir = temp_plugins_dir / "NoEntrypoint"
        plugin_dir.mkdir()

        manifest_data = {
            "id": "com.test.noentry",
            "name": "No Entrypoint",
            "version": "1.0.0",
            "author": "Test",
            "description": "Missing entrypoint",
            "entrypoint": "missing.py",
            "platform": "python",
        }
        (plugin_dir / "manifest.json").write_text(json.dumps(manifest_data))

        with pytest.raises(LoadFailedError) as exc_info:
            await loader_with_temp_dir.load_plugin(plugin_dir)

        assert "entrypoint not found" in str(exc_info.value).lower()

    @pytest.mark.asyncio
    async def test_unload_plugin_success(self, temp_plugins_dir, loader_with_temp_dir):
        """Test successfully unloading a plugin."""
        plugin_dir = temp_plugins_dir / "UnloadTest"
        plugin_dir.mkdir()

        manifest_data = {
            "id": "com.test.unload",
            "name": "Unload Test",
            "version": "1.0.0",
            "author": "Test",
            "description": "Unload test",
            "entrypoint": "plugin.py",
            "platform": "python",
        }
        (plugin_dir / "manifest.json").write_text(json.dumps(manifest_data))

        plugin_code = '''
from plugin_api import VoiceFlowPlugin

class UnloadTestPlugin(VoiceFlowPlugin):
    async def on_load(self):
        pass

    async def on_transcription(self, text: str) -> str:
        return text

    async def on_unload(self):
        pass
'''
        (plugin_dir / "plugin.py").write_text(plugin_code)

        # Load plugin
        await loader_with_temp_dir.load_plugin(plugin_dir)
        assert "com.test.unload" in loader_with_temp_dir.loaded_plugins

        # Unload plugin
        await loader_with_temp_dir.unload_plugin("com.test.unload")
        assert "com.test.unload" not in loader_with_temp_dir.loaded_plugins

    @pytest.mark.asyncio
    async def test_unload_plugin_not_loaded(self, loader_with_temp_dir):
        """Test unloading plugin that is not loaded raises error."""
        with pytest.raises(ValueError) as exc_info:
            await loader_with_temp_dir.unload_plugin("nonexistent.plugin")

        assert "not loaded" in str(exc_info.value).lower()

    @pytest.mark.asyncio
    async def test_process_text_enabled_plugin(
        self, temp_plugins_dir, loader_with_temp_dir
    ):
        """Test text processing through enabled plugin."""
        plugin_dir = temp_plugins_dir / "TextProcessor"
        plugin_dir.mkdir()

        manifest_data = {
            "id": "com.test.processor",
            "name": "Text Processor",
            "version": "1.0.0",
            "author": "Test",
            "description": "Processes text",
            "entrypoint": "plugin.py",
            "platform": "python",
        }
        (plugin_dir / "manifest.json").write_text(json.dumps(manifest_data))

        plugin_code = '''
from plugin_api import VoiceFlowPlugin

class TextProcessorPlugin(VoiceFlowPlugin):
    async def on_load(self):
        pass

    async def on_transcription(self, text: str) -> str:
        return text.upper()

    async def on_unload(self):
        pass
'''
        (plugin_dir / "plugin.py").write_text(plugin_code)

        # Load and enable plugin
        plugin_info = await loader_with_temp_dir.load_plugin(plugin_dir)
        plugin_info.state = PluginState.ENABLED

        # Process text
        result = await loader_with_temp_dir.process_text("hello world")
        assert result == "HELLO WORLD"

    @pytest.mark.asyncio
    async def test_process_text_disabled_plugin_ignored(
        self, temp_plugins_dir, loader_with_temp_dir
    ):
        """Test disabled plugin is not executed during text processing."""
        plugin_dir = temp_plugins_dir / "DisabledPlugin"
        plugin_dir.mkdir()

        manifest_data = {
            "id": "com.test.disabled",
            "name": "Disabled Plugin",
            "version": "1.0.0",
            "author": "Test",
            "description": "Disabled",
            "entrypoint": "plugin.py",
            "platform": "python",
        }
        (plugin_dir / "manifest.json").write_text(json.dumps(manifest_data))

        plugin_code = '''
from plugin_api import VoiceFlowPlugin

class DisabledPlugin(VoiceFlowPlugin):
    async def on_load(self):
        pass

    async def on_transcription(self, text: str) -> str:
        return text.upper()  # Should not be called

    async def on_unload(self):
        pass
'''
        (plugin_dir / "plugin.py").write_text(plugin_code)

        # Load plugin but keep it disabled (LOADED state, not ENABLED)
        plugin_info = await loader_with_temp_dir.load_plugin(plugin_dir)
        assert plugin_info.state == PluginState.LOADED

        # Process text - should not be modified
        result = await loader_with_temp_dir.process_text("hello world")
        assert result == "hello world"  # Unchanged

    def test_get_plugin(self, loader_with_temp_dir):
        """Test getting plugin by ID."""
        manifest = PluginManifest(
            id="test.get",
            name="Get Test",
            version="1.0.0",
            author="Test",
            description="Get test",
            entrypoint="plugin.py",
            permissions=[],
            platform=PluginPlatform.PYTHON,
        )

        from plugin_api import PluginInfo

        plugin_info = PluginInfo(manifest=manifest, state=PluginState.LOADED)
        loader_with_temp_dir.loaded_plugins["test.get"] = plugin_info

        retrieved = loader_with_temp_dir.get_plugin("test.get")
        assert retrieved == plugin_info

        # Non-existent plugin
        assert loader_with_temp_dir.get_plugin("nonexistent") is None

    def test_list_plugins(self, loader_with_temp_dir):
        """Test listing all loaded plugins."""
        manifest1 = PluginManifest(
            id="test.list1",
            name="List Test 1",
            version="1.0.0",
            author="Test",
            description="List test",
            entrypoint="plugin.py",
            permissions=[],
            platform=PluginPlatform.PYTHON,
        )

        manifest2 = PluginManifest(
            id="test.list2",
            name="List Test 2",
            version="1.0.0",
            author="Test",
            description="List test",
            entrypoint="plugin.py",
            permissions=[],
            platform=PluginPlatform.PYTHON,
        )

        from plugin_api import PluginInfo

        loader_with_temp_dir.loaded_plugins["test.list1"] = PluginInfo(
            manifest=manifest1
        )
        loader_with_temp_dir.loaded_plugins["test.list2"] = PluginInfo(
            manifest=manifest2
        )

        plugins = loader_with_temp_dir.list_plugins()
        assert len(plugins) == 2
