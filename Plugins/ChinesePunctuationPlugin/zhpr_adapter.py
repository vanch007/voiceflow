"""
Zhpr Adapter - Primary punctuation restoration library wrapper.

This module provides a clean interface to the zhpr library for fast Chinese
punctuation restoration. Zhpr is the primary choice for speed and simplicity,
supporting 6 types of Chinese punctuation: ，、。？！；
"""

import logging
from typing import Optional

logger = logging.getLogger(__name__)


class ZhprAdapter:
    """
    Adapter for zhpr library - fast Chinese punctuation restoration.

    Zhpr provides simple, rule-based punctuation restoration optimized for
    Chinese text. It's faster than transformer-based models but may have
    lower accuracy for complex sentence boundaries.

    Supported punctuation:
    - ，(comma)
    - 、(enumeration comma)
    - 。(period)
    - ？(question mark)
    - ！(exclamation mark)
    - ；(semicolon)

    Features:
    - Lazy loading via ModelManager
    - Simple API: restore(text) -> punctuated_text
    - Fast processing (no GPU needed)
    - Graceful error handling
    """

    def __init__(self, model_manager):
        """
        Initialize ZhprAdapter with a ModelManager.

        Args:
            model_manager: ModelManager instance for lazy loading zhpr
        """
        self.model_manager = model_manager
        self._zhpr_module = None
        logger.info("ZhprAdapter initialized")

    def restore(self, text: str) -> str:
        """
        Restore punctuation in Chinese text using zhpr.

        This is the main entry point for punctuation restoration. It handles:
        - Empty input validation
        - Lazy loading of zhpr library
        - Error handling with informative logging
        - Non-destructive fallback (returns original on error)

        Args:
            text: Unpunctuated Chinese text

        Returns:
            Text with Chinese punctuation marks added

        Raises:
            ImportError: If zhpr library is not installed
            Exception: For other processing errors (caught and logged)

        Example:
            >>> adapter = ZhprAdapter(model_manager)
            >>> adapter.restore("你好吗我很好谢谢")
            "你好吗？我很好，谢谢。"
        """
        # Validate input
        if not text or not text.strip():
            logger.debug("Empty input received, returning as-is")
            return text

        try:
            # Lazy load zhpr module if not already loaded
            if self._zhpr_module is None:
                logger.info("Loading zhpr library...")
                self._zhpr_module = self.model_manager.get_zhpr()
                logger.info("zhpr library loaded successfully")

            # Process text with zhpr
            logger.debug(f"Restoring punctuation for text ({len(text)} chars)")

            # Call zhpr's restore_punctuation function
            result = self._zhpr_module.restore(text)

            logger.info(f"Punctuation restored successfully ({len(text)} -> {len(result)} chars)")
            return result

        except ImportError as e:
            logger.error(f"zhpr library not available: {e}")
            logger.error("Install with: pip install zhpr")
            raise

        except Exception as e:
            logger.error(f"Error during zhpr punctuation restoration: {e}", exc_info=True)
            logger.warning("Returning original text due to processing error")
            # Non-destructive: return original text on error
            return text

    def is_available(self) -> bool:
        """
        Check if zhpr library is available without loading it.

        This is useful for feature detection and library selection logic.

        Returns:
            bool: True if zhpr can be imported, False otherwise
        """
        return self.model_manager.is_zhpr_available()

    def get_supported_punctuation(self) -> list:
        """
        Get list of punctuation marks supported by zhpr.

        Returns:
            list: Chinese punctuation marks that zhpr can add
        """
        return ["，", "、", "。", "？", "！", "；"]

    def get_info(self) -> dict:
        """
        Get adapter information and status.

        Returns:
            dict: Adapter metadata including library name, status, capabilities
        """
        return {
            "library": "zhpr",
            "loaded": self._zhpr_module is not None,
            "available": self.is_available(),
            "supported_punctuation": self.get_supported_punctuation(),
            "features": {
                "speed": "fast",
                "accuracy": "good",
                "gpu_required": False,
                "model_size": "small",
            },
            "limitations": [
                "Rule-based approach may have lower accuracy than ML models",
                "Limited to 6 types of Chinese punctuation",
                "May struggle with complex sentence boundaries",
            ]
        }


# Convenience function for direct usage
def restore_punctuation(text: str, model_manager) -> str:
    """
    Convenience function for one-off punctuation restoration.

    Args:
        text: Unpunctuated Chinese text
        model_manager: ModelManager instance

    Returns:
        Text with punctuation restored

    Example:
        >>> from model_manager import ModelManager
        >>> from zhpr_adapter import restore_punctuation
        >>> manager = ModelManager()
        >>> restore_punctuation("你好吗我很好", manager)
        "你好吗？我很好。"
    """
    adapter = ZhprAdapter(model_manager)
    return adapter.restore(text)


if __name__ == "__main__":
    # Test the adapter
    import sys
    sys.path.insert(0, str(__file__.rsplit('/', 1)[0]))

    from model_manager import ModelManager

    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )

    # Create adapter
    manager = ModelManager()
    adapter = ZhprAdapter(manager)

    # Check availability
    print(f"Zhpr available: {adapter.is_available()}")
    print(f"Adapter info: {adapter.get_info()}")

    # Test punctuation restoration (will fail if zhpr not installed)
    if adapter.is_available():
        test_text = "你好吗我很好谢谢"
        print(f"\nInput:  {test_text}")

        try:
            result = adapter.restore(test_text)
            print(f"Output: {result}")
        except ImportError:
            print("zhpr not installed - skipping test")
            print("Install with: pip install zhpr")
    else:
        print("\nzhpr library not available - install with: pip install zhpr")
