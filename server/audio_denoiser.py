#!/usr/bin/env python3
"""
Audio denoiser using noisereduce TorchGate for real-time noise suppression.

Design:
- Lazy loading: Model loaded only when first needed
- Graceful degradation: Falls back to passthrough on errors
- Thread-safe: Safe for concurrent access
- Ultra-fast: ~2ms latency for 1s audio (vs 500ms with DeepFilterNet)
"""

import logging
import threading
from typing import Optional

import numpy as np

logger = logging.getLogger(__name__)

VOICEFLOW_SAMPLE_RATE = 16000


class AudioDenoiser:
    """TorchGate-based audio denoiser with ultra-low latency."""

    def __init__(self, nonstationary: bool = True):
        """
        Initialize the denoiser.

        Args:
            nonstationary: If True, uses non-stationary noise estimation.
                          Better for varying background noise (recommended for speech).
        """
        self._model = None
        self._lock = threading.Lock()
        self._enabled = True
        self._loaded = False
        self._load_error: Optional[str] = None
        self._nonstationary = nonstationary
        self._device = None

    def _load_model(self) -> bool:
        """Lazy load TorchGate model."""
        if self._loaded:
            return self._model is not None

        with self._lock:
            if self._loaded:
                return self._model is not None

            try:
                logger.info("Loading TorchGate denoiser...")
                import torch
                from noisereduce.torchgate import TorchGate

                # Use CPU (MPS doesn't support FFT operations yet)
                self._device = torch.device('cpu')

                self._model = TorchGate(
                    sr=VOICEFLOW_SAMPLE_RATE,
                    nonstationary=self._nonstationary
                ).to(self._device)

                self._loaded = True
                logger.info("TorchGate denoiser loaded successfully (CPU, ~2ms latency)")
                return True

            except ImportError as e:
                self._load_error = f"noisereduce not installed: {e}"
                logger.warning(f"{self._load_error}")
                self._loaded = True
                return False

            except Exception as e:
                self._load_error = f"Failed to load TorchGate: {e}"
                logger.error(f"{self._load_error}")
                self._loaded = True
                return False

    def denoise(self, audio: np.ndarray, sample_rate: int = 16000) -> np.ndarray:
        """
        Denoise audio using TorchGate spectral gating.

        Args:
            audio: Input audio as numpy array (float32)
            sample_rate: Sample rate in Hz (default 16000)

        Returns:
            Denoised audio as numpy array (float32)
        """
        if not self._enabled:
            return audio

        if len(audio) < 160:  # < 10ms at 16kHz
            return audio

        if not self._load_model():
            return audio

        try:
            import torch

            audio = audio.astype(np.float32)

            # Convert to torch tensor [1, T]
            audio_tensor = torch.from_numpy(audio).unsqueeze(0).to(self._device)

            with self._lock:
                enhanced = self._model(audio_tensor)

            # Convert back to numpy
            enhanced_np = enhanced.squeeze().cpu().numpy()

            # TorchGate may slightly change length due to STFT, pad/trim to match
            if len(enhanced_np) < len(audio):
                enhanced_np = np.pad(enhanced_np, (0, len(audio) - len(enhanced_np)))
            elif len(enhanced_np) > len(audio):
                enhanced_np = enhanced_np[:len(audio)]

            return enhanced_np.astype(np.float32)

        except Exception as e:
            logger.warning(f"Denoising failed, using original audio: {e}")
            return audio

    def set_enabled(self, enabled: bool):
        """Enable or disable denoising."""
        self._enabled = enabled
        logger.info(f"Denoising {'enabled' if enabled else 'disabled'}")

    @property
    def is_enabled(self) -> bool:
        return self._enabled

    @property
    def is_loaded(self) -> bool:
        return self._loaded and self._model is not None

    @property
    def load_error(self) -> Optional[str]:
        return self._load_error


# Singleton
_denoiser: Optional[AudioDenoiser] = None
_denoiser_lock = threading.Lock()


def get_denoiser() -> AudioDenoiser:
    """Get or create the global AudioDenoiser instance."""
    global _denoiser
    if _denoiser is None:
        with _denoiser_lock:
            if _denoiser is None:
                _denoiser = AudioDenoiser()
    return _denoiser


def init_denoiser(nonstationary: bool = True) -> AudioDenoiser:
    """Initialize the global denoiser with custom settings."""
    global _denoiser
    with _denoiser_lock:
        _denoiser = AudioDenoiser(nonstationary=nonstationary)
    return _denoiser
