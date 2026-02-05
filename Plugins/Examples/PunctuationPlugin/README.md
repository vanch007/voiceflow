# Punctuation Plugin

A VoiceFlow plugin that adds smart punctuation to transcribed text based on speech patterns and context.

## Overview

This example Python plugin demonstrates:
- **Text modification**: Adds punctuation marks (periods, question marks, exclamation points)
- **Smart detection**: Analyzes text patterns to determine appropriate punctuation
- **Configuration**: User-configurable behavior for capitalization and period insertion
- **Python implementation**: Shows the Python plugin development pattern

## Features

- **Automatic Period Insertion**: Adds periods at the end of statements
- **Question Detection**: Recognizes question patterns and adds question marks
- **Exclamation Detection**: Identifies exclamatory phrases and adds exclamation marks
- **Sentence Capitalization**: Capitalizes the first letter of sentences
- **Configurable Behavior**: Enable/disable features through configuration

## Installation

### Development Installation

1. Copy the plugin to the Examples directory:
   ```bash
   cp -r Plugins/Examples/PunctuationPlugin ~/Library/Application\ Support/VoiceFlow/Plugins/
   ```

2. Restart VoiceFlow to load the plugin

3. Enable the plugin in VoiceFlow settings

### User Installation

1. Copy the PunctuationPlugin directory to your VoiceFlow plugins folder:
   ```bash
   cp -r PunctuationPlugin ~/Library/Application\ Support/VoiceFlow/Plugins/
   ```

2. The plugin will be automatically detected on next launch

## Configuration

The plugin supports the following configuration options in `manifest.json`:

```json
{
  "configuration": {
    "defaults": {
      "addPeriods": true,
      "capitalizeFirst": true
    }
  }
}
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `addPeriods` | boolean | `true` | Automatically add periods at sentence ends |
| `capitalizeFirst` | boolean | `true` | Capitalize first letter of sentences |

## Usage Examples

### Input → Output

**Simple statement:**
```
Input:  "hello world"
Output: "Hello world."
```

**Question:**
```
Input:  "what is the weather today"
Output: "What is the weather today?"
```

**Exclamation:**
```
Input:  "wow that's amazing"
Output: "Wow that's amazing!"
```

**Already punctuated:**
```
Input:  "This is already done."
Output: "This is already done."
```

## How It Works

The plugin uses pattern matching and keyword detection to determine appropriate punctuation:

1. **Question Detection**: Looks for question words (what, when, where, who, why, how) and inverted verb patterns
2. **Exclamation Detection**: Identifies exclamatory keywords (wow, amazing, terrible, help, etc.)
3. **Default Behavior**: Adds periods to regular statements

### Question Patterns

The plugin recognizes these question patterns:
- Questions starting with: what, when, where, who, why, how, which, whose, whom
- Inverted verb questions: "Is it ready?", "Are you coming?", "Will you help?"

### Exclamation Keywords

The plugin adds exclamation marks when it detects:
- Positive: wow, amazing, incredible, awesome, fantastic, wonderful, excellent
- Negative: terrible, horrible, oh no
- Urgent: help

## Testing

### Manual Testing

1. Load the plugin in VoiceFlow
2. Speak various phrases and observe the punctuation:
   - Statement: "this is a test" → "This is a test."
   - Question: "what time is it" → "What time is it?"
   - Exclamation: "that's amazing" → "That's amazing!"

### Validation

Validate the manifest:
```bash
bash scripts/plugin-dev-tools.sh validate Plugins/Examples/PunctuationPlugin
```

## Technical Details

- **Platform**: Python 3.8+
- **Dependencies**: None (uses only standard library)
- **Permissions**: `text.read`, `text.modify`
- **Entry Point**: `punctuation_plugin.py`

## Limitations

- **Pattern-based**: Uses simple pattern matching, not advanced NLP
- **False positives**: May occasionally misidentify punctuation type
- **English-focused**: Patterns optimized for English language
- **No context memory**: Processes each transcription independently

## Customization Ideas

You can extend this plugin by:

1. **Adding more patterns**: Expand question and exclamation detection
2. **ML integration**: Use NLP libraries for better detection
3. **Multi-language support**: Add patterns for other languages
4. **Comma insertion**: Detect pauses and add commas
5. **Abbreviation handling**: Detect abbreviations like "Dr." or "etc."

## Example Code

Here's how to modify the question detection:

```python
def _is_question(self, text: str) -> bool:
    text_lower = text.lower()

    # Add your custom question patterns
    custom_patterns = [
        r'\b(can|could|would|should) you\b',
        r'\bdid (you|he|she|they)\b',
    ]

    for pattern in self.question_patterns + custom_patterns:
        if re.search(pattern, text_lower):
            return True

    return False
```

## License

MIT License - See manifest.json for details

## Support

For issues or questions about this example plugin:
- Check the main plugin documentation: `docs/PLUGIN_DEVELOPMENT.md`
- Review the API reference: `docs/PLUGIN_API_REFERENCE.md`
- See other examples in `Plugins/Examples/`
