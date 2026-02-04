#!/usr/bin/env python3
"""VoiceFlow Plugin API - Base classes for Python plugins."""

import logging
from abc import ABC, abstractmethod
from dataclasses import dataclass
from enum import Enum
from typing import Optional

logger = logging.getLogger(__name__)


# MARK: - Plugin Metadata


class PluginPlatform(str, Enum):
    """Supported plugin platforms."""

    SWIFT = "swift"
    PYTHON = "python"
    BOTH = "both"


@dataclass
class PluginManifest:
    """Plugin metadata and configuration."""

    id: str
    name: str
    version: str
    author: str
    description: str
    entrypoint: str
    permissions: list[str]
    platform: PluginPlatform

    @classmethod
    def from_dict(cls, data: dict) -> "PluginManifest":
        """Create manifest from dictionary (e.g., loaded from JSON)."""
        platform = data.get("platform", "python")
        if isinstance(platform, str):
            platform = PluginPlatform(platform)
        return cls(
            id=data["id"],
            name=data["name"],
            version=data["version"],
            author=data["author"],
            description=data["description"],
            entrypoint=data["entrypoint"],
            permissions=data.get("permissions", []),
            platform=platform,
        )


# MARK: - Plugin Error


class PluginError(Exception):
    """Base exception for plugin-related errors."""

    pass


class LoadFailedError(PluginError):
    """Raised when plugin loading fails."""

    pass


class ManifestInvalidError(PluginError):
    """Raised when plugin manifest is invalid."""

    pass


class PermissionDeniedError(PluginError):
    """Raised when plugin lacks required permissions."""

    pass


class ExecutionFailedError(PluginError):
    """Raised when plugin execution fails."""

    pass


# MARK: - Plugin State


class PluginState(str, Enum):
    """Plugin lifecycle states."""

    LOADED = "loaded"
    ENABLED = "enabled"
    DISABLED = "disabled"
    FAILED = "failed"


@dataclass
class PluginInfo:
    """Plugin runtime information."""

    manifest: PluginManifest
    state: PluginState = PluginState.LOADED
    plugin: Optional["VoiceFlowPlugin"] = None
    error: Optional[Exception] = None

    @property
    def is_enabled(self) -> bool:
        """Check if plugin is enabled."""
        return self.state == PluginState.ENABLED


# MARK: - Plugin Protocol


class VoiceFlowPlugin(ABC):
    """
    Abstract base class for VoiceFlow plugins.

    All VoiceFlow plugins must inherit from this class and implement
    the required lifecycle hooks.
    """

    def __init__(self, manifest: PluginManifest):
        """
        Initialize the plugin.

        Args:
            manifest: Plugin metadata and configuration
        """
        self._manifest = manifest
        self._plugin_id = manifest.id

    @property
    def plugin_id(self) -> str:
        """Unique identifier for the plugin."""
        return self._plugin_id

    @property
    def manifest(self) -> PluginManifest:
        """Plugin metadata."""
        return self._manifest

    @abstractmethod
    async def on_load(self) -> None:
        """
        Called when the plugin is loaded.

        Use this hook to initialize resources, load configuration,
        or perform any setup required by the plugin.

        Raises:
            PluginError: If initialization fails
        """
        pass

    @abstractmethod
    async def on_transcription(self, text: str) -> str:
        """
        Called when transcription text is available for processing.

        This is the main processing hook where plugins can transform,
        analyze, or modify the transcribed text.

        Args:
            text: The transcribed text from the ASR system

        Returns:
            The processed text (can be the same as input if no transformation needed)

        Raises:
            PluginError: If text processing fails
        """
        pass

    @abstractmethod
    async def on_unload(self) -> None:
        """
        Called when the plugin is unloaded.

        Use this hook to clean up resources, save state, or perform
        any teardown required by the plugin.

        Raises:
            PluginError: If cleanup fails
        """
        pass
