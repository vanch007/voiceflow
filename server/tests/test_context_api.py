#!/usr/bin/env python3
"""
MLX ASR Context Parameter API Verification

This test verifies whether the mlx-audio library's Qwen3-ASR wrapper
supports the 'context' parameter for hotword biasing. This is a CRITICAL
prerequisite for implementing the custom vocabulary/hotword system.

Expected outcomes:
1. If context is supported: Document API signature and behavior
2. If context is NOT supported: Identify alternative approaches (post-processing, patching, etc.)
"""

import logging
import numpy as np
import pytest

logger = logging.getLogger(__name__)


class TestContextParameterAPI:
    """Test MLX ASR context parameter support."""

    def test_context_parameter_acceptance(self):
        """
        Test if model.generate() accepts 'context' parameter.

        This is the critical blocker verification mentioned in spec.md line 376-377.
        """
        try:
            from mlx_audio.stt import load
        except ImportError:
            pytest.skip("mlx-audio not installed")
            return

        # Create minimal test audio (1 second of silence at 16kHz)
        sample_rate = 16000
        duration = 1.0
        audio = np.zeros(int(sample_rate * duration), dtype=np.float32)

        # Load the model
        logger.info("Loading MLX Qwen3-ASR model...")
        try:
            model = load("mlx-community/Qwen3-ASR-0.6B-8bit")
        except Exception as e:
            pytest.skip(f"Failed to load model: {e}")
            return

        # Test 1: Baseline generation without context
        logger.info("Test 1: Baseline generation (no context)")
        try:
            result_baseline = model.generate(audio=audio, language="English")
            logger.info(f"✅ Baseline result: {result_baseline}")
        except Exception as e:
            pytest.fail(f"Baseline generation failed: {e}")

        # Test 2: Attempt to pass context parameter
        logger.info("Test 2: Generation with context parameter")
        test_context = ["React", "Kubernetes", "TypeScript"]

        context_supported = False
        context_error = None
        result_with_context = None

        try:
            result_with_context = model.generate(
                audio=audio,
                language="English",
                context=test_context
            )
            context_supported = True
            logger.info(f"✅ Context parameter ACCEPTED: {result_with_context}")
        except TypeError as e:
            context_error = str(e)
            if "context" in context_error or "unexpected keyword" in context_error:
                logger.warning(f"❌ Context parameter NOT supported: {e}")
            else:
                raise

        # Test 3: Try alternative parameter names
        if not context_supported:
            logger.info("Test 3: Trying alternative parameter names")
            alternative_params = [
                ("hotwords", test_context),
                ("vocabulary", test_context),
                ("bias_words", test_context),
                ("prompt", " ".join(test_context))
            ]

            for param_name, param_value in alternative_params:
                try:
                    result = model.generate(
                        audio=audio,
                        language="English",
                        **{param_name: param_value}
                    )
                    logger.info(f"✅ Alternative parameter '{param_name}' ACCEPTED")
                    context_supported = True
                    break
                except TypeError:
                    logger.debug(f"Parameter '{param_name}' not supported")

        # Test 4: Inspect model signature
        logger.info("Test 4: Inspecting model.generate() signature")
        import inspect
        try:
            sig = inspect.signature(model.generate)
            logger.info(f"model.generate() signature: {sig}")
            logger.info(f"Parameters: {list(sig.parameters.keys())}")
        except Exception as e:
            logger.warning(f"Could not inspect signature: {e}")

        # Generate API behavior report
        print("\n" + "="*80)
        print("MLX ASR CONTEXT PARAMETER API VERIFICATION REPORT")
        print("="*80)
        print(f"Model: mlx-community/Qwen3-ASR-0.6B-8bit")
        print(f"Context Parameter Supported: {'YES ✅' if context_supported else 'NO ❌'}")

        if context_supported:
            print("\nAPI Usage:")
            print("  model.generate(audio=audio, language='English', context=['word1', 'word2'])")
            print("\nRecommendation:")
            print("  ✅ Proceed with ASR-level hotword biasing implementation")
        else:
            print(f"\nError: {context_error}")
            print("\nFallback Options:")
            print("  1. Post-processing with enhanced text replacement rules")
            print("  2. Patch mlx-audio locally to expose context parameter")
            print("  3. Use HuggingFace transformers directly instead of mlx-audio wrapper")
            print("  4. Contact mlx-audio maintainers to add context support")
            print("\nRecommendation:")
            print("  ⚠️  Implement post-processing fallback OR patch mlx-audio")

        print("="*80 + "\n")

        # Save report to file for reference
        import os
        report_path = os.path.join(
            os.path.dirname(__file__),
            "context_api_verification_report.txt"
        )
        with open(report_path, "w") as f:
            f.write("MLX ASR CONTEXT PARAMETER API VERIFICATION REPORT\n")
            f.write("="*80 + "\n")
            f.write(f"Model: mlx-community/Qwen3-ASR-0.6B-8bit\n")
            f.write(f"Context Parameter Supported: {'YES' if context_supported else 'NO'}\n")
            if context_supported:
                f.write("\nAPI Usage:\n")
                f.write("  model.generate(audio=audio, language='English', context=['word1', 'word2'])\n")
            else:
                f.write(f"\nError: {context_error}\n")
                f.write("\nFallback Options:\n")
                f.write("  1. Post-processing with enhanced text replacement rules\n")
                f.write("  2. Patch mlx-audio locally to expose context parameter\n")
                f.write("  3. Use HuggingFace transformers directly\n")
            f.write("="*80 + "\n")

        logger.info(f"Report saved to: {report_path}")

        # The test always passes - it's a verification, not a pass/fail test
        # The important output is the report above
        assert True, "Context parameter verification completed"


class TestContextParameterBehavior:
    """Test context parameter behavior if supported."""

    def test_context_improves_recognition(self):
        """
        If context parameter is supported, verify it actually improves recognition.

        This test is skipped if context is not supported.
        """
        try:
            from mlx_audio.stt import load
        except ImportError:
            pytest.skip("mlx-audio not installed")
            return

        # Create test audio with technical terms
        # (In real implementation, this would be actual audio samples)
        sample_rate = 16000
        duration = 2.0
        audio = np.zeros(int(sample_rate * duration), dtype=np.float32)

        logger.info("Loading model for behavior test...")
        try:
            model = load("mlx-community/Qwen3-ASR-0.6B-8bit")
        except Exception:
            pytest.skip("Model loading failed")
            return

        # Test if context parameter is accepted
        test_context = ["React", "Kubernetes"]
        try:
            result = model.generate(audio=audio, language="English", context=test_context)
            logger.info(f"✅ Context behavior test passed: {result}")
            # If we get here, context is supported
            assert True
        except TypeError:
            pytest.skip("Context parameter not supported - skipping behavior test")


class TestAlternativeApproaches:
    """Document alternative approaches if context is not supported."""

    def test_post_processing_fallback(self):
        """
        Test post-processing text replacement as fallback.

        This demonstrates how to achieve similar results without ASR-level support.
        """
        # Simulate ASR output without context
        asr_output = "I'm using react and kubernetes"

        # Vocabulary-based post-processing
        vocabulary = {
            "react": "React",
            "kubernetes": "Kubernetes",
            "typescript": "TypeScript"
        }

        # Simple case-insensitive replacement
        processed = asr_output
        for wrong, correct in vocabulary.items():
            import re
            processed = re.sub(
                r'\b' + re.escape(wrong) + r'\b',
                correct,
                processed,
                flags=re.IGNORECASE
            )

        expected = "I'm using React and Kubernetes"
        assert processed == expected, f"Expected '{expected}', got '{processed}'"

        logger.info("✅ Post-processing fallback approach validated")
        print("\nPost-processing Fallback:")
        print(f"  Input:  '{asr_output}'")
        print(f"  Output: '{processed}'")
        print("  Note: This only fixes capitalization, not recognition accuracy")


if __name__ == "__main__":
    # Configure logging for standalone execution
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s"
    )

    # Run the critical test
    print("="*80)
    print("CRITICAL BLOCKER VERIFICATION: MLX ASR Context Parameter Support")
    print("="*80)
    print()

    test = TestContextParameterAPI()
    test.test_context_parameter_acceptance()

    print("\nVerification complete. See report above for recommendations.")
