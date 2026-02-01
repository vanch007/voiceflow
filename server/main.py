#!/usr/bin/env python3
"""VoiceFlow ASR WebSocket Server using Qwen3-ASR-1.7B with MPS acceleration."""

import asyncio
import json
import logging
import time

import numpy as np
import websockets
from qwen_asr import Qwen3ASRModel

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

HOST = "localhost"
PORT = 9876

model: Qwen3ASRModel = None


def load_model():
    global model
    logger.info("正在加载 Qwen3-ASR-1.7B 模型...")
    model = Qwen3ASRModel.from_pretrained("Qwen/Qwen3-ASR-1.7B")
    try:
        model.model = model.model.to("mps")
        logger.info("✅ 模型已移至 MPS (Apple GPU)")
    except Exception as e:
        logger.warning(f"⚠️ MPS 不可用，使用 CPU: {e}")
    logger.info("✅ 模型加载成功")


async def handle_client(websocket):
    logger.info("客户端已连接")
    audio_chunks: list[bytes] = []
    recording = False

    try:
        async for message in websocket:
            if isinstance(message, str):
                data = json.loads(message)
                msg_type = data.get("type")

                if msg_type == "start":
                    logger.info("🎤 开始录音")
                    audio_chunks.clear()
                    recording = True

                elif msg_type == "stop":
                    logger.info("⏹️ 停止录音，正在处理音频...")
                    recording = False

                    if not audio_chunks:
                        await websocket.send(json.dumps({"type": "final", "text": ""}))
                        continue

                    raw = b"".join(audio_chunks)
                    samples = np.frombuffer(raw, dtype=np.float32)
                    duration = len(samples) / 16000
                    logger.info(f"📊 音频: {len(samples)} 采样点 ({duration:.1f}s)")

                    # Pass as (ndarray, sample_rate) tuple — no temp file needed
                    t0 = time.perf_counter()
                    result = model.transcribe(audio=(samples, 16000), language="Chinese")
                    elapsed = time.perf_counter() - t0

                    if isinstance(result, str):
                        text = result
                    elif isinstance(result, list) and len(result) > 0:
                        text = result[0].text if hasattr(result[0], 'text') else str(result[0])
                    elif hasattr(result, 'text'):
                        text = result.text
                    else:
                        text = str(result)

                    logger.info(f"✅ 转录完成 ({elapsed:.2f}s): {text}")
                    await websocket.send(json.dumps({"type": "final", "text": text}))

            elif isinstance(message, bytes) and recording:
                audio_chunks.append(message)

    except websockets.exceptions.ConnectionClosed:
        logger.info("客户端断开连接")
    except Exception as e:
        logger.error(f"❌ 错误: {e}", exc_info=True)


async def main():
    load_model()
    logger.info(f"🚀 WebSocket 服务器启动于 ws://{HOST}:{PORT}")
    async with websockets.serve(handle_client, HOST, PORT):
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
