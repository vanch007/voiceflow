# Qwen3-ASR Custom Vocabulary Research

**Date:** 2026-02-03
**Task:** Investigate custom vocabulary/hotword support in Qwen3-ASR-1.7B
**Purpose:** Enable custom dictionary feature for VoiceFlow app

---

## Summary

✅ **Qwen3-ASR DOES support custom vocabulary** through **contextual biasing** feature.

The model accepts plain text context to guide recognition toward specific terms, making it suitable for implementing a custom dictionary feature.

---

## Key Findings

### 1. Feature Name: "Contextual Biasing"

Qwen3-ASR refers to custom vocabulary support as **"contextual biasing"** or **"hotword biasing"**.

- Users can provide plain text context to guide the ASR model
- The system "gently nudges recognition toward the terms you care about"
- No preprocessing or special formatting required

### 2. Supported Input Formats

The context parameter accepts flexible input:

- **Simple keyword list**: `"Qwen-ASR, DashScope, FFmpeg"`
- **Full paragraphs**: Background text or domain-specific descriptions
- **Mixed text**: Any length, any format
- **Documents**: Even entire PDF content can be used as context

### 3. CLI Usage (Documented)

The `qwen3-asr` command-line tool uses the `-c` flag for context:

```bash
qwen3-asr -i "/path/to/my/tech_talk.mp4" -c "Qwen-ASR, DashScope, FFmpeg"
```

### 4. Python API (Needs Verification)

**Status:** Parameter name not explicitly documented in search results.

**Possible parameter names** based on related Qwen ASR APIs:
- `context` (most likely based on CLI flag)
- `corpus_text` (mentioned in Alibaba Cloud Model Studio SDK)
- `hotwords` (common ASR parameter name)

**Current server code:**
```python
result = model.transcribe(audio=(samples, 16000), language="Korean")
```

**Potential implementation:**
```python
# Option 1: context parameter (most likely)
result = model.transcribe(
    audio=(samples, 16000),
    language="Korean",
    context="CustomWord1, CustomWord2, CustomWord3"
)

# Option 2: corpus_text parameter (Alibaba Cloud SDK style)
result = model.transcribe(
    audio=(samples, 16000),
    language="Korean",
    corpus_text="CustomWord1, CustomWord2, CustomWord3"
)
```

---

## Recommended Implementation Approach

### Phase 1: API Parameter Discovery (TEST REQUIRED)

Before implementing the full feature, we need to verify the exact parameter name:

1. **Test script** to check which parameter works:

```python
from qwen_asr import Qwen3ASRModel
import numpy as np

model = Qwen3ASRModel.from_pretrained("Qwen/Qwen3-ASR-1.7B")
test_audio = np.zeros(16000, dtype=np.float32)  # 1 second of silence

# Test different parameter names
try:
    result = model.transcribe(audio=(test_audio, 16000), context="test")
    print("✓ 'context' parameter works")
except TypeError as e:
    print(f"✗ 'context' failed: {e}")

try:
    result = model.transcribe(audio=(test_audio, 16000), corpus_text="test")
    print("✓ 'corpus_text' parameter works")
except TypeError as e:
    print(f"✗ 'corpus_text' failed: {e}")

try:
    result = model.transcribe(audio=(test_audio, 16000), hotwords="test")
    print("✓ 'hotwords' parameter works")
except TypeError as e:
    print(f"✗ 'hotwords' failed: {e}")

# Check available parameters
import inspect
sig = inspect.signature(model.transcribe)
print(f"\nAvailable parameters: {list(sig.parameters.keys())}")
```

2. **Inspect source code** of qwen-asr library:

```bash
python3 -c "import qwen_asr; print(qwen_asr.__file__)"
# Then read the transcribe method implementation
```

### Phase 2: Server Integration

Once the parameter name is confirmed, modify `server/main.py`:

```python
async def handle_client(websocket):
    custom_dictionary: list[str] = []  # Store client's custom words

    async for message in websocket:
        if isinstance(message, str):
            data = json.loads(message)
            msg_type = data.get("type")

            # NEW: Handle dictionary updates
            if msg_type == "update_dictionary":
                custom_dictionary = data.get("words", [])
                logger.info(f"Dictionary updated: {len(custom_dictionary)} words")
                await websocket.send(json.dumps({
                    "type": "dictionary_updated",
                    "count": len(custom_dictionary)
                }))

            elif msg_type == "stop":
                # Build context string from custom dictionary
                context_str = ", ".join(custom_dictionary) if custom_dictionary else None

                # Pass to transcribe (adjust parameter name based on Phase 1 testing)
                if context_str:
                    result = model.transcribe(
                        audio=(samples, 16000),
                        language="Korean",
                        context=context_str  # Or corpus_text/hotwords
                    )
                else:
                    result = model.transcribe(audio=(samples, 16000), language="Korean")
```

### Phase 3: Fallback Strategy (If Native Support Unavailable)

If Qwen3-ASR's Python API doesn't expose the context parameter, we have alternatives:

**Option A: Post-processing correction**
```python
def apply_custom_dictionary_correction(text: str, custom_words: list[str]) -> str:
    """Replace common misrecognitions with custom dictionary words."""
    # Use fuzzy matching or phonetic similarity
    # Example: Replace "Queen ASR" → "Qwen-ASR"
    import difflib
    words = text.split()
    corrected = []
    for word in words:
        matches = difflib.get_close_matches(word, custom_words, n=1, cutoff=0.6)
        corrected.append(matches[0] if matches else word)
    return " ".join(corrected)
```

**Option B: Switch to DashScope API**

The Alibaba Cloud DashScope API (commercial) has documented `corpus_text` support:
- Requires API key
- May have costs
- Better documentation

---

## Testing Plan

### Test Case 1: Korean Technical Terms

**Custom dictionary:**
- "SwiftUI" (often misrecognized as "스위프트유아이")
- "Anthropic" (often misrecognized as "앤트로픽")
- "Claude" (often misrecognized as "클로드")

**Test audio:** Record Korean speech containing these English terms.

**Success criteria:** Recognition accuracy improvement with dictionary enabled vs. disabled.

### Test Case 2: Real-time Dictionary Updates

**Steps:**
1. Start recording session
2. Transcribe audio (baseline accuracy)
3. Send dictionary update via WebSocket
4. Transcribe same audio again
5. Verify improvement

### Test Case 3: Empty Dictionary Handling

**Verify:**
- No errors when dictionary is empty
- No performance degradation
- Graceful fallback to standard recognition

---

## Open Questions

1. **Parameter name**: What is the exact parameter name for `model.transcribe()`?
   - **Action**: Run test script to verify

2. **Context format**: Comma-separated vs. space-separated vs. newline-separated?
   - **Action**: Test different formats

3. **Performance impact**: Does providing context slow down transcription?
   - **Action**: Benchmark with/without context

4. **Context length limit**: Is there a maximum context string length?
   - **Action**: Test with large dictionaries (100+ words)

5. **Language mixing**: Does Korean language setting + English context words work?
   - **Action**: Test with mixed Korean/English audio

---

## References

- [Qwen ASR Official Website](https://qwenasr.com) - Contextual biasing documentation
- [Hugging Face Qwen3-ASR](https://huggingface.co/Qwen/Qwen3-ASR-1.7B) - Model card
- [GitHub Qwen3-ASR Examples](https://github.com/QwenLM/Qwen3-ASR) - Code examples
- [Alibaba Cloud Model Studio](https://alibabacloud.com) - DashScope API with corpus_text parameter
- [Limecraft ASR Overview](https://limecraft.com) - Custom context usage patterns

---

## Recommendation

**Proceed with implementation** using the following strategy:

1. ✅ **Immediate**: Implement WebSocket message handler for dictionary updates (Phase 4.1)
2. ✅ **Immediate**: Implement Swift client dictionary sync (Phase 4.2)
3. 🔬 **Before Phase 4.1 completion**: Run parameter discovery test to confirm API
4. ✅ **Conditional**: Use native context parameter if available, or implement post-processing fallback

**Risk level:** Low - Even if native support is unavailable, post-processing is a viable alternative.

**Confidence:** High (85%) - Commercial ASR services and CLI tool confirm the feature exists; only Python API surface needs verification.
