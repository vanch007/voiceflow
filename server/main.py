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


async def handle_client(websocket):
    logger.info("Client connected.")
    audio_buffer = bytearray()
    recording = False
    accumulated_text = []

    # Process audio in 2-second chunks to reduce memory usage
    CHUNK_DURATION = 2.0
    SAMPLE_RATE = 16000
    BYTES_PER_SAMPLE = 4  # float32
    CHUNK_SIZE = int(SAMPLE_RATE * CHUNK_DURATION * BYTES_PER_SAMPLE)

    async def process_chunk(chunk_bytes: bytes, is_final: bool = False):
        """Process a chunk of audio and return transcription."""
        samples = np.frombuffer(chunk_bytes, dtype=np.float32)
        duration = len(samples) / SAMPLE_RATE

        t0 = time.perf_counter()
        result = model.transcribe(audio=(samples, SAMPLE_RATE), language="Korean")
        elapsed = time.perf_counter() - t0

        if isinstance(result, str):
            text = result
        elif isinstance(result, list) and len(result) > 0:
            text = result[0].text if hasattr(result[0], 'text') else str(result[0])
        elif hasattr(result, 'text'):
            text = result.text
        else:
            text = str(result)

        msg_type = "final" if is_final else "partial"
        logger.info(f"Transcription [{msg_type}] ({elapsed:.2f}s, {duration:.1f}s audio): {text}")
        return text

    try:
        async for message in websocket:
            if isinstance(message, str):
                data = json.loads(message)
                msg_type = data.get("type")

                if msg_type == "start":
                    logger.info("Recording started.")
                    audio_buffer.clear()
                    accumulated_text.clear()
                    recording = True

                elif msg_type == "stop":
                    logger.info("Recording stopped. Processing final audio...")
                    recording = False

                    # Process any remaining audio in buffer
                    if len(audio_buffer) > 0:
                        text = await process_chunk(bytes(audio_buffer), is_final=True)
                        accumulated_text.append(text)
                        audio_buffer.clear()

                    # Send final combined result
                    final_text = " ".join(accumulated_text)
                    await websocket.send(json.dumps({"type": "final", "text": final_text}))
                    accumulated_text.clear()

            elif isinstance(message, bytes) and recording:
                audio_buffer.extend(message)

                # Process chunk when buffer reaches threshold
                while len(audio_buffer) >= CHUNK_SIZE:
                    chunk = bytes(audio_buffer[:CHUNK_SIZE])
                    text = await process_chunk(chunk, is_final=False)

                    if text.strip():
                        accumulated_text.append(text)
                        await websocket.send(json.dumps({"type": "partial", "text": text}))

                    # Remove processed chunk from buffer
                    audio_buffer = audio_buffer[CHUNK_SIZE:]

    except websockets.exceptions.ConnectionClosed:
        logger.info("Client disconnected.")


async def main():
    load_model()
    logger.info(f"Starting WebSocket server on ws://{HOST}:{PORT}")
    async with websockets.serve(handle_client, HOST, PORT):
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
