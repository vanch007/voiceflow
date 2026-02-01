#!/usr/bin/env python3
"""VoiceFlow ASR WebSocket Server using Qwen3-ASR-1.7B with MPS acceleration."""

import asyncio
import json
import logging
import time

import numpy as np
import soundfile as sf
import websockets
from qwen_asr import Qwen3ASRModel

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

HOST = "localhost"
PORT = 9876

model: Qwen3ASRModel = None


def load_model():
    global model
    logger.info("Loading Qwen3-ASR-1.7B model...")
    model = Qwen3ASRModel.from_pretrained("Qwen/Qwen3-ASR-1.7B")
    try:
        model.model = model.model.to("mps")
        logger.info("Model moved to MPS (GPU).")
    except Exception as e:
        logger.warning(f"MPS not available, using CPU: {e}")
    logger.info("Model loaded successfully.")


def warmup_model():
    """Warm up the model with a short silent audio segment."""
    global model
    if model is None:
        raise RuntimeError("Model not loaded. Call load_model() first.")

    logger.info("Warming up model with silent audio...")
    # Generate 1 second of silence at 16kHz
    silent_audio = np.zeros(16000, dtype=np.float32)

    try:
        # Perform warmup inference
        _ = model.transcribe(audio=(silent_audio, 16000), language="Korean")
        logger.info("Model warmup completed.")
    except Exception as e:
        logger.warning(f"Warmup failed: {e}")


async def handle_client(websocket):
    logger.info("Client connected.")
    audio_chunks: list[bytes] = []
    recording = False

    try:
        async for message in websocket:
            if isinstance(message, str):
                data = json.loads(message)
                msg_type = data.get("type")

                if msg_type == "start":
                    logger.info("Recording started.")
                    audio_chunks.clear()
                    recording = True

                elif msg_type == "stop":
                    logger.info("Recording stopped. Processing audio...")
                    recording = False

                    if not audio_chunks:
                        await websocket.send(json.dumps({"type": "final", "text": ""}))
                        continue

                    raw = b"".join(audio_chunks)
                    samples = np.frombuffer(raw, dtype=np.float32)
                    duration = len(samples) / 16000
                    logger.info(f"Audio: {len(samples)} samples ({duration:.1f}s)")

                    # Pass as (ndarray, sample_rate) tuple — no temp file needed
                    t0 = time.perf_counter()
                    result = model.transcribe(audio=(samples, 16000), language="Korean")
                    elapsed = time.perf_counter() - t0

                    if isinstance(result, str):
                        text = result
                    elif isinstance(result, list) and len(result) > 0:
                        text = result[0].text if hasattr(result[0], 'text') else str(result[0])
                    elif hasattr(result, 'text'):
                        text = result.text
                    else:
                        text = str(result)

                    logger.info(f"Transcription ({elapsed:.2f}s): {text}")
                    await websocket.send(json.dumps({"type": "final", "text": text}))

            elif isinstance(message, bytes) and recording:
                audio_chunks.append(message)

    except websockets.exceptions.ConnectionClosed:
        logger.info("Client disconnected.")


async def main():
    load_model()
    logger.info(f"Starting WebSocket server on ws://{HOST}:{PORT}")
    async with websockets.serve(handle_client, HOST, PORT):
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
