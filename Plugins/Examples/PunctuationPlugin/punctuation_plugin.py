"""
PunctuationPlugin - Adds smart punctuation to transcribed text

This example plugin demonstrates:
- Python plugin implementation
- Text modification capabilities
- Configuration-based behavior
- Smart text processing logic
"""

import re
from typing import Dict, Any


class VoiceFlowPlugin:
    """
    VoiceFlow Plugin for adding smart punctuation to transcribed text.

    This plugin processes transcribed text and adds appropriate punctuation
    based on speech patterns and context.
    """

    def __init__(self, manifest: Dict[str, Any]):
        """
        Initialize the plugin with its manifest.

        Args:
            manifest: Plugin manifest dictionary containing metadata and configuration
        """
        self.manifest = manifest
        self.plugin_id = manifest['id']
        self.config = manifest.get('configuration', {}).get('defaults', {})
        self.add_periods = self.config.get('addPeriods', True)
        self.capitalize_first = self.config.get('capitalizeFirst', True)

    def on_load(self) -> None:
        """
        Called when the plugin is loaded.
        Initialize any resources needed for punctuation processing.
        """
        # Common sentence-ending patterns (questions, exclamations)
        self.question_patterns = [
            r'\b(what|when|where|who|why|how|which|whose|whom)\b',
            r'\b(is|are|was|were|will|would|could|should|can|do|does|did)\b.*\b(you|he|she|it|they|we)\b',
        ]

        self.exclamation_keywords = [
            'wow', 'amazing', 'incredible', 'awesome', 'terrible', 'horrible',
            'great', 'excellent', 'fantastic', 'wonderful', 'oh no', 'help'
        ]

        print(f"[{self.plugin_id}] Loaded with config: addPeriods={self.add_periods}, capitalizeFirst={self.capitalize_first}")

    def on_transcription(self, text: str) -> str:
        """
        Process transcribed text and add smart punctuation.

        Args:
            text: The raw transcribed text

        Returns:
            The text with added punctuation
        """
        if not text or not text.strip():
            return text

        processed_text = text.strip()

        # Capitalize first letter if enabled
        if self.capitalize_first and processed_text:
            processed_text = processed_text[0].upper() + processed_text[1:]

        # Skip if text already has ending punctuation
        if processed_text and processed_text[-1] in '.!?':
            return processed_text

        # Check for question patterns
        if self._is_question(processed_text):
            processed_text += '?'
        # Check for exclamation patterns
        elif self._is_exclamation(processed_text):
            processed_text += '!'
        # Add period for regular statements
        elif self.add_periods:
            processed_text += '.'

        return processed_text

    def _is_question(self, text: str) -> bool:
        """
        Detect if the text is likely a question.

        Args:
            text: The text to analyze

        Returns:
            True if the text appears to be a question
        """
        text_lower = text.lower()

        # Check for question word patterns
        for pattern in self.question_patterns:
            if re.search(pattern, text_lower):
                return True

        return False

    def _is_exclamation(self, text: str) -> bool:
        """
        Detect if the text should have an exclamation mark.

        Args:
            text: The text to analyze

        Returns:
            True if the text appears to be an exclamation
        """
        text_lower = text.lower()

        # Check for exclamation keywords
        for keyword in self.exclamation_keywords:
            if keyword in text_lower:
                return True

        return False

    def on_unload(self) -> None:
        """
        Called when the plugin is unloaded.
        Clean up any resources.
        """
        print(f"[{self.plugin_id}] Unloaded")
