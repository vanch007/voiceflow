#!/usr/bin/env python3
"""VoiceFlow ASR WebSocket Server using Qwen3-ASR with MPS acceleration."""

import asyncio
import json
import logging
import time
from pathlib import Path

import numpy as np
import websockets
from qwen_asr import Qwen3ASRModel

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

HOST = "localhost"
PORT = 9876

model: Qwen3ASRModel = None
config = {}


def load_config():
    """加载配置文件"""
    global config
    config_path = Path(__file__).parent.parent / "config.json"

    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            config = json.load(f)
            logger.info(f"✅ 配置加载成功: {config}")
    except FileNotFoundError:
        # 默认配置
        config = {"model_size": "1.7B", "language": "Chinese"}
        logger.warning(f"⚠️ 配置文件不存在，使用默认配置: {config}")
    except Exception as e:
        config = {"model_size": "1.7B", "language": "Chinese"}
        logger.error(f"❌ 配置加载失败: {e}，使用默认配置")

    return config


def load_model():
    """加载 Qwen3-ASR 模型"""
    global model

    model_size = config.get("model_size", "1.7B")
    model_name = f"Qwen/Qwen3-ASR-{model_size}"

    logger.info(f"正在加载 {model_name} 模型...")

    try:
        model = Qwen3ASRModel.from_pretrained(model_name)

        # 尝试使用 MPS（Apple GPU）
        try:
            model.model = model.model.to("mps")
            logger.info("✅ 模型已移至 MPS (Apple GPU)")
        except Exception as e:
            logger.warning(f"⚠️ MPS 不可用，使用 CPU: {e}")

        logger.info(f"✅ 模型加载成功: {model_name}")

    except Exception as e:
        logger.error(f"❌ 模型加载失败: {e}")
        raise


async def handle_client(websocket):
    """处理客户端连接"""
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

                    # 使用配置的语言进行识别
                    language = config.get("language", "Chinese")
                    t0 = time.perf_counter()
                    result = model.transcribe(audio=(samples, 16000), language=language)
                    elapsed = time.perf_counter() - t0

                    # 提取文本
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
    load_config()
    load_model()

    model_size = config.get("model_size", "1.7B")
    logger.info(f"🚀 WebSocket 服务器启动于 ws://{HOST}:{PORT}")
    logger.info(f"📊 当前模型: Qwen3-ASR-{model_size}")

    async with websockets.serve(handle_client, HOST, PORT):
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
