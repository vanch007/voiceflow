#!/usr/bin/env python3
"""
Unit tests for Chinese Punctuation Plugin components.

Tests cover:
- ModelManager: lazy loading, GPU detection, model caching
- ZhprAdapter: punctuation restoration, error handling
- TransformersAdapter: punctuation restoration, error handling
- ChinesePunctuationPlugin: initialization, transcription processing, fallback logic
"""

import pytest
import sys
from pathlib import Path
from unittest.mock import Mock, MagicMock, patch, call
import logging

# Add plugin directory to path
plugin_path = Path(__file__).parent.parent.parent / "Plugins" / "ChinesePunctuationPlugin"
sys.path.insert(0, str(plugin_path))

# Import components under test
from model_manager import ModelManager
from zhpr_adapter import ZhprAdapter
from transformers_adapter import TransformersAdapter
from chinese_punctuation_plugin import ChinesePunctuationPlugin


# ============================================================================
# ModelManager Tests
# ============================================================================

class TestModelManager:
    """Tests for ModelManager lazy loading and device detection."""

    def test_initialization(self):
        """Test ModelManager initializes with lazy loading flags."""
        manager = ModelManager()
        assert manager._zhpr_loaded is False
        assert manager._zhpr_module is None
        assert manager._transformers_model is None
        assert manager._transformers_tokenizer is None
        assert manager._device is None

    def test_get_device_cpu_when_torch_unavailable(self):
        """Test device defaults to CPU when PyTorch not available."""
        manager = ModelManager()

        with patch.dict('sys.modules', {'torch': None}):
            with patch('builtins.__import__', side_effect=ImportError("No module named 'torch'")):
                device = manager.get_device()

        assert device == "cpu"

    def test_get_device_cpu_when_cuda_unavailable(self):
        """Test device is CPU when CUDA not available."""
        manager = ModelManager()

        mock_torch = MagicMock()
        mock_torch.cuda.is_available.return_value = False

        with patch.dict('sys.modules', {'torch': mock_torch}):
            device = manager.get_device()

        assert device == "cpu"

    def test_get_device_cuda_when_available(self):
        """Test device is CUDA when GPU available."""
        manager = ModelManager()

        mock_torch = MagicMock()
        mock_torch.cuda.is_available.return_value = True

        with patch.dict('sys.modules', {'torch': mock_torch}):
            device = manager.get_device()

        assert device == "cuda"

    def test_get_device_caching(self):
        """Test device detection is cached after first call."""
        manager = ModelManager()
        manager._device = "cuda"

        # Should return cached value without checking torch
        device = manager.get_device()
        assert device == "cuda"

    def test_get_zhpr_success(self):
        """Test successful lazy loading of zhpr library."""
        manager = ModelManager()

        mock_zhpr = MagicMock()
        mock_zhpr.restore.return_value = "你好，世界。"

        with patch.dict('sys.modules', {'zhpr': mock_zhpr}):
            with patch('builtins.__import__', return_value=mock_zhpr):
                zhpr_module = manager.get_zhpr()

        assert zhpr_module is mock_zhpr
        assert manager._zhpr_loaded is True
        assert manager._zhpr_module is mock_zhpr

    def test_get_zhpr_import_error(self):
        """Test get_zhpr raises ImportError when zhpr not installed."""
        manager = ModelManager()

        with patch.dict('sys.modules', {'zhpr': None}):
            with patch('builtins.__import__', side_effect=ImportError("No module named 'zhpr'")):
                with pytest.raises(ImportError) as exc_info:
                    manager.get_zhpr()

        assert "zhpr library not installed" in str(exc_info.value)

    def test_get_zhpr_caching(self):
        """Test zhpr module is cached after first load."""
        manager = ModelManager()
        mock_zhpr = MagicMock()
        manager._zhpr_module = mock_zhpr
        manager._zhpr_loaded = True

        # Should return cached module
        zhpr_module = manager.get_zhpr()
        assert zhpr_module is mock_zhpr

    def test_get_transformers_model_success(self):
        """Test successful lazy loading of transformers model."""
        manager = ModelManager()

        mock_model = MagicMock()
        mock_tokenizer = MagicMock()
        mock_auto_model = MagicMock()
        mock_auto_model.from_pretrained.return_value = mock_model
        mock_auto_tokenizer = MagicMock()
        mock_auto_tokenizer.from_pretrained.return_value = mock_tokenizer

        with patch('transformers.AutoModelForTokenClassification', mock_auto_model):
            with patch('transformers.AutoTokenizer', mock_auto_tokenizer):
                model, tokenizer = manager.get_transformers_model()

        assert model is mock_model
        assert tokenizer is mock_tokenizer
        assert manager._transformers_model is mock_model
        assert manager._transformers_tokenizer is mock_tokenizer

    def test_get_transformers_model_import_error(self):
        """Test get_transformers_model raises ImportError when library unavailable."""
        manager = ModelManager()

        with patch('builtins.__import__', side_effect=ImportError("No module named 'transformers'")):
            with pytest.raises(ImportError) as exc_info:
                manager.get_transformers_model()

        assert "transformers library not installed" in str(exc_info.value)

    def test_is_zhpr_available_true(self):
        """Test is_zhpr_available returns True when zhpr can be imported."""
        manager = ModelManager()

        mock_zhpr = MagicMock()
        with patch.dict('sys.modules', {'zhpr': mock_zhpr}):
            assert manager.is_zhpr_available() is True

    def test_is_zhpr_available_false(self):
        """Test is_zhpr_available returns False when zhpr cannot be imported."""
        manager = ModelManager()

        with patch.dict('sys.modules', {'zhpr': None}):
            with patch('builtins.__import__', side_effect=ImportError):
                assert manager.is_zhpr_available() is False

    def test_is_transformers_available_true(self):
        """Test is_transformers_available returns True when library can be imported."""
        manager = ModelManager()

        mock_transformers = MagicMock()
        with patch.dict('sys.modules', {'transformers': mock_transformers}):
            assert manager.is_transformers_available() is True

    def test_is_transformers_available_false(self):
        """Test is_transformers_available returns False when library cannot be imported."""
        manager = ModelManager()

        with patch.dict('sys.modules', {'transformers': None}):
            with patch('builtins.__import__', side_effect=ImportError):
                assert manager.is_transformers_available() is False

    def test_unload_models(self):
        """Test unload_models clears all cached models."""
        manager = ModelManager()
        manager._zhpr_module = MagicMock()
        manager._zhpr_loaded = True
        manager._transformers_model = MagicMock()
        manager._transformers_tokenizer = MagicMock()

        manager.unload_models()

        assert manager._zhpr_module is None
        assert manager._zhpr_loaded is False
        assert manager._transformers_model is None
        assert manager._transformers_tokenizer is None


# ============================================================================
# ZhprAdapter Tests
# ============================================================================

class TestZhprAdapter:
    """Tests for ZhprAdapter punctuation restoration."""

    def test_initialization(self):
        """Test ZhprAdapter initializes correctly."""
        mock_manager = MagicMock()
        adapter = ZhprAdapter(mock_manager)

        assert adapter.model_manager is mock_manager
        assert adapter._zhpr_module is None

    def test_restore_empty_input(self):
        """Test restore returns empty input unchanged."""
        mock_manager = MagicMock()
        adapter = ZhprAdapter(mock_manager)

        assert adapter.restore("") == ""
        assert adapter.restore("   ") == "   "

    def test_restore_success(self):
        """Test successful punctuation restoration with zhpr."""
        mock_manager = MagicMock()
        mock_zhpr = MagicMock()
        mock_zhpr.restore.return_value = "你好吗？我很好，谢谢。"
        mock_manager.get_zhpr.return_value = mock_zhpr

        adapter = ZhprAdapter(mock_manager)
        result = adapter.restore("你好吗我很好谢谢")

        assert result == "你好吗？我很好，谢谢。"
        assert adapter._zhpr_module is mock_zhpr
        mock_zhpr.restore.assert_called_once_with("你好吗我很好谢谢")

    def test_restore_lazy_loading(self):
        """Test zhpr module is lazy loaded on first restore call."""
        mock_manager = MagicMock()
        mock_zhpr = MagicMock()
        mock_zhpr.restore.return_value = "你好。"
        mock_manager.get_zhpr.return_value = mock_zhpr

        adapter = ZhprAdapter(mock_manager)
        assert adapter._zhpr_module is None

        adapter.restore("你好")

        mock_manager.get_zhpr.assert_called_once()
        assert adapter._zhpr_module is mock_zhpr

    def test_restore_uses_cached_module(self):
        """Test restore uses cached zhpr module on subsequent calls."""
        mock_manager = MagicMock()
        mock_zhpr = MagicMock()
        mock_zhpr.restore.return_value = "你好。"

        adapter = ZhprAdapter(mock_manager)
        adapter._zhpr_module = mock_zhpr

        adapter.restore("你好")

        # Should not call get_zhpr since module already cached
        mock_manager.get_zhpr.assert_not_called()
        mock_zhpr.restore.assert_called_once()

    def test_restore_import_error(self):
        """Test restore raises ImportError when zhpr not available."""
        mock_manager = MagicMock()
        mock_manager.get_zhpr.side_effect = ImportError("zhpr library not installed")

        adapter = ZhprAdapter(mock_manager)

        with pytest.raises(ImportError):
            adapter.restore("你好")

    def test_restore_processing_error_returns_original(self):
        """Test restore returns original text on processing errors."""
        mock_manager = MagicMock()
        mock_zhpr = MagicMock()
        mock_zhpr.restore.side_effect = RuntimeError("Processing failed")
        mock_manager.get_zhpr.return_value = mock_zhpr

        adapter = ZhprAdapter(mock_manager)
        original_text = "你好吗我很好"
        result = adapter.restore(original_text)

        # Should return original text on error (non-destructive)
        assert result == original_text

    def test_is_available(self):
        """Test is_available delegates to model manager."""
        mock_manager = MagicMock()
        mock_manager.is_zhpr_available.return_value = True

        adapter = ZhprAdapter(mock_manager)
        assert adapter.is_available() is True

        mock_manager.is_zhpr_available.assert_called_once()

    def test_get_supported_punctuation(self):
        """Test get_supported_punctuation returns correct marks."""
        mock_manager = MagicMock()
        adapter = ZhprAdapter(mock_manager)

        supported = adapter.get_supported_punctuation()

        assert "，" in supported
        assert "、" in supported
        assert "。" in supported
        assert "？" in supported
        assert "！" in supported
        assert "；" in supported
        assert len(supported) == 6

    def test_get_info(self):
        """Test get_info returns adapter metadata."""
        mock_manager = MagicMock()
        mock_manager.is_zhpr_available.return_value = True

        adapter = ZhprAdapter(mock_manager)
        info = adapter.get_info()

        assert info["library"] == "zhpr"
        assert info["loaded"] is False
        assert info["available"] is True
        assert "supported_punctuation" in info
        assert "features" in info


# ============================================================================
# TransformersAdapter Tests
# ============================================================================

class TestTransformersAdapter:
    """Tests for TransformersAdapter punctuation restoration."""

    def test_initialization(self):
        """Test TransformersAdapter initializes correctly."""
        mock_manager = MagicMock()
        adapter = TransformersAdapter(mock_manager)

        assert adapter.model_manager is mock_manager
        assert adapter.model_name == "p208p2002/zh-wiki-punctuation-restore"
        assert adapter._model is None
        assert adapter._tokenizer is None

    def test_initialization_custom_model(self):
        """Test initialization with custom model name."""
        mock_manager = MagicMock()
        adapter = TransformersAdapter(mock_manager, model_name="custom/model")

        assert adapter.model_name == "custom/model"

    def test_restore_empty_input(self):
        """Test restore returns empty input unchanged."""
        mock_manager = MagicMock()
        adapter = TransformersAdapter(mock_manager)

        assert adapter.restore("") == ""
        assert adapter.restore("   ") == "   "

    def test_restore_success(self):
        """Test successful punctuation restoration with transformers."""
        mock_manager = MagicMock()
        mock_manager.get_device.return_value = "cpu"

        mock_model = MagicMock()
        mock_tokenizer = MagicMock()
        mock_manager.get_transformers_model.return_value = (mock_model, mock_tokenizer)

        # Mock tokenizer output
        mock_inputs = {
            'input_ids': [[101, 872, 1962, 102]],  # Mock token IDs
            'attention_mask': [[1, 1, 1, 1]]
        }
        mock_tokenizer.return_value = mock_inputs
        mock_tokenizer.convert_ids_to_tokens.return_value = ['[CLS]', '你', '好', '[SEP]']

        # Mock model output
        mock_torch = MagicMock()
        mock_predictions = MagicMock()
        mock_predictions.tolist.return_value = [0, 2, 0, 0]  # Predict period after second char
        mock_torch.argmax.return_value = mock_predictions

        mock_outputs = MagicMock()
        mock_outputs.logits = MagicMock()
        mock_model.return_value = mock_outputs

        with patch.dict('sys.modules', {'torch': mock_torch}):
            adapter = TransformersAdapter(mock_manager)
            result = adapter.restore("你好")

        assert isinstance(result, str)
        assert adapter._model is mock_model
        assert adapter._tokenizer is mock_tokenizer

    def test_restore_import_error(self):
        """Test restore raises ImportError when transformers not available."""
        mock_manager = MagicMock()
        mock_manager.get_transformers_model.side_effect = ImportError("transformers not installed")

        adapter = TransformersAdapter(mock_manager)

        with pytest.raises(ImportError):
            adapter.restore("你好")

    def test_restore_processing_error_returns_original(self):
        """Test restore returns original text on processing errors."""
        mock_manager = MagicMock()
        mock_manager.get_transformers_model.side_effect = RuntimeError("Model loading failed")

        adapter = TransformersAdapter(mock_manager)
        original_text = "你好吗我很好"
        result = adapter.restore(original_text)

        # Should return original text on error (non-destructive)
        assert result == original_text

    def test_is_available(self):
        """Test is_available delegates to model manager."""
        mock_manager = MagicMock()
        mock_manager.is_transformers_available.return_value = True

        adapter = TransformersAdapter(mock_manager)
        assert adapter.is_available() is True

        mock_manager.is_transformers_available.assert_called_once()

    def test_get_supported_punctuation(self):
        """Test get_supported_punctuation returns correct marks."""
        mock_manager = MagicMock()
        adapter = TransformersAdapter(mock_manager)

        supported = adapter.get_supported_punctuation()

        assert "，" in supported
        assert "。" in supported
        assert "？" in supported
        assert "！" in supported
        assert "；" in supported
        assert "：" in supported

    def test_get_info(self):
        """Test get_info returns adapter metadata."""
        mock_manager = MagicMock()
        mock_manager.is_transformers_available.return_value = True
        mock_manager.get_device.return_value = "cpu"

        adapter = TransformersAdapter(mock_manager)
        info = adapter.get_info()

        assert info["library"] == "transformers"
        assert info["model"] == "p208p2002/zh-wiki-punctuation-restore"
        assert info["loaded"] is False
        assert info["available"] is True
        assert info["device"] == "cpu"


# ============================================================================
# ChinesePunctuationPlugin Tests
# ============================================================================

class TestChinesePunctuationPlugin:
    """Tests for ChinesePunctuationPlugin main plugin class."""

    def test_initialization(self):
        """Test plugin initializes with default values."""
        plugin = ChinesePunctuationPlugin()

        assert plugin.config == {}
        assert plugin.enabled is True
        assert plugin.library == "zhpr"
        assert plugin.device == "auto"
        assert plugin._initialized is False
        assert plugin._zhpr_adapter is None
        assert plugin._transformers_adapter is None
        assert plugin._model_manager is None

    def test_initialize_with_config(self):
        """Test plugin initialization with configuration."""
        plugin = ChinesePunctuationPlugin()

        config = {
            "auto_punctuation": True,
            "library": "transformers",
            "device": "cpu"
        }

        plugin.initialize(config)

        assert plugin.config == config
        assert plugin.enabled is True
        assert plugin.library == "transformers"
        assert plugin.device == "cpu"
        assert plugin._initialized is True

    def test_initialize_with_defaults(self):
        """Test initialization uses defaults for missing config values."""
        plugin = ChinesePunctuationPlugin()
        plugin.initialize({})

        assert plugin.enabled is True
        assert plugin.library == "zhpr"
        assert plugin.device == "auto"

    def test_initialize_invalid_library(self):
        """Test initialization raises error for invalid library."""
        plugin = ChinesePunctuationPlugin()

        config = {"library": "invalid"}

        with pytest.raises(ValueError) as exc_info:
            plugin.initialize(config)

        assert "Invalid library" in str(exc_info.value)

    def test_initialize_invalid_device(self):
        """Test initialization raises error for invalid device."""
        plugin = ChinesePunctuationPlugin()

        config = {"device": "invalid"}

        with pytest.raises(ValueError) as exc_info:
            plugin.initialize(config)

        assert "Invalid device" in str(exc_info.value)

    def test_on_transcription_plugin_disabled(self):
        """Test on_transcription returns original text when plugin disabled."""
        plugin = ChinesePunctuationPlugin()
        plugin.initialize({"auto_punctuation": False})

        result = plugin.on_transcription("你好吗我很好")

        assert result == "你好吗我很好"

    def test_on_transcription_not_initialized(self):
        """Test on_transcription returns original text when not initialized."""
        plugin = ChinesePunctuationPlugin()

        result = plugin.on_transcription("你好吗我很好")

        assert result == "你好吗我很好"

    def test_on_transcription_empty_input(self):
        """Test on_transcription handles empty input."""
        plugin = ChinesePunctuationPlugin()
        plugin.initialize({})

        assert plugin.on_transcription("") == ""
        assert plugin.on_transcription("   ") == "   "

    def test_on_transcription_zhpr_success(self):
        """Test on_transcription uses zhpr successfully."""
        plugin = ChinesePunctuationPlugin()
        plugin.initialize({"library": "zhpr"})

        # Mock the adapters
        mock_zhpr_adapter = MagicMock()
        mock_zhpr_adapter.is_available.return_value = True
        mock_zhpr_adapter.restore.return_value = "你好吗？我很好。"

        with patch('model_manager.ModelManager') as mock_manager_class:
            with patch('zhpr_adapter.ZhprAdapter', return_value=mock_zhpr_adapter):
                result = plugin.on_transcription("你好吗我很好")

        assert result == "你好吗？我很好。"
        mock_zhpr_adapter.restore.assert_called_once_with("你好吗我很好")

    def test_on_transcription_fallback_to_transformers(self):
        """Test on_transcription falls back to transformers when zhpr fails."""
        plugin = ChinesePunctuationPlugin()
        plugin.initialize({"library": "zhpr"})

        # Mock zhpr to fail
        mock_zhpr_adapter = MagicMock()
        mock_zhpr_adapter.is_available.return_value = False

        # Mock transformers to succeed
        mock_transformers_adapter = MagicMock()
        mock_transformers_adapter.is_available.return_value = True
        mock_transformers_adapter.restore.return_value = "你好吗？我很好。"

        with patch('model_manager.ModelManager'):
            with patch('zhpr_adapter.ZhprAdapter', return_value=mock_zhpr_adapter):
                with patch('transformers_adapter.TransformersAdapter', return_value=mock_transformers_adapter):
                    result = plugin.on_transcription("你好吗我很好")

        assert result == "你好吗？我很好。"
        mock_transformers_adapter.restore.assert_called_once()

    def test_on_transcription_both_libraries_fail(self):
        """Test on_transcription returns original text when both libraries fail."""
        plugin = ChinesePunctuationPlugin()
        plugin.initialize({"library": "zhpr"})

        # Mock both adapters to fail
        mock_zhpr_adapter = MagicMock()
        mock_zhpr_adapter.is_available.return_value = False

        mock_transformers_adapter = MagicMock()
        mock_transformers_adapter.is_available.return_value = False

        with patch('model_manager.ModelManager'):
            with patch('zhpr_adapter.ZhprAdapter', return_value=mock_zhpr_adapter):
                with patch('transformers_adapter.TransformersAdapter', return_value=mock_transformers_adapter):
                    result = plugin.on_transcription("你好吗我很好")

        # Should return original text (non-destructive)
        assert result == "你好吗我很好"

    def test_on_transcription_exception_handling(self):
        """Test on_transcription handles exceptions gracefully."""
        plugin = ChinesePunctuationPlugin()
        plugin.initialize({})

        with patch('model_manager.ModelManager', side_effect=RuntimeError("Error")):
            result = plugin.on_transcription("你好")

        # Should return original text on error
        assert result == "你好"

    def test_cleanup(self):
        """Test cleanup clears all resources."""
        plugin = ChinesePunctuationPlugin()
        plugin.initialize({})

        plugin._zhpr_adapter = MagicMock()
        plugin._transformers_adapter = MagicMock()
        plugin._model_manager = MagicMock()

        plugin.cleanup()

        assert plugin._zhpr_adapter is None
        assert plugin._transformers_adapter is None
        assert plugin._model_manager is None
        assert plugin._initialized is False

    def test_get_info(self):
        """Test get_info returns plugin metadata."""
        plugin = ChinesePunctuationPlugin()
        plugin.initialize({"library": "zhpr", "device": "cpu"})

        info = plugin.get_info()

        assert info["name"] == "ChinesePunctuationPlugin"
        assert info["version"] == "1.0.0"
        assert info["initialized"] is True
        assert info["enabled"] is True
        assert info["library"] == "zhpr"
        assert info["device"] == "cpu"
        assert "supported_punctuation" in info
        assert "features" in info

    def test_try_library_zhpr(self):
        """Test _try_library with zhpr library."""
        plugin = ChinesePunctuationPlugin()
        plugin.initialize({})

        mock_zhpr_adapter = MagicMock()
        mock_zhpr_adapter.is_available.return_value = True
        mock_zhpr_adapter.restore.return_value = "你好。"

        with patch('model_manager.ModelManager'):
            with patch('zhpr_adapter.ZhprAdapter', return_value=mock_zhpr_adapter):
                result = plugin._try_library("你好", "zhpr")

        assert result == "你好。"

    def test_try_library_transformers(self):
        """Test _try_library with transformers library."""
        plugin = ChinesePunctuationPlugin()
        plugin.initialize({})

        mock_transformers_adapter = MagicMock()
        mock_transformers_adapter.is_available.return_value = True
        mock_transformers_adapter.restore.return_value = "你好。"

        with patch('model_manager.ModelManager'):
            with patch('transformers_adapter.TransformersAdapter', return_value=mock_transformers_adapter):
                result = plugin._try_library("你好", "transformers")

        assert result == "你好。"

    def test_try_library_unavailable(self):
        """Test _try_library returns None when library unavailable."""
        plugin = ChinesePunctuationPlugin()
        plugin.initialize({})

        mock_adapter = MagicMock()
        mock_adapter.is_available.return_value = False

        with patch('model_manager.ModelManager'):
            with patch('zhpr_adapter.ZhprAdapter', return_value=mock_adapter):
                result = plugin._try_library("你好", "zhpr")

        assert result is None

    def test_try_library_unknown_library(self):
        """Test _try_library returns None for unknown library."""
        plugin = ChinesePunctuationPlugin()
        plugin.initialize({})

        with patch('model_manager.ModelManager'):
            result = plugin._try_library("你好", "unknown")

        assert result is None


# ============================================================================
# Integration Tests
# ============================================================================

class TestIntegration:
    """Integration tests for end-to-end workflows."""

    def test_full_pipeline_with_mocked_zhpr(self):
        """Test full pipeline from plugin initialization to text processing."""
        # Create plugin
        plugin = ChinesePunctuationPlugin()

        # Initialize with config
        config = {
            "auto_punctuation": True,
            "library": "zhpr",
            "device": "cpu"
        }
        plugin.initialize(config)

        # Mock zhpr adapter
        mock_zhpr_adapter = MagicMock()
        mock_zhpr_adapter.is_available.return_value = True
        mock_zhpr_adapter.restore.return_value = "你好吗？我很好，谢谢。"

        with patch('model_manager.ModelManager'):
            with patch('zhpr_adapter.ZhprAdapter', return_value=mock_zhpr_adapter):
                result = plugin.on_transcription("你好吗我很好谢谢")

        assert result == "你好吗？我很好，谢谢。"

        # Cleanup
        plugin.cleanup()
        assert plugin._initialized is False

    def test_configuration_toggle(self):
        """Test plugin respects enable/disable toggle."""
        plugin = ChinesePunctuationPlugin()

        # Test enabled
        plugin.initialize({"auto_punctuation": True})
        assert plugin.enabled is True

        # Test disabled
        plugin.initialize({"auto_punctuation": False})
        result = plugin.on_transcription("你好吗我很好")
        assert result == "你好吗我很好"  # Should return unchanged

    def test_library_selection(self):
        """Test plugin respects library selection configuration."""
        plugin = ChinesePunctuationPlugin()

        # Test zhpr selection
        plugin.initialize({"library": "zhpr"})
        assert plugin.library == "zhpr"

        # Test transformers selection
        plugin.initialize({"library": "transformers"})
        assert plugin.library == "transformers"


if __name__ == "__main__":
    # Run tests with pytest
    pytest.main([__file__, "-v", "--tb=short"])
