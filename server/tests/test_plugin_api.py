#!/usr/bin/env python3
"""
Unit tests for Plugin API (plugin_api.py)

Tests the base classes and data structures for the VoiceFlow plugin system:
- PluginManifest.from_dict()
- VoiceFlowPlugin lifecycle
- Error classes
"""

import pytest
from plugin_api import (
    ExecutionFailedError,
    LoadFailedError,
    ManifestInvalidError,
    PermissionDeniedError,
    PluginError,
    PluginInfo,
    PluginManifest,
    PluginPlatform,
    PluginState,
    VoiceFlowPlugin,
)


class TestPluginManifest:
    """Test PluginManifest data class."""

    def test_from_dict_valid_python_plugin(self):
        """Test creating manifest from valid Python plugin dict."""
        data = {
            "id": "com.test.plugin",
            "name": "Test Plugin",
            "version": "1.0.0",
            "author": "Test Author",
            "description": "A test plugin",
            "entrypoint": "plugin.py",
            "permissions": ["text.read", "text.modify"],
            "platform": "python",
        }

        manifest = PluginManifest.from_dict(data)

        assert manifest.id == "com.test.plugin"
        assert manifest.name == "Test Plugin"
        assert manifest.version == "1.0.0"
        assert manifest.author == "Test Author"
        assert manifest.description == "A test plugin"
        assert manifest.entrypoint == "plugin.py"
        assert manifest.permissions == ["text.read", "text.modify"]
        assert manifest.platform == PluginPlatform.PYTHON

    def test_from_dict_swift_platform(self):
        """Test creating manifest with swift platform."""
        data = {
            "id": "com.test.swift",
            "name": "Swift Plugin",
            "version": "1.0.0",
            "author": "Test",
            "description": "Swift test",
            "entrypoint": "Plugin.swift",
            "platform": "swift",
        }

        manifest = PluginManifest.from_dict(data)
        assert manifest.platform == PluginPlatform.SWIFT

    def test_from_dict_both_platform(self):
        """Test creating manifest with both platform."""
        data = {
            "id": "com.test.both",
            "name": "Cross-platform Plugin",
            "version": "1.0.0",
            "author": "Test",
            "description": "Cross-platform test",
            "entrypoint": "plugin",
            "platform": "both",
        }

        manifest = PluginManifest.from_dict(data)
        assert manifest.platform == PluginPlatform.BOTH

    def test_from_dict_default_permissions(self):
        """Test manifest without permissions gets empty list."""
        data = {
            "id": "com.test.noperm",
            "name": "No Permissions",
            "version": "1.0.0",
            "author": "Test",
            "description": "No permissions test",
            "entrypoint": "plugin.py",
        }

        manifest = PluginManifest.from_dict(data)
        assert manifest.permissions == []

    def test_from_dict_default_platform(self):
        """Test manifest defaults to python platform."""
        data = {
            "id": "com.test.default",
            "name": "Default Platform",
            "version": "1.0.0",
            "author": "Test",
            "description": "Default platform test",
            "entrypoint": "plugin.py",
        }

        manifest = PluginManifest.from_dict(data)
        assert manifest.platform == PluginPlatform.PYTHON

    def test_from_dict_missing_required_field(self):
        """Test manifest creation fails with missing required field."""
        data = {
            "id": "com.test.invalid",
            "name": "Invalid Plugin",
            # Missing: version, author, description, entrypoint
        }

        with pytest.raises(KeyError):
            PluginManifest.from_dict(data)


class TestPluginPlatform:
    """Test PluginPlatform enum."""

    def test_platform_values(self):
        """Test platform enum has correct values."""
        assert PluginPlatform.SWIFT.value == "swift"
        assert PluginPlatform.PYTHON.value == "python"
        assert PluginPlatform.BOTH.value == "both"

    def test_platform_from_string(self):
        """Test creating platform enum from string."""
        assert PluginPlatform("swift") == PluginPlatform.SWIFT
        assert PluginPlatform("python") == PluginPlatform.PYTHON
        assert PluginPlatform("both") == PluginPlatform.BOTH


class TestPluginState:
    """Test PluginState enum."""

    def test_state_values(self):
        """Test state enum has correct values."""
        assert PluginState.LOADED.value == "loaded"
        assert PluginState.ENABLED.value == "enabled"
        assert PluginState.DISABLED.value == "disabled"
        assert PluginState.FAILED.value == "failed"


class TestPluginInfo:
    """Test PluginInfo data class."""

    def test_plugin_info_creation(self):
        """Test creating PluginInfo object."""
        manifest = PluginManifest(
            id="test.plugin",
            name="Test",
            version="1.0.0",
            author="Author",
            description="Description",
            entrypoint="plugin.py",
            permissions=[],
            platform=PluginPlatform.PYTHON,
        )

        info = PluginInfo(manifest=manifest, state=PluginState.LOADED)

        assert info.manifest == manifest
        assert info.state == PluginState.LOADED
        assert info.plugin is None
        assert info.error is None

    def test_is_enabled_property(self):
        """Test is_enabled property."""
        manifest = PluginManifest(
            id="test.plugin",
            name="Test",
            version="1.0.0",
            author="Author",
            description="Description",
            entrypoint="plugin.py",
            permissions=[],
            platform=PluginPlatform.PYTHON,
        )

        # Test enabled state
        info_enabled = PluginInfo(manifest=manifest, state=PluginState.ENABLED)
        assert info_enabled.is_enabled is True

        # Test loaded state (not enabled)
        info_loaded = PluginInfo(manifest=manifest, state=PluginState.LOADED)
        assert info_loaded.is_enabled is False

        # Test disabled state
        info_disabled = PluginInfo(manifest=manifest, state=PluginState.DISABLED)
        assert info_disabled.is_enabled is False

        # Test failed state
        info_failed = PluginInfo(manifest=manifest, state=PluginState.FAILED)
        assert info_failed.is_enabled is False


class TestPluginErrors:
    """Test plugin error classes."""

    def test_plugin_error_hierarchy(self):
        """Test error class inheritance."""
        assert issubclass(LoadFailedError, PluginError)
        assert issubclass(ManifestInvalidError, PluginError)
        assert issubclass(PermissionDeniedError, PluginError)
        assert issubclass(ExecutionFailedError, PluginError)
        assert issubclass(PluginError, Exception)

    def test_load_failed_error(self):
        """Test LoadFailedError can be raised."""
        with pytest.raises(LoadFailedError) as exc_info:
            raise LoadFailedError("Load failed")
        assert str(exc_info.value) == "Load failed"

    def test_manifest_invalid_error(self):
        """Test ManifestInvalidError can be raised."""
        with pytest.raises(ManifestInvalidError) as exc_info:
            raise ManifestInvalidError("Invalid manifest")
        assert str(exc_info.value) == "Invalid manifest"

    def test_permission_denied_error(self):
        """Test PermissionDeniedError can be raised."""
        with pytest.raises(PermissionDeniedError) as exc_info:
            raise PermissionDeniedError("Permission denied")
        assert str(exc_info.value) == "Permission denied"

    def test_execution_failed_error(self):
        """Test ExecutionFailedError can be raised."""
        with pytest.raises(ExecutionFailedError) as exc_info:
            raise ExecutionFailedError("Execution failed")
        assert str(exc_info.value) == "Execution failed"


class TestVoiceFlowPlugin:
    """Test VoiceFlowPlugin base class."""

    def test_plugin_is_abstract(self):
        """Test VoiceFlowPlugin is an abstract base class."""
        manifest = PluginManifest(
            id="test.plugin",
            name="Test",
            version="1.0.0",
            author="Author",
            description="Description",
            entrypoint="plugin.py",
            permissions=[],
            platform=PluginPlatform.PYTHON,
        )

        # Cannot instantiate abstract class
        with pytest.raises(TypeError):
            VoiceFlowPlugin(manifest)

    def test_concrete_plugin_implementation(self):
        """Test concrete plugin implementation."""

        class TestPlugin(VoiceFlowPlugin):
            async def on_load(self):
                pass

            async def on_transcription(self, text: str) -> str:
                return text.upper()

            async def on_unload(self):
                pass

        manifest = PluginManifest(
            id="test.plugin",
            name="Test",
            version="1.0.0",
            author="Author",
            description="Description",
            entrypoint="plugin.py",
            permissions=[],
            platform=PluginPlatform.PYTHON,
        )

        plugin = TestPlugin(manifest)

        assert plugin.plugin_id == "test.plugin"
        assert plugin.manifest == manifest

    @pytest.mark.asyncio
    async def test_plugin_lifecycle_hooks(self):
        """Test plugin lifecycle hooks are called."""

        class LifecycleTestPlugin(VoiceFlowPlugin):
            def __init__(self, manifest):
                super().__init__(manifest)
                self.load_called = False
                self.unload_called = False
                self.transcription_count = 0

            async def on_load(self):
                self.load_called = True

            async def on_transcription(self, text: str) -> str:
                self.transcription_count += 1
                return text.upper()

            async def on_unload(self):
                self.unload_called = True

        manifest = PluginManifest(
            id="test.lifecycle",
            name="Lifecycle Test",
            version="1.0.0",
            author="Test",
            description="Lifecycle test",
            entrypoint="plugin.py",
            permissions=[],
            platform=PluginPlatform.PYTHON,
        )

        plugin = LifecycleTestPlugin(manifest)

        # Test on_load
        await plugin.on_load()
        assert plugin.load_called is True

        # Test on_transcription
        result = await plugin.on_transcription("hello world")
        assert result == "HELLO WORLD"
        assert plugin.transcription_count == 1

        # Test on_unload
        await plugin.on_unload()
        assert plugin.unload_called is True
