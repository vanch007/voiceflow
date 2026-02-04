"""
Transformers Adapter - Fallback punctuation restoration library wrapper.

This module provides a clean interface to Hugging Face transformers library
for Chinese punctuation restoration. This is the fallback option when zhpr
is unavailable or when higher accuracy is needed.

Uses model: p208p2002/zh-wiki-punctuation-restore
"""

import logging
from typing import Optional, List, Tuple

logger = logging.getLogger(__name__)


class TransformersAdapter:
    """
    Adapter for Hugging Face transformers - accurate Chinese punctuation restoration.

    This adapter uses a token classification model to predict punctuation marks
    for Chinese text. It provides better accuracy than rule-based approaches
    but requires more computational resources.

    Supported punctuation:
    - ，(comma)
    - 。(period)
    - ？(question mark)
    - ！(exclamation mark)
    - ；(semicolon)
    - ：(colon)

    Features:
    - Lazy loading via ModelManager
    - GPU acceleration support
    - Higher accuracy than rule-based methods
    - Token-level punctuation prediction
    """

    # Model configuration
    DEFAULT_MODEL = "p208p2002/zh-wiki-punctuation-restore"

    # Punctuation label mapping (common for Chinese punctuation models)
    LABEL_MAP = {
        0: "",      # No punctuation
        1: "，",    # Comma
        2: "。",    # Period
        3: "？",    # Question mark
        4: "！",    # Exclamation mark
        5: "；",    # Semicolon
        6: "：",    # Colon
    }

    def __init__(self, model_manager, model_name: str = None):
        """
        Initialize TransformersAdapter with a ModelManager.

        Args:
            model_manager: ModelManager instance for lazy loading transformers
            model_name: Optional custom model name (defaults to DEFAULT_MODEL)
        """
        self.model_manager = model_manager
        self.model_name = model_name or self.DEFAULT_MODEL
        self._model = None
        self._tokenizer = None
        logger.info(f"TransformersAdapter initialized with model: {self.model_name}")

    def restore(self, text: str) -> str:
        """
        Restore punctuation in Chinese text using transformers model.

        This method:
        - Validates input
        - Lazy loads the model and tokenizer
        - Tokenizes the input text
        - Runs inference to predict punctuation
        - Reconstructs the text with punctuation marks
        - Handles errors gracefully

        Args:
            text: Unpunctuated Chinese text

        Returns:
            Text with Chinese punctuation marks added

        Raises:
            ImportError: If transformers library is not installed
            Exception: For other processing errors (caught and logged)

        Example:
            >>> adapter = TransformersAdapter(model_manager)
            >>> adapter.restore("你好吗我很好谢谢")
            "你好吗？我很好，谢谢。"
        """
        # Validate input
        if not text or not text.strip():
            logger.debug("Empty input received, returning as-is")
            return text

        try:
            # Lazy load model and tokenizer if not already loaded
            if self._model is None or self._tokenizer is None:
                logger.info("Loading transformers model and tokenizer...")
                self._model, self._tokenizer = self.model_manager.get_transformers_model(
                    self.model_name
                )
                logger.info("Transformers model loaded successfully")

            # Process text with transformers
            logger.debug(f"Restoring punctuation for text ({len(text)} chars)")

            # Tokenize input
            inputs = self._tokenizer(
                text,
                return_tensors="pt",
                truncation=True,
                max_length=512,
                padding=True
            )

            # Move inputs to same device as model
            device = self.model_manager.get_device()
            if device == "cuda":
                try:
                    import torch
                    inputs = {k: v.to(torch.device("cuda")) for k, v in inputs.items()}
                except Exception as e:
                    logger.warning(f"Failed to move inputs to GPU: {e}")

            # Run inference
            import torch
            with torch.no_grad():
                outputs = self._model(**inputs)
                predictions = torch.argmax(outputs.logits, dim=-1)

            # Reconstruct text with punctuation
            result = self._reconstruct_text(text, predictions[0], inputs)

            logger.info(f"Punctuation restored successfully ({len(text)} -> {len(result)} chars)")
            return result

        except ImportError as e:
            logger.error(f"transformers library not available: {e}")
            logger.error("Install with: pip install transformers torch")
            raise

        except Exception as e:
            logger.error(f"Error during transformers punctuation restoration: {e}", exc_info=True)
            logger.warning("Returning original text due to processing error")
            # Non-destructive: return original text on error
            return text

    def _reconstruct_text(self, original_text: str, predictions, inputs) -> str:
        """
        Reconstruct text with punctuation marks based on model predictions.

        This handles the token-to-character alignment and inserts punctuation
        marks at the appropriate positions.

        Args:
            original_text: Original unpunctuated text
            predictions: Model predictions (tensor of label IDs)
            inputs: Tokenizer inputs with special tokens

        Returns:
            Text with punctuation marks inserted
        """
        try:
            # Convert predictions to list
            pred_list = predictions.tolist() if hasattr(predictions, 'tolist') else predictions

            # Decode tokens to get character-level alignment
            tokens = self._tokenizer.convert_ids_to_tokens(inputs['input_ids'][0])

            # Build result character by character
            result = []
            char_idx = 0

            for i, (token, pred_label) in enumerate(zip(tokens, pred_list)):
                # Skip special tokens
                if token in ['[CLS]', '[SEP]', '[PAD]', '<s>', '</s>', '<pad>']:
                    continue

                # Remove tokenizer prefix (e.g., '##' in BERT)
                clean_token = token.replace('##', '')

                # Add the character(s) from original text
                if char_idx < len(original_text):
                    if clean_token.strip():  # Only for non-empty tokens
                        result.append(original_text[char_idx])
                        char_idx += 1

                    # Add punctuation if predicted
                    if pred_label in self.LABEL_MAP and self.LABEL_MAP[pred_label]:
                        result.append(self.LABEL_MAP[pred_label])

            # Add any remaining characters
            if char_idx < len(original_text):
                result.append(original_text[char_idx:])

            return ''.join(result)

        except Exception as e:
            logger.error(f"Error reconstructing text: {e}", exc_info=True)
            logger.warning("Falling back to simple character-based reconstruction")

            # Fallback: simple reconstruction
            return self._simple_reconstruction(original_text, predictions)

    def _simple_reconstruction(self, text: str, predictions) -> str:
        """
        Simple fallback reconstruction when detailed alignment fails.

        Args:
            text: Original text
            predictions: Model predictions

        Returns:
            Text with punctuation (best-effort)
        """
        try:
            pred_list = predictions.tolist() if hasattr(predictions, 'tolist') else predictions

            # Simple approach: add punctuation after each character based on prediction
            result = []
            for i, char in enumerate(text):
                result.append(char)
                # Add punctuation if predicted (skip first and last to avoid issues)
                if 0 < i < len(pred_list) - 1 and i < len(text):
                    pred_label = pred_list[min(i + 1, len(pred_list) - 1)]
                    if pred_label in self.LABEL_MAP and self.LABEL_MAP[pred_label]:
                        result.append(self.LABEL_MAP[pred_label])

            return ''.join(result)
        except Exception as e:
            logger.error(f"Simple reconstruction also failed: {e}")
            return text

    def is_available(self) -> bool:
        """
        Check if transformers library is available without loading models.

        This is useful for feature detection and library selection logic.

        Returns:
            bool: True if transformers can be imported, False otherwise
        """
        return self.model_manager.is_transformers_available()

    def get_supported_punctuation(self) -> List[str]:
        """
        Get list of punctuation marks supported by transformers model.

        Returns:
            list: Chinese punctuation marks that the model can predict
        """
        return [p for p in self.LABEL_MAP.values() if p]

    def get_info(self) -> dict:
        """
        Get adapter information and status.

        Returns:
            dict: Adapter metadata including library name, status, capabilities
        """
        return {
            "library": "transformers",
            "model": self.model_name,
            "loaded": self._model is not None,
            "available": self.is_available(),
            "device": self.model_manager.get_device(),
            "supported_punctuation": self.get_supported_punctuation(),
            "features": {
                "speed": "moderate",
                "accuracy": "high",
                "gpu_required": False,
                "gpu_recommended": True,
                "model_size": "medium (~400-700MB)",
            },
            "advantages": [
                "Higher accuracy than rule-based approaches",
                "ML-based context understanding",
                "Trained on Wikipedia data",
            ],
            "limitations": [
                "Slower than zhpr (especially on CPU)",
                "Requires model download on first use",
                "May struggle with domain-specific text",
                "Comma placement accuracy still challenging",
            ]
        }


# Convenience function for direct usage
def restore_punctuation(text: str, model_manager, model_name: str = None) -> str:
    """
    Convenience function for one-off punctuation restoration.

    Args:
        text: Unpunctuated Chinese text
        model_manager: ModelManager instance
        model_name: Optional custom model name

    Returns:
        Text with punctuation restored

    Example:
        >>> from model_manager import ModelManager
        >>> from transformers_adapter import restore_punctuation
        >>> manager = ModelManager()
        >>> restore_punctuation("你好吗我很好", manager)
        "你好吗？我很好。"
    """
    adapter = TransformersAdapter(model_manager, model_name)
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
    adapter = TransformersAdapter(manager)

    # Check availability
    print(f"Transformers available: {adapter.is_available()}")
    print(f"Adapter info: {adapter.get_info()}")

    # Test punctuation restoration (will download model on first run)
    if adapter.is_available():
        test_text = "你好吗我很好谢谢"
        print(f"\nInput:  {test_text}")

        try:
            result = adapter.restore(test_text)
            print(f"Output: {result}")
        except ImportError:
            print("transformers not installed - skipping test")
            print("Install with: pip install transformers torch")
        except Exception as e:
            print(f"Error during test: {e}")
    else:
        print("\ntransformers library not available")
        print("Install with: pip install transformers torch")
