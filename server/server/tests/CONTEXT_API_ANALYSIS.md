# MLX ASR Context Parameter API Analysis

## Overview

This document provides analysis of the MLX ASR context parameter support based on code inspection of `mlx_asr.py` and the verification test in `test_context_api.py`.

## Current API Signature

Based on `server/mlx_asr.py`, the `transcribe()` method currently calls:

```python
# Line 168-171 in mlx_asr.py
if language is None:
    result = self.model.generate(audio=audio_input)
else:
    result = self.model.generate(audio=audio_input, language=language)
```

**Parameters currently used:**
- `audio`: numpy array or file path
- `language`: optional language string (e.g., "Chinese", "English")

**Parameters NOT currently used:**
- `context`: Not passed to model.generate()
- `hotwords`: Not passed to model.generate()
- Any vocabulary/biasing parameters: Not present

## Verification Test Approach

The test file `server/tests/test_context_api.py` implements a comprehensive verification strategy:

### Test 1: Baseline Generation
Tests that the model works without any context parameter.

### Test 2: Context Parameter Acceptance
Attempts to pass `context` parameter to `model.generate()`:
```python
result = model.generate(audio=audio, language="English", context=["React", "Kubernetes", "TypeScript"])
```

### Test 3: Alternative Parameter Names
If `context` fails, tries alternatives:
- `hotwords`
- `vocabulary`
- `bias_words`
- `prompt`

### Test 4: Signature Inspection
Uses Python's `inspect` module to document the actual API signature.

## Expected Outcomes

### If Context is Supported ✅
- Report will show: "Context Parameter Supported: YES ✅"
- Recommendation: Proceed with ASR-level hotword biasing
- API usage documented for implementation

### If Context is NOT Supported ❌
- Report will show: "Context Parameter Supported: NO ❌"
- Fallback options documented:
  1. Post-processing with enhanced text replacement rules
  2. Patch mlx-audio locally to expose context parameter
  3. Use HuggingFace transformers directly
  4. Contact mlx-audio maintainers

## Fallback Implementation

The test includes a working demonstration of post-processing fallback:

```python
# Simple case-insensitive replacement
vocabulary = {"react": "React", "kubernetes": "Kubernetes"}
processed = asr_output
for wrong, correct in vocabulary.items():
    processed = re.sub(r'\b' + re.escape(wrong) + r'\b', correct, processed, flags=re.IGNORECASE)
```

**Note:** This only fixes capitalization/formatting, NOT recognition accuracy.

## Next Steps

1. **Run the test** in the proper Python environment:
   ```bash
   cd server && python tests/test_context_api.py
   ```

2. **Review the generated report** at `server/tests/context_api_verification_report.txt`

3. **Implementation decision:**
   - If supported: Modify `mlx_asr.py` to pass context parameter
   - If not supported: Implement post-processing fallback in `text_polisher.py`

## Critical Blocker Status

This verification addresses the critical blocker mentioned in spec.md:
- **Line 92**: "CRITICAL: Verify `model.generate()` accepts `context` parameter"
- **Line 376-377**: QA blocker verification for mlx-audio context parameter

The test is designed to provide a clear go/no-go decision for the hotword biasing feature.
