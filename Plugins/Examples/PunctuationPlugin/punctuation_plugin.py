#!/usr/bin/env python3
"""PunctuationPlugin - Example VoiceFlow plugin that adds punctuation to transcribed text."""

import logging
import re
import sys
from pathlib import Path

# Add server directory to Python path for imports
server_path = Path(__file__).resolve().parent.parent.parent.parent / "server"
sys.path.insert(0, str(server_path))

from plugin_api import VoiceFlowPlugin, PluginManifest, PluginError

logger = logging.getLogger(__name__)


class PunctuationPlugin(VoiceFlowPlugin):
    """
    Example plugin that intelligently adds punctuation to transcribed text.

    This plugin demonstrates:
    - Implementing the VoiceFlowPlugin protocol
    - Using async lifecycle hooks
    - Text transformation with pattern matching
    - Error handling
    """

    def __init__(self, manifest: PluginManifest):
        """Initialize the punctuation plugin."""
        super().__init__(manifest)
        self._enabled = False

    async def on_load(self) -> None:
        """
        Called when the plugin is loaded.
        Initialize any resources needed by the plugin.
        """
        logger.info(f"[{self.plugin_id}] Loading PunctuationPlugin v{self.manifest.version}")
        self._enabled = True
        logger.info(f"[{self.plugin_id}] PunctuationPlugin loaded successfully")

    async def on_transcription(self, text: str) -> str:
        """
        Process transcribed text by adding appropriate punctuation.

        Rules:
        - Add period to end if no punctuation exists
        - Capitalize first letter
        - Handle question patterns (what, where, when, who, why, how)
        - Preserve existing punctuation

        Args:
            text: The transcribed text from the ASR system

        Returns:
            The text with appropriate punctuation added

        Raises:
            PluginError: If text processing fails
        """
        if not self._enabled:
            return text

        try:
            # Strip whitespace
            processed = text.strip()

            if not processed:
                return text

            # Capitalize first letter
            processed = processed[0].upper() + processed[1:] if len(processed) > 1 else processed.upper()

            # Check if text already ends with punctuation
            if processed[-1] in {'.', '!', '?', ',', ';', ':'}:
                return processed

            # Detect question patterns
            question_words = {'what', 'where', 'when', 'who', 'why', 'how', 'which', 'whose', 'whom'}
            first_word = processed.split()[0].lower() if processed.split() else ''

            # Add question mark for questions, period otherwise
            if first_word in question_words:
                processed += '?'
            else:
                processed += '.'

            logger.debug(f"[{self.plugin_id}] Transformed: '{text}' -> '{processed}'")
            return processed

        except Exception as e:
            error_msg = f"Failed to process text: {str(e)}"
            logger.error(f"[{self.plugin_id}] {error_msg}")
            raise PluginError(error_msg) from e

    async def on_unload(self) -> None:
        """
        Called when the plugin is unloaded.
        Clean up any resources used by the plugin.
        """
        logger.info(f"[{self.plugin_id}] Unloading PunctuationPlugin")
        self._enabled = False
        logger.info(f"[{self.plugin_id}] PunctuationPlugin unloaded successfully")
