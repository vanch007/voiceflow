#!/usr/bin/env python3
"""
ChinesePunctuationPlugin - Automatic Chinese punctuation restoration for VoiceFlow.

This plugin implements ML-based punctuation restoration for transcribed Chinese text,
using either zhpr (fast) or transformers (accurate) libraries with automatic fallback.
"""

import logging
from typing import Dict, Any, Optional
from pathlib import Path
import json


logger = logging.getLogger(__name__)


class VoiceFlowPlugin:
    """Base protocol for VoiceFlow plugins.

    All plugins must implement this interface to integrate with the VoiceFlow system.
    """

    def initialize(self, config: Dict[str, Any]) -> None:
        """Initialize the plugin with configuration."""
        raise NotImplementedError

    def on_transcription(self, text: str) -> str:
        """Process transcribed text and return modified version."""
        raise NotImplementedError

    def cleanup(self) -> None:
        """Cleanup resources before plugin shutdown."""
        raise NotImplementedError


class ChinesePunctuationPlugin(VoiceFlowPlugin):
    """
    Automatic Chinese punctuation restoration plugin.

    This plugin adds punctuation marks (，、。？！；) to unpunctuated Chinese text
    using ML-based models. Supports dual-library architecture with zhpr (primary)
    and transformers (fallback) for optimal balance of speed and accuracy.

    Features:
    - Intelligent sentence boundary detection
    - GPU acceleration when available
    - Configurable library selection (zhpr/transformers)
    - Lazy model loading for fast startup
    - Graceful error handling and fallback

    Configuration:
    - auto_punctuation: Enable/disable feature (default: true)
    - library: Choose 'zhpr' or 'transformers' (default: 'zhpr')
    - device: 'auto', 'cpu', or 'cuda' (default: 'auto')
    """

    def __init__(self):
        """Initialize plugin instance."""
        self.config: Dict[str, Any] = {}
        self.enabled: bool = True
        self.library: str = "zhpr"
        self.device: str = "auto"
        self._initialized: bool = False

        # Model managers (lazy loaded)
        self._zhpr_adapter = None
        self._transformers_adapter = None
        self._model_manager = None

        logger.info("ChinesePunctuationPlugin instance created")

    def initialize(self, config: Dict[str, Any]) -> None:
        """
        Initialize the plugin with configuration.

        Args:
            config: Configuration dictionary with keys:
                - auto_punctuation (bool): Enable/disable plugin
                - library (str): 'zhpr' or 'transformers'
                - device (str): 'auto', 'cpu', or 'cuda'

        Raises:
            ValueError: If configuration is invalid
        """
        logger.info("Initializing ChinesePunctuationPlugin...")

        # Store configuration
        self.config = config

        # Load configuration settings
        self.enabled = config.get("auto_punctuation", True)
        self.library = config.get("library", "zhpr")
        self.device = config.get("device", "auto")

        # Validate configuration
        if self.library not in ["zhpr", "transformers"]:
            raise ValueError(f"Invalid library: {self.library}. Must be 'zhpr' or 'transformers'")

        if self.device not in ["auto", "cpu", "cuda"]:
            raise ValueError(f"Invalid device: {self.device}. Must be 'auto', 'cpu', or 'cuda'")

        logger.info(f"Configuration: enabled={self.enabled}, library={self.library}, device={self.device}")

        # Note: Models are lazy-loaded on first use for faster startup
        self._initialized = True
        logger.info("ChinesePunctuationPlugin initialized successfully")

    def on_transcription(self, text: str) -> str:
        """
        Process transcribed text and add Chinese punctuation.

        This is the main entry point called by VoiceFlow after transcription.
        Implements dual-library fallback strategy for reliability.

        Args:
            text: Unpunctuated Chinese text from transcription

        Returns:
            Text with punctuation marks added

        Processing flow:
        1. Check if plugin is enabled
        2. Validate input (non-empty, contains Chinese)
        3. Try primary library (zhpr by default)
        4. On failure, try fallback library (transformers)
        5. On all failures, return original text (non-destructive)
        """
        # Short-circuit if plugin disabled
        if not self.enabled:
            logger.debug("Plugin disabled, returning original text")
            return text

        if not self._initialized:
            logger.warning("Plugin not initialized, returning original text")
            return text

        # Validate input
        if not text or not text.strip():
            logger.debug("Empty input, returning as-is")
            return text

        logger.info(f"Processing text ({len(text)} chars): {text[:50]}...")

        try:
            # TODO: Implement actual punctuation restoration in Phase 3
            # For now, just return the original text
            # This will be wired up with model adapters in subtask-3-1
            logger.warning("Punctuation restoration not yet implemented (pending Phase 2 and 3)")
            return text

        except Exception as e:
            logger.error(f"Error processing text: {e}", exc_info=True)
            # Non-destructive: return original text on any error
            return text

    def cleanup(self) -> None:
        """
        Cleanup resources before plugin shutdown.

        Unloads models from memory and releases GPU resources.
        """
        logger.info("Cleaning up ChinesePunctuationPlugin...")

        # Cleanup model adapters if loaded
        if self._zhpr_adapter is not None:
            logger.debug("Cleaning up zhpr adapter")
            self._zhpr_adapter = None

        if self._transformers_adapter is not None:
            logger.debug("Cleaning up transformers adapter")
            self._transformers_adapter = None

        if self._model_manager is not None:
            logger.debug("Cleaning up model manager")
            self._model_manager = None

        self._initialized = False
        logger.info("ChinesePunctuationPlugin cleanup complete")

    def get_info(self) -> Dict[str, Any]:
        """
        Get plugin information and status.

        Returns:
            Dictionary with plugin metadata and current status
        """
        return {
            "name": "ChinesePunctuationPlugin",
            "version": "1.0.0",
            "initialized": self._initialized,
            "enabled": self.enabled,
            "library": self.library,
            "device": self.device,
            "supported_punctuation": ["，", "、", "。", "？", "！", "；"],
            "features": {
                "gpu_acceleration": self.device != "cpu",
                "lazy_loading": True,
                "dual_library": True
            }
        }


# Module-level helper for loading plugin manifest
def load_manifest() -> Dict[str, Any]:
    """Load plugin manifest.json from the same directory."""
    manifest_path = Path(__file__).parent / "manifest.json"

    if not manifest_path.exists():
        raise FileNotFoundError(f"Manifest not found: {manifest_path}")

    with open(manifest_path, 'r', encoding='utf-8') as f:
        return json.load(f)


if __name__ == "__main__":
    # Test basic plugin functionality
    logging.basicConfig(level=logging.INFO)

    plugin = ChinesePunctuationPlugin()
    manifest = load_manifest()

    # Initialize with default config from manifest
    config = {
        "auto_punctuation": manifest["configuration"]["auto_punctuation"]["default"],
        "library": manifest["configuration"]["library"]["default"],
        "device": manifest["configuration"]["device"]["default"]
    }

    plugin.initialize(config)

    # Test with sample text
    sample_text = "你好吗我很好谢谢"
    result = plugin.on_transcription(sample_text)

    print(f"Input:  {sample_text}")
    print(f"Output: {result}")
    print(f"Plugin Info: {plugin.get_info()}")

    plugin.cleanup()
