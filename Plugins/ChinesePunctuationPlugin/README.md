# Chinese Punctuation Restoration Plugin

Automatic Chinese punctuation restoration for VoiceFlow transcriptions using ML-based approaches.

## Overview

This plugin adds intelligent punctuation marks (，、。？！；) to unpunctuated Chinese transcribed text, eliminating the manual editing step required with native dictation systems.

## Features

- **Dual-library support**: zhpr (fast) or transformers (accurate)
- **Automatic fallback**: Switches libraries if primary fails
- **GPU acceleration**: Automatically detects and uses GPU when available
- **Lazy model loading**: Fast startup, models load on first use
- **Configurable**: Enable/disable, choose library, customize punctuation marks
- **Model caching**: Downloads models once (~400-700MB), caches for reuse

## Installation

### Requirements
- Python 3.8 or higher
- 400-700MB disk space for ML models (first run only)
- Optional: CUDA-compatible GPU for faster processing

### Install Dependencies

```bash
cd Plugins/ChinesePunctuationPlugin
pip install -r requirements.txt
```

This will install:
- `zhpr`: Fast Chinese punctuation restoration
- `transformers`: Hugging Face transformers for ML-based restoration
- `torch`: PyTorch for model execution

### First Run

Models download automatically on first use (~400-700MB). This may take 1-2 minutes depending on your internet connection.

## Configuration

Edit the VoiceFlow `config.json` file to customize plugin behavior:

```json
{
  "chinese_punctuation": {
    "enabled": true,
    "library": "zhpr",
    "fallback_enabled": true,
    "punctuation_marks": {
      "comma": true,
      "period": true,
      "question_mark": true,
      "exclamation_mark": true,
      "semicolon": true,
      "enumeration_comma": true
    },
    "batch_size": 1000,
    "gpu_enabled": true
  }
}
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | boolean | `true` | Enable/disable the plugin |
| `library` | string | `"zhpr"` | Primary library: `"zhpr"` (fast) or `"transformers"` (accurate) |
| `fallback_enabled` | boolean | `true` | Auto-switch to alternate library on failure |
| `punctuation_marks.*` | boolean | `true` | Enable/disable specific punctuation types |
| `batch_size` | number | `1000` | Characters per batch for large texts |
| `gpu_enabled` | boolean | `true` | Use GPU if available |

## Usage

### Automatic Processing

Once installed and enabled, the plugin automatically processes all Chinese transcriptions:

**Input** (unpunctuated):
```
你好吗我很好谢谢你呢我也很好
```

**Output** (punctuated):
```
你好吗？我很好，谢谢。你呢？我也很好。
```

### Manual Testing

Test the plugin directly:

```python
import sys
from pathlib import Path
sys.path.insert(0, 'Plugins/ChinesePunctuationPlugin')

from chinese_punctuation_plugin import ChinesePunctuationPlugin

# Initialize plugin
plugin = ChinesePunctuationPlugin()
plugin.initialize({"library": "zhpr"})

# Test punctuation restoration
text = "你好吗我很好谢谢"
result = plugin.on_transcription(text)

print(f"Input:  {text}")
print(f"Output: {result}")
```

## Supported Punctuation

The plugin supports 6 types of Chinese punctuation:

| Mark | Name | zhpr | transformers |
|------|------|------|--------------|
| ， | Comma | ✓ | ✓ |
| 、 | Enumeration comma | ✓ | ✓ |
| 。 | Period | ✓ | ✓ |
| ？ | Question mark | ✓ | ✓ |
| ！ | Exclamation mark | ✓ | ✓ |
| ； | Semicolon | ✓ | ✓ |

## Performance

| Scenario | zhpr | transformers |
|----------|------|--------------|
| First run (model download) | ~30s | ~60s |
| Cached model load | <2s | <5s |
| 1000 chars (CPU) | <2s | <5s |
| 1000 chars (GPU) | <1s | <2s |
| Memory usage | <500MB | <2GB |

## Troubleshooting

### Plugin doesn't load

**Problem**: Plugin fails to load in VoiceFlow

**Solutions**:
1. Verify manifest.json is valid JSON: `python3 -m json.tool manifest.json`
2. Check entry point exists: `test -f chinese_punctuation_plugin.py && echo OK`
3. Verify dependencies installed: `pip list | grep -E "zhpr|transformers|torch"`

### No punctuation added

**Problem**: Text passes through unchanged

**Solutions**:
1. Check if plugin is enabled in config.json: `"enabled": true`
2. Verify text is Chinese (plugin only supports Chinese)
3. Check logs for errors: Plugin logs errors to console

### ImportError: No module named 'zhpr'

**Problem**: ML libraries not installed

**Solution**:
```bash
pip install -r requirements.txt
```

### GPU not detected

**Problem**: Plugin uses CPU despite having GPU

**Solutions**:
1. Check CUDA installation: `python3 -c "import torch; print(torch.cuda.is_available())"`
2. Install PyTorch with CUDA support:
   ```bash
   pip install torch --index-url https://download.pytorch.org/whl/cu118
   ```
3. Set GPU explicitly in config: `"gpu_enabled": true`

### Model download fails

**Problem**: Network error during first run

**Solutions**:
1. Check internet connection
2. Retry - downloads resume automatically
3. Manual download: Place models in `~/.cache/huggingface/` (transformers) or `~/.zhpr/` (zhpr)

### Out of memory error

**Problem**: Large text causes memory overflow

**Solutions**:
1. Reduce batch_size in config: `"batch_size": 500`
2. Use zhpr instead of transformers (lower memory usage)
3. Process shorter text segments

## Known Limitations

1. **Language support**: Chinese only (no English or multilingual support)
2. **Comma accuracy**: ML models struggle with comma placement; may over/under-use commas
3. **Domain-specific text**: Trained on general Wikipedia/web data; may underperform on technical jargon
4. **Processing mode**: Batch only (no real-time streaming)
5. **First-run download**: 400-700MB model download required on first use
6. **Max text length**: 10,000 characters per request (configurable via batch_size)

## Technical Details

### Architecture

```
VoiceFlow Transcription
    ↓
ChinesePunctuationPlugin.on_transcription()
    ↓
ModelManager (lazy loading, device detection)
    ↓
    ├─→ ZhprAdapter (primary, fast)
    │       ↓ (on failure)
    └─→ TransformersAdapter (fallback, accurate)
    ↓
Punctuated Text
```

### Files

- `chinese_punctuation_plugin.py`: Main plugin entry point
- `model_manager.py`: Model loading, caching, GPU detection
- `zhpr_adapter.py`: Wrapper for zhpr library
- `transformers_adapter.py`: Wrapper for Hugging Face transformers
- `manifest.json`: Plugin metadata
- `requirements.txt`: Python dependencies

### Models Used

- **zhpr**: Rule-based + ML hybrid (lightweight, fast)
- **transformers**: `p208p2002/zh-wiki-punctuation-restore` (token classification)

## Development

### Running Tests

```bash
# Run plugin unit tests
pytest server/tests/test_chinese_punctuation_plugin.py -v

# Run with coverage
pytest server/tests/test_chinese_punctuation_plugin.py --cov=Plugins/ChinesePunctuationPlugin --cov-report=term-missing
```

### Adding New Features

1. Modify adapter files for new libraries
2. Update manifest.json with new configuration options
3. Add tests in `server/tests/test_chinese_punctuation_plugin.py`
4. Update this README

## Support

For issues, questions, or feature requests, please contact the VoiceFlow development team.

## License

[Add license information]

## Version

**Version**: 1.0.0
**Last Updated**: 2026-02-04
