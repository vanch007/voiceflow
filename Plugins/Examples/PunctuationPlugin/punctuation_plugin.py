#!/usr/bin/env python3
"""
PunctuationPlugin - Example plugin that adds punctuation to transcribed text.

This plugin demonstrates how to create a VoiceFlow plugin that processes
transcription text by adding basic punctuation using simple heuristics.
"""

import logging
import re
from typing import Optional

import sys
from pathlib import Path

# Add server directory to Python path for imports
server_path = Path(__file__).parent.parent.parent.parent / "server"
sys.path.insert(0, str(server_path))

from plugin_api import VoiceFlowPlugin, PluginManifest, PluginError

logger = logging.getLogger(__name__)


class PunctuationPlugin(VoiceFlowPlugin):
    """
    Adds basic punctuation to transcribed text.

    This plugin applies simple heuristics to add periods, question marks,
    and commas to text that lacks punctuation. Useful for improving
    readability of raw ASR output.
    """

    def __init__(self, manifest: PluginManifest):
        """Initialize the punctuation plugin."""
        super().__init__(manifest)
        self._enabled = False

    async def on_load(self) -> None:
        """
        Called when the plugin is loaded.

        Initializes the plugin and prepares it for processing.
        """
        logger.info(f"Loading {self.manifest.name} v{self.manifest.version}")
        self._enabled = True
        logger.info("PunctuationPlugin loaded successfully")

    async def on_transcription(self, text: str) -> str:
        """
        Process transcription text by adding punctuation.

        Applies the following heuristics:
        - Capitalize first letter of sentences
        - Add periods at the end if missing
        - Add question marks for sentences starting with question words
        - Add commas after common transitional phrases

        Args:
            text: The transcribed text from the ASR system

        Returns:
            The text with added punctuation

        Raises:
            PluginError: If text processing fails
        """
        if not self._enabled:
            raise PluginError("Plugin is not enabled")

        if not text or not text.strip():
            return text

        try:
            processed_text = self._add_punctuation(text.strip())
            logger.debug(f"Processed text: '{text}' -> '{processed_text}'")
            return processed_text
        except Exception as e:
            logger.error(f"Failed to process text: {e}")
            raise PluginError(f"Text processing failed: {e}")

    async def on_unload(self) -> None:
        """
        Called when the plugin is unloaded.

        Performs cleanup and releases resources.
        """
        logger.info(f"Unloading {self.manifest.name}")
        self._enabled = False
        logger.info("PunctuationPlugin unloaded successfully")

    def _add_punctuation(self, text: str) -> str:
        """
        Apply punctuation heuristics to text.

        Args:
            text: Input text without punctuation

        Returns:
            Text with added punctuation
        """
        # Capitalize first letter
        if text:
            text = text[0].upper() + text[1:]

        # Question words for detecting questions
        question_words = [
            "what",
            "when",
            "where",
            "who",
            "whom",
            "whose",
            "why",
            "which",
            "how",
            "can",
            "could",
            "would",
            "should",
            "is",
            "are",
            "do",
            "does",
            "did",
        ]

        # Check if it's a question
        first_word = text.split()[0].lower() if text.split() else ""
        is_question = first_word in question_words

        # Add comma after transitional phrases
        transitional_phrases = [
            "however",
            "therefore",
            "moreover",
            "furthermore",
            "meanwhile",
            "consequently",
            "nevertheless",
            "thus",
            "hence",
            "indeed",
            "besides",
            "otherwise",
        ]

        for phrase in transitional_phrases:
            # Add comma after phrase at start of sentence
            pattern = rf"\b{phrase}\b(?!,)"
            replacement = f"{phrase},"
            text = re.sub(pattern, replacement, text, count=1, flags=re.IGNORECASE)

        # Add ending punctuation if missing
        if not text[-1] in ".!?":
            text = text + ("?" if is_question else ".")

        return text
