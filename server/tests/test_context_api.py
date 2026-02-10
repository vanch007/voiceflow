#!/usr/bin/env python3
"""
MLX ASR Context Parameter API Verification

This test verifies whether the mlx-audio library's Qwen3-ASR wrapper
supports the 'context' parameter for hotword biasing.

APPROACH: Gracefully handles missing dependencies and documents findings.
"""

import inspect
import logging
import sys

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def print_section(title):
    """Print a formatted section header."""
    print("\n" + "=" * 80)
    print(title)
    print("=" * 80)


def test_mlx_audio_availability():
    """Check if mlx-audio is installed."""
    print_section("STEP 1: Check mlx-audio Availability")

    try:
        import mlx_audio
        print("✅ mlx-audio is installed")
        print(f"   Version: {getattr(mlx_audio, '__version__', 'unknown')}")
        return True
    except ImportError as e:
        print("❌ mlx-audio is NOT installed")
        print(f"   Error: {e}")
        print("   Note: This is expected in a minimal test environment")
        return False


def test_context_parameter_via_inspection():
    """Inspect mlx-audio API to check for context parameter support."""
    print_section("STEP 2: API Signature Inspection")

    try:
        from mlx_audio.stt import load
        print("✅ mlx_audio.stt.load is available")

        # Inspect the load function
        sig = inspect.signature(load)
        print(f"\nmlx_audio.stt.load() signature:")
        print(f"  {sig}")

        # Try loading a model to inspect generate()
        print("\nAttempting to inspect model.generate() signature...")
        print("  Note: This requires model download (may take time or fail)")

        try:
            model = load("mlx-community/Qwen3-ASR-0.6B-8bit")
            print("✅ Model loaded successfully")

            if hasattr(model, 'generate'):
                gen_sig = inspect.signature(model.generate)
                print(f"\nmodel.generate() signature:")
                print(f"  {gen_sig}")

                params = list(gen_sig.parameters.keys())
                print(f"\nParameters: {params}")

                if 'context' in params:
                    print("\n✅✅✅ RESULT: 'context' parameter IS SUPPORTED ✅✅✅")
                    return True
                else:
                    print("\n❌ RESULT: 'context' parameter is NOT in signature")
                    print(f"   Available params: {', '.join(params)}")
                    return False
            else:
                print("⚠️  Model does not have 'generate' method")
                return False

        except Exception as e:
            print(f"⚠️  Could not load model: {e}")
            print("   This is expected without proper mlx-audio setup")
            return None

    except ImportError:
        print("❌ mlx_audio.stt not available - cannot inspect")
        return None


def test_context_parameter_via_execution():
    """Try to actually call the API with context parameter."""
    print_section("STEP 3: Runtime API Test")

    try:
        import numpy as np
    except ImportError:
        print("⚠️  numpy not available - skipping runtime test")
        return None

    try:
        from mlx_audio.stt import load

        # Create minimal test audio
        audio = np.zeros(16000, dtype=np.float32)  # 1 second of silence
        print(f"Created test audio: {len(audio)} samples")

        # Load model
        print("Loading model...")
        model = load("mlx-community/Qwen3-ASR-0.6B-8bit")
        print("✅ Model loaded")

        # Test WITHOUT context (baseline)
        print("\nTest 3a: Baseline (no context)")
        try:
            result = model.generate(audio=audio, language="English")
            print(f"✅ Baseline successful: {result}")
        except Exception as e:
            print(f"❌ Baseline failed: {e}")
            return False

        # Test WITH context
        print("\nTest 3b: With context parameter")
        test_context = ["React", "TypeScript", "Kubernetes"]
        try:
            result = model.generate(audio=audio, language="English", context=test_context)
            print(f"✅✅✅ Context parameter ACCEPTED! ✅✅✅")
            print(f"   Result: {result}")
            return True
        except TypeError as e:
            if "context" in str(e) or "unexpected keyword" in str(e):
                print(f"❌ Context parameter NOT supported")
                print(f"   Error: {e}")
                return False
            else:
                raise

    except ImportError:
        print("⚠️  Dependencies not available - skipping runtime test")
        return None
    except Exception as e:
        print(f"⚠️  Runtime test failed: {e}")
        return None


def generate_documentation_report(context_supported):
    """Generate final API behavior documentation."""
    print_section("📋 MLX ASR CONTEXT PARAMETER - FINAL REPORT")

    print("\nModel: mlx-community/Qwen3-ASR-0.6B-8bit")
    print("Test Date: 2026-02-10")

    if context_supported is True:
        print("\n✅ RESULT: Context parameter IS SUPPORTED")
        print("\nAPI Usage:")
        print("  from mlx_audio.stt import load")
        print("  model = load('mlx-community/Qwen3-ASR-0.6B-8bit')")
        print("  result = model.generate(")
        print("      audio=audio_array,")
        print("      language='English',")
        print("      context=['React', 'TypeScript', 'Kubernetes']  # Hotwords!")
        print("  )")
        print("\n📌 RECOMMENDATION:")
        print("  ✅ Proceed with ASR-level hotword biasing implementation")
        print("  ✅ Context parameter can improve recognition of technical terms")

    elif context_supported is False:
        print("\n❌ RESULT: Context parameter is NOT SUPPORTED")
        print("\nFallback Options:")
        print("  1. Post-processing with enhanced text replacement rules")
        print("  2. Patch mlx-audio locally to expose context parameter")
        print("  3. Use HuggingFace transformers directly instead of mlx-audio")
        print("  4. Contact mlx-audio maintainers to request context support")
        print("\n📌 RECOMMENDATION:")
        print("  ⚠️  Implement post-processing-based hotword system")
        print("  ⚠️  Enhanced ReplacementRules can achieve similar results")

    else:
        print("\n⚠️  RESULT: Unable to determine (dependencies not available)")
        print("\n📝 MANUAL VERIFICATION REQUIRED:")
        print("  1. Install mlx-audio: pip install mlx-audio")
        print("  2. Re-run this test in a proper Python environment")
        print("  3. Or manually inspect mlx-audio source code on GitHub")
        print("\n📌 NEXT STEPS:")
        print("  1. Set up proper Python environment with mlx-audio")
        print("  2. Re-run: cd server && python tests/test_context_api.py")
        print("  3. Document findings in implementation_plan.json notes")

    print("\n" + "=" * 80)


def main():
    """Run MLX ASR context parameter verification."""
    print_section("🧪 MLX ASR CONTEXT PARAMETER API VERIFICATION")
    print("\nPurpose: Verify if mlx-audio supports 'context' parameter for hotword biasing")
    print("Context: Prerequisite for Task 007 custom vocabulary implementation")

    # Run tests in order
    has_mlx = test_mlx_audio_availability()

    context_supported = None

    if has_mlx:
        # Try inspection first (lightweight)
        result = test_context_parameter_via_inspection()
        if result is not None:
            context_supported = result

        # Try runtime test if inspection was inconclusive
        if context_supported is None:
            result = test_context_parameter_via_execution()
            if result is not None:
                context_supported = result

    # Generate final report
    generate_documentation_report(context_supported)

    # Save report to file
    report_path = "server/tests/context_api_verification_report.txt"
    try:
        with open(report_path, "w") as f:
            f.write("MLX ASR CONTEXT PARAMETER API VERIFICATION REPORT\n")
            f.write("=" * 80 + "\n")
            f.write(f"Test Date: 2026-02-10\n")
            f.write(f"Model: mlx-community/Qwen3-ASR-0.6B-8bit\n")
            if context_supported is True:
                f.write("\nRESULT: Context parameter IS SUPPORTED ✅\n")
            elif context_supported is False:
                f.write("\nRESULT: Context parameter is NOT SUPPORTED ❌\n")
            else:
                f.write("\nRESULT: Unable to determine (dependencies missing) ⚠️\n")
            f.write("=" * 80 + "\n")
        print(f"\n📄 Report saved to: {report_path}")
    except Exception as e:
        print(f"\n⚠️  Could not save report: {e}")

    print("\n✅ Context parameter API verification completed")
    print("   See report above for detailed findings and recommendations")

    return 0


if __name__ == "__main__":
    sys.exit(main())
