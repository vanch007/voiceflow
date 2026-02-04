"""
Model Manager for Chinese Punctuation Restoration Plugin

Handles lazy loading of ML models, GPU detection, and model caching.
Supports both zhpr (primary) and transformers (fallback) libraries.
"""

import logging
from typing import Optional, Any

logger = logging.getLogger(__name__)


class ModelManager:
    """
    Manages ML model loading with lazy initialization and device optimization.

    Features:
    - Lazy loading: Models loaded only when needed
    - GPU detection: Automatically detects and uses CUDA if available
    - Model caching: Loaded models cached in memory for reuse
    - Graceful fallback: Falls back to CPU if GPU unavailable
    """

    def __init__(self):
        """Initialize ModelManager with lazy loading flags."""
        self._zhpr_loaded = False
        self._zhpr_module = None
        self._transformers_model = None
        self._transformers_tokenizer = None
        self._device = None

        logger.info("ModelManager initialized with lazy loading")

    def get_device(self) -> str:
        """
        Detect and return the optimal compute device (GPU or CPU).

        Returns:
            str: "cuda" if GPU available, "cpu" otherwise
        """
        if self._device is not None:
            return self._device

        try:
            import torch
            if torch.cuda.is_available():
                self._device = "cuda"
                logger.info("GPU detected - using CUDA acceleration")
            else:
                self._device = "cpu"
                logger.info("GPU not available - using CPU")
        except ImportError:
            # If torch not available, default to CPU
            self._device = "cpu"
            logger.warning("PyTorch not installed - defaulting to CPU")

        return self._device

    def get_zhpr(self) -> Any:
        """
        Lazy load and return the zhpr module.

        Returns:
            module: The zhpr module for punctuation restoration

        Raises:
            ImportError: If zhpr library is not installed
        """
        if not self._zhpr_loaded:
            try:
                import zhpr
                self._zhpr_module = zhpr
                self._zhpr_loaded = True
                logger.info("zhpr library loaded successfully")
            except ImportError as e:
                logger.error(f"Failed to import zhpr: {e}")
                raise ImportError(
                    "zhpr library not installed. Install with: pip install zhpr"
                ) from e

        return self._zhpr_module

    def get_transformers_model(self, model_name: str = "p208p2002/zh-wiki-punctuation-restore"):
        """
        Lazy load and return the Hugging Face transformers model with tokenizer.

        Args:
            model_name: Name of the HuggingFace model to load

        Returns:
            tuple: (model, tokenizer) for punctuation restoration

        Raises:
            ImportError: If transformers library is not installed
            Exception: If model loading fails
        """
        if self._transformers_model is None:
            try:
                from transformers import AutoModelForTokenClassification, AutoTokenizer

                logger.info(f"Loading transformers model: {model_name}")

                # Load model and tokenizer
                tokenizer = AutoTokenizer.from_pretrained(model_name)
                model = AutoModelForTokenClassification.from_pretrained(model_name)

                # Move model to appropriate device
                device = self.get_device()
                if device == "cuda":
                    try:
                        import torch
                        model = model.to(torch.device("cuda"))
                        logger.info("Model moved to GPU")
                    except Exception as e:
                        logger.warning(f"Failed to move model to GPU: {e}. Using CPU.")

                self._transformers_model = model
                self._transformers_tokenizer = tokenizer

                logger.info("Transformers model loaded and cached successfully")

            except ImportError as e:
                logger.error(f"Failed to import transformers: {e}")
                raise ImportError(
                    "transformers library not installed. Install with: pip install transformers"
                ) from e
            except Exception as e:
                logger.error(f"Failed to load transformers model: {e}")
                raise

        return self._transformers_model, self._transformers_tokenizer

    def unload_models(self):
        """
        Unload all cached models to free memory.
        Useful for cleanup or memory management.
        """
        if self._transformers_model is not None:
            try:
                import torch
                del self._transformers_model
                del self._transformers_tokenizer
                if torch.cuda.is_available():
                    torch.cuda.empty_cache()
                logger.info("Transformers model unloaded and GPU cache cleared")
            except Exception as e:
                logger.warning(f"Error during model cleanup: {e}")

        self._transformers_model = None
        self._transformers_tokenizer = None
        self._zhpr_module = None
        self._zhpr_loaded = False

        logger.info("All models unloaded from cache")

    def is_zhpr_available(self) -> bool:
        """
        Check if zhpr library is available without loading it.

        Returns:
            bool: True if zhpr can be imported, False otherwise
        """
        try:
            import zhpr
            return True
        except ImportError:
            return False

    def is_transformers_available(self) -> bool:
        """
        Check if transformers library is available without loading models.

        Returns:
            bool: True if transformers can be imported, False otherwise
        """
        try:
            import transformers
            return True
        except ImportError:
            return False
