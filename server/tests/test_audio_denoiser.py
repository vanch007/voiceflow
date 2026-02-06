#!/usr/bin/env python3
"""Unit tests for AudioDenoiser module (noisereduce TorchGate version)."""

import numpy as np
import pytest


class TestAudioDenoiserInit:
    """Test AudioDenoiser initialization."""

    def test_init_default_values(self):
        """Test default initialization values."""
        from audio_denoiser import AudioDenoiser

        denoiser = AudioDenoiser()

        assert denoiser._enabled is True
        assert denoiser._loaded is False
        assert denoiser._model is None
        assert denoiser._nonstationary is True


class TestAudioDenoiserEnableDisable:
    """Test enable/disable functionality."""

    def test_disabled_returns_original(self):
        """Test that disabled denoiser returns original audio."""
        from audio_denoiser import AudioDenoiser

        denoiser = AudioDenoiser()
        denoiser.set_enabled(False)

        audio = np.random.randn(1600).astype(np.float32)
        result = denoiser.denoise(audio)

        np.testing.assert_array_equal(result, audio)

    def test_short_audio_returns_original(self):
        """Test that very short audio (<10ms) is returned unchanged."""
        from audio_denoiser import AudioDenoiser

        denoiser = AudioDenoiser()
        # 100 samples at 16kHz = 6.25ms, below the 10ms threshold
        audio = np.random.randn(100).astype(np.float32)
        result = denoiser.denoise(audio)

        np.testing.assert_array_equal(result, audio)


class TestAudioDenoiserSingleton:
    """Test singleton pattern."""

    def test_get_denoiser_returns_same_instance(self):
        """Test that get_denoiser returns the same instance."""
        from audio_denoiser import get_denoiser, init_denoiser

        # Reset singleton
        init_denoiser()

        denoiser1 = get_denoiser()
        denoiser2 = get_denoiser()

        assert denoiser1 is denoiser2

    def test_init_denoiser_creates_new_instance(self):
        """Test that init_denoiser creates a new instance with custom settings."""
        from audio_denoiser import get_denoiser, init_denoiser

        init_denoiser(nonstationary=False)
        denoiser = get_denoiser()

        assert denoiser._nonstationary is False


class TestAudioDenoiserProperties:
    """Test property accessors."""

    def test_is_enabled_property(self):
        """Test is_enabled property."""
        from audio_denoiser import AudioDenoiser

        denoiser = AudioDenoiser()
        assert denoiser.is_enabled is True

        denoiser.set_enabled(False)
        assert denoiser.is_enabled is False

    def test_is_loaded_property(self):
        """Test is_loaded property before model loading."""
        from audio_denoiser import AudioDenoiser

        denoiser = AudioDenoiser()
        # Before loading, should be False
        assert denoiser.is_loaded is False


class TestAudioDenoiserPerformance:
    """Test denoising performance."""

    def test_denoise_preserves_length(self):
        """Test that denoised audio has same length as input."""
        from audio_denoiser import AudioDenoiser

        denoiser = AudioDenoiser()
        audio = np.random.randn(16000).astype(np.float32)  # 1 second

        result = denoiser.denoise(audio)

        assert len(result) == len(audio)

    def test_denoise_latency_under_10ms(self):
        """Test that denoising latency is under 10ms for 1s audio."""
        import time
        from audio_denoiser import AudioDenoiser

        denoiser = AudioDenoiser()
        audio = np.random.randn(16000).astype(np.float32)  # 1 second

        # Warmup
        _ = denoiser.denoise(audio)

        # Measure
        t0 = time.perf_counter()
        _ = denoiser.denoise(audio)
        t1 = time.perf_counter()

        latency_ms = (t1 - t0) * 1000
        assert latency_ms < 10, f"Latency {latency_ms:.1f}ms exceeds 10ms threshold"
