"""
Template plugin for VoiceFlow
Replace this docstring with a description of what your plugin does
"""

import logging


class VoiceFlowPlugin:
    """
    Base class for VoiceFlow Python plugins.

    All Python plugins must inherit from this class and implement
    the lifecycle methods.
    """

    def __init__(self, manifest: dict):
        """
        Initialize plugin with manifest data.

        Args:
            manifest (dict): Parsed manifest.json data
        """
        self.manifest = manifest
        self.plugin_id = manifest['id']

        # Configuration properties
        self.example_setting = None
        self.enabled = True

        # Set up logging
        self.logger = logging.getLogger(self.plugin_id)

    def on_load(self):
        """
        Called when plugin is loaded and enabled.

        Use this for initialization:
        - Load configuration
        - Initialize resources
        - Set up caches
        - Load ML models
        """
        # Extract configuration from manifest
        config = self.manifest.get('configuration', {}).get('defaults', {})
        self.example_setting = config.get('exampleSetting', 'default value')
        self.enabled = config.get('enabled', True)

        self.logger.info(
            f"Plugin loaded with exampleSetting: {self.example_setting}, "
            f"enabled: {self.enabled}"
        )

    def on_transcription(self, text: str) -> str:
        """
        Process transcribed text.

        Args:
            text (str): Input text from ASR or previous plugin

        Returns:
            str: Transformed text or original if no changes
        """
        # Return early if plugin is disabled
        if not self.enabled:
            return text

        # TODO: Implement your plugin logic here
        # This template simply returns the text unchanged
        # Example modifications you could make:
        # - Transform the text (uppercase, lowercase, title case, etc.)
        # - Add prefixes or suffixes
        # - Filter or replace certain words
        # - Send data to external services
        # - Store data locally

        self.logger.debug(
            f"Processing transcription: {text[:50]}{'...' if len(text) > 50 else ''}"
        )

        # Return the original text (replace this with your logic)
        return text

    def on_unload(self):
        """
        Called when plugin is disabled or unloaded.

        Use this for cleanup:
        - Close connections
        - Save state
        - Free resources
        """
        # Clean up any resources here
        # Examples:
        # - Close network connections
        # - Save state to disk
        # - Cancel pending operations
        # - Release allocated resources

        self.logger.info("Plugin unloaded and cleaned up")
