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
            # Lazy load model manager and adapters on first use
            if self._model_manager is None:
                logger.info("Lazy loading model manager...")
                from .model_manager import ModelManager
                self._model_manager = ModelManager()
                logger.info("Model manager loaded successfully")

            # Determine primary and fallback libraries based on configuration
            primary_library = self.library
            fallback_library = "transformers" if primary_library == "zhpr" else "zhpr"

            logger.info(f"Using library strategy: primary={primary_library}, fallback={fallback_library}")

            # Try primary library first
            result = self._try_library(text, primary_library)
            if result is not None:
                logger.info(f"Successfully processed with {primary_library}")
                return result

            # Primary library failed, try fallback
            logger.warning(f"{primary_library} failed, trying fallback: {fallback_library}")
            result = self._try_library(text, fallback_library)
            if result is not None:
                logger.info(f"Successfully processed with fallback {fallback_library}")
                return result

            # Both libraries failed - return original text (non-destructive)
            logger.error("Both libraries failed, returning original text")
            return text

        except Exception as e:
            logger.error(f"Error processing text: {e}", exc_info=True)
            # Non-destructive: return original text on any error
            return text

    def _try_library(self, text: str, library: str) -> Optional[str]:
        """
        Try to restore punctuation using the specified library.

        Args:
            text: Unpunctuated Chinese text
            library: Library name ('zhpr' or 'transformers')

        Returns:
            Punctuated text if successful, None if library failed/unavailable

        This method handles:
        - Lazy loading of adapters
        - Library availability checking
        - Error handling with non-destructive fallback
        """
        try:
            if library == "zhpr":
                # Lazy load zhpr adapter
                if self._zhpr_adapter is None:
                    logger.info("Lazy loading zhpr adapter...")
                    from .zhpr_adapter import ZhprAdapter
                    self._zhpr_adapter = ZhprAdapter(self._model_manager)
                    logger.info("Zhpr adapter loaded successfully")

                # Check availability before attempting
                if not self._zhpr_adapter.is_available():
                    logger.warning("zhpr library not available")
                    return None

                # Process text
                logger.debug("Attempting punctuation restoration with zhpr...")
                result = self._zhpr_adapter.restore(text)
                return result

            elif library == "transformers":
                # Lazy load transformers adapter
                if self._transformers_adapter is None:
                    logger.info("Lazy loading transformers adapter...")
                    from .transformers_adapter import TransformersAdapter
                    self._transformers_adapter = TransformersAdapter(self._model_manager)
                    logger.info("Transformers adapter loaded successfully")

                # Check availability before attempting
                if not self._transformers_adapter.is_available():
                    logger.warning("transformers library not available")
                    return None

                # Process text
                logger.debug("Attempting punctuation restoration with transformers...")
                result = self._transformers_adapter.restore(text)
                return result

            else:
                logger.error(f"Unknown library: {library}")
                return None

        except ImportError as e:
            logger.warning(f"Library {library} not available: {e}")
            return None

        except Exception as e:
            logger.error(f"Error using {library}: {e}", exc_info=True)
            return None

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
