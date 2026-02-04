#!/usr/bin/env python3
"""VoiceFlow Plugin Loader - Dynamic Python plugin loading and lifecycle management."""

import importlib.util
import json
import logging
from pathlib import Path
from typing import Optional

from plugin_api import (
    LoadFailedError,
    ManifestInvalidError,
    PluginInfo,
    PluginManifest,
    PluginState,
    VoiceFlowPlugin,
)

logger = logging.getLogger(__name__)


class PluginLoader:
    """
    Manages dynamic loading and lifecycle of VoiceFlow Python plugins.

    Discovers plugins from the plugins directory, validates manifests,
    and instantiates plugin classes using importlib.
    """

    def __init__(self, plugins_dir: Optional[Path] = None):
        """
        Initialize the plugin loader.

        Args:
            plugins_dir: Directory to scan for plugins. Defaults to ~/Library/Application Support/VoiceFlow/Plugins
        """
        if plugins_dir is None:
            home = Path.home()
            self.plugins_dir = home / "Library" / "Application Support" / "VoiceFlow" / "Plugins"
        else:
            self.plugins_dir = Path(plugins_dir)

        self.loaded_plugins: dict[str, PluginInfo] = {}
        logger.info(f"PluginLoader initialized with directory: {self.plugins_dir}")

    def discover_plugins(self) -> list[Path]:
        """
        Scan the plugins directory for valid plugin manifests.

        Returns:
            List of paths to plugin directories containing manifest.json files

        Raises:
            OSError: If plugins directory is not accessible
        """
        if not self.plugins_dir.exists():
            logger.warning(f"Plugins directory does not exist: {self.plugins_dir}")
            return []

        plugin_dirs = []
        for item in self.plugins_dir.iterdir():
            if item.is_dir():
                manifest_path = item / "manifest.json"
                if manifest_path.exists():
                    plugin_dirs.append(item)
                    logger.debug(f"Discovered plugin: {item.name}")

        logger.info(f"Discovered {len(plugin_dirs)} plugin(s)")
        return plugin_dirs

    def load_manifest(self, plugin_dir: Path) -> PluginManifest:
        """
        Load and validate plugin manifest from directory.

        Args:
            plugin_dir: Path to plugin directory containing manifest.json

        Returns:
            Validated PluginManifest object

        Raises:
            ManifestInvalidError: If manifest is missing, malformed, or invalid
        """
        manifest_path = plugin_dir / "manifest.json"

        try:
            with open(manifest_path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except FileNotFoundError as e:
            raise ManifestInvalidError(f"Manifest not found: {manifest_path}") from e
        except json.JSONDecodeError as e:
            raise ManifestInvalidError(f"Invalid JSON in manifest: {manifest_path}") from e

        # Validate required fields
        required_fields = ["id", "name", "version", "author", "description", "entrypoint"]
        missing_fields = [field for field in required_fields if field not in data]
        if missing_fields:
            raise ManifestInvalidError(
                f"Missing required fields in manifest: {', '.join(missing_fields)}"
            )

        try:
            manifest = PluginManifest.from_dict(data)
            logger.debug(f"Loaded manifest for plugin: {manifest.id} v{manifest.version}")
            return manifest
        except (KeyError, ValueError, TypeError) as e:
            raise ManifestInvalidError(f"Invalid manifest data: {e}") from e

    async def load_plugin(self, plugin_dir: Path) -> PluginInfo:
        """
        Load a plugin from the specified directory.

        Args:
            plugin_dir: Path to plugin directory

        Returns:
            PluginInfo object containing loaded plugin instance

        Raises:
            LoadFailedError: If plugin loading fails
            ManifestInvalidError: If manifest is invalid
        """
        try:
            # Load and validate manifest
            manifest = self.load_manifest(plugin_dir)

            # Check if plugin is for Python platform
            if manifest.platform.value not in ["python", "both"]:
                raise LoadFailedError(
                    f"Plugin {manifest.id} is not a Python plugin (platform: {manifest.platform.value})"
                )

            # Construct path to plugin module
            entrypoint = manifest.entrypoint
            if not entrypoint.endswith(".py"):
                entrypoint = f"{entrypoint}.py"

            module_path = plugin_dir / entrypoint

            if not module_path.exists():
                raise LoadFailedError(
                    f"Plugin entrypoint not found: {module_path}"
                )

            # Load module dynamically using importlib
            module_name = f"voiceflow_plugin_{manifest.id}"
            spec = importlib.util.spec_from_file_location(module_name, module_path)
            if spec is None or spec.loader is None:
                raise LoadFailedError(
                    f"Failed to create module spec for: {module_path}"
                )

            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)

            # Find VoiceFlowPlugin subclass in module
            plugin_class = None
            for attr_name in dir(module):
                attr = getattr(module, attr_name)
                if (
                    isinstance(attr, type)
                    and issubclass(attr, VoiceFlowPlugin)
                    and attr is not VoiceFlowPlugin
                ):
                    plugin_class = attr
                    break

            if plugin_class is None:
                raise LoadFailedError(
                    f"No VoiceFlowPlugin subclass found in {entrypoint}"
                )

            # Instantiate plugin
            plugin_instance = plugin_class(manifest)

            # Call on_load hook
            await plugin_instance.on_load()

            # Create PluginInfo
            plugin_info = PluginInfo(
                manifest=manifest,
                state=PluginState.LOADED,
                plugin=plugin_instance,
                error=None,
            )

            # Store in loaded plugins
            self.loaded_plugins[manifest.id] = plugin_info

            logger.info(f"Plugin loaded successfully: {manifest.name} v{manifest.version}")
            return plugin_info

        except (ManifestInvalidError, LoadFailedError):
            raise
        except Exception as e:
            error_msg = f"Unexpected error loading plugin from {plugin_dir}: {e}"
            logger.error(error_msg)
            raise LoadFailedError(error_msg) from e

    async def unload_plugin(self, plugin_id: str) -> None:
        """
        Unload a plugin and clean up resources.

        Args:
            plugin_id: Unique identifier of the plugin to unload

        Raises:
            ValueError: If plugin is not loaded
        """
        if plugin_id not in self.loaded_plugins:
            raise ValueError(f"Plugin not loaded: {plugin_id}")

        plugin_info = self.loaded_plugins[plugin_id]

        try:
            if plugin_info.plugin is not None:
                await plugin_info.plugin.on_unload()
            del self.loaded_plugins[plugin_id]
            logger.info(f"Plugin unloaded: {plugin_id}")
        except Exception as e:
            logger.error(f"Error unloading plugin {plugin_id}: {e}")
            raise

    async def load_all_plugins(self) -> list[PluginInfo]:
        """
        Discover and load all plugins from the plugins directory.

        Returns:
            List of successfully loaded PluginInfo objects
        """
        plugin_dirs = self.discover_plugins()
        loaded = []

        for plugin_dir in plugin_dirs:
            try:
                plugin_info = await self.load_plugin(plugin_dir)
                loaded.append(plugin_info)
            except (ManifestInvalidError, LoadFailedError) as e:
                logger.warning(f"Failed to load plugin from {plugin_dir.name}: {e}")
                continue

        logger.info(f"Loaded {len(loaded)}/{len(plugin_dirs)} plugin(s)")
        return loaded

    async def process_text(self, text: str) -> str:
        """
        Process text through all enabled plugins.

        Args:
            text: Input text to process

        Returns:
            Processed text after passing through all enabled plugins
        """
        processed_text = text

        for plugin_id, plugin_info in self.loaded_plugins.items():
            if plugin_info.is_enabled and plugin_info.plugin is not None:
                try:
                    processed_text = await plugin_info.plugin.on_transcription(processed_text)
                    logger.debug(f"Plugin {plugin_id} processed text")
                except Exception as e:
                    logger.error(f"Plugin {plugin_id} failed to process text: {e}")
                    plugin_info.state = PluginState.FAILED
                    plugin_info.error = e

        return processed_text

    def get_plugin(self, plugin_id: str) -> Optional[PluginInfo]:
        """
        Get plugin info by ID.

        Args:
            plugin_id: Unique identifier of the plugin

        Returns:
            PluginInfo if found, None otherwise
        """
        return self.loaded_plugins.get(plugin_id)

    def list_plugins(self) -> list[PluginInfo]:
        """
        Get list of all loaded plugins.

        Returns:
            List of PluginInfo objects
        """
        return list(self.loaded_plugins.values())
