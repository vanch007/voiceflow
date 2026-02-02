#!/usr/bin/env python3
"""VoiceFlow ASR WebSocket Server using MLX Qwen3-ASR with Apple Silicon acceleration."""

import asyncio
import json
import logging
import time
from pathlib import Path

import numpy as np
import websockets
from mlx_asr import MLXQwen3ASR
from text_polisher import TextPolisher

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

HOST = "localhost"
PORT = 9876

# 模型缓存：model_id -> MLXQwen3ASR 实例
models: dict[str, MLXQwen3ASR] = {}
current_model_id: str = None
polisher: TextPolisher = None
config = {}


# 语言代码到 mlx-audio 语言名称的映射
LANGUAGE_MAP = {
    "auto": None,  # None 表示自动检测
    "zh": "Chinese",
    "en": "English",
    "yue": "Cantonese",
    "ja": "Japanese",
    "ko": "Korean",
    "de": "German",
    "fr": "French",
    "es": "Spanish",
    "pt": "Portuguese",
    "it": "Italian",
    "ru": "Russian",
    "nl": "Dutch",
    "sv": "Swedish",
    "da": "Danish",
    "fi": "Finnish",
    "pl": "Polish",
    "cs": "Czech",
    "el": "Greek",
    "hu": "Hungarian",
    "mk": "Macedonian",
    "ro": "Romanian",
    "ar": "Arabic",
    "id": "Indonesian",
    "th": "Thai",
    "vi": "Vietnamese",
    "tr": "Turkish",
    "hi": "Hindi",
    "ms": "Malay",
    "fil": "Filipino",
    "fa": "Persian",
}


def load_config():
    """加载配置文件"""
    global config
    config_path = Path(__file__).parent.parent / "config.json"

    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            config = json.load(f)
            logger.info(f"✅ 配置加载成功: {config}")
    except FileNotFoundError:
        config = {"model_id": "mlx-community/Qwen3-ASR-0.6B-8bit", "language": "Chinese"}
        logger.warning(f"⚠️ 配置文件不存在，使用默认配置: {config}")
    except Exception as e:
        config = {"model_id": "mlx-community/Qwen3-ASR-0.6B-8bit", "language": "Chinese"}
        logger.error(f"❌ 配置加载失败: {e}，使用默认配置")

    return config


def load_model(model_id: str = None):
    """加载 MLX Qwen3-ASR 模型（支持动态切换）"""
    global models, current_model_id

    if model_id is None:
        model_id = config.get("model_id", "mlx-community/Qwen3-ASR-0.6B-8bit")

    # 如果已经加载过该模型，直接返回
    if model_id in models:
        current_model_id = model_id
        logger.info(f"✅ 使用已缓存模型: {model_id}")
        return models[model_id]

    logger.info(f"正在加载MLX模型: {model_id}")

    try:
        model = MLXQwen3ASR(model_id=model_id)
        models[model_id] = model
        current_model_id = model_id
        logger.info(f"✅ MLX模型加载成功: {model_id}")
        logger.info("🚀 使用Apple Silicon GPU加速")
        return model
    except Exception as e:
        logger.error(f"❌ 模型加载失败: {e}")
        raise


def get_model(model_id: str = None) -> MLXQwen3ASR:
    """获取模型实例，如果未加载则自动加载"""
    if model_id is None:
        model_id = current_model_id or config.get("model_id", "mlx-community/Qwen3-ASR-0.6B-8bit")

    if model_id not in models:
        return load_model(model_id)

    return models[model_id]


def warmup_model():
    """Warm up the model with a short silent audio segment."""
    global polisher
    model = get_model()
    if model is None:
        raise RuntimeError("Model not loaded. Call load_model() first.")

    logger.info("Warming up model with silent audio...")
    silent_audio = np.zeros(16000, dtype=np.float32)

    try:
        language = config.get("language", "Chinese")
        _ = model.transcribe(audio=(silent_audio, 16000), language=language)
        logger.info("✅ Model warmup completed.")
    except Exception as e:
        logger.warning(f"⚠️ Warmup failed: {e}")

    logger.info("Initializing text polisher...")
    polisher = TextPolisher()
    logger.info("✅ Text polisher initialized.")


async def handle_client(websocket):
    """处理客户端连接"""
    logger.info("客户端已连接")
    audio_chunks: list[bytes] = []
    recording = False
    enable_polish = False
    session_model_id = None
    session_language = None

    try:
        async for message in websocket:
            if isinstance(message, str):
                data = json.loads(message)
                msg_type = data.get("type")

                if msg_type == "start":
                    enable_polish = data.get("enable_polish") == "true"
                    session_model_id = data.get("model_id")
                    lang_code = data.get("language", "auto")
                    session_language = LANGUAGE_MAP.get(lang_code, None)

                    logger.info(f"🎤 开始录音. Polish: {enable_polish}, Model: {session_model_id}, Language: {lang_code} -> {session_language}")

                    # 确保模型已加载
                    if session_model_id:
                        get_model(session_model_id)

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

                    # 使用会话指定的模型和语言
                    model = get_model(session_model_id)
                    language = session_language  # None 表示自动检测

                    t0 = time.perf_counter()
                    result = model.transcribe(audio=(samples, 16000), language=language)
                    elapsed = time.perf_counter() - t0

                    # 提取文本
                    if isinstance(result, str):
                        original_text = result
                    elif isinstance(result, list) and len(result) > 0:
                        original_text = result[0].text if hasattr(result[0], 'text') else str(result[0])
                    elif hasattr(result, 'text'):
                        original_text = result.text
                    else:
                        original_text = str(result)

                    # Polish the transcribed text only if enabled
                    if enable_polish:
                        polished_text = polisher.polish(original_text)
                        logger.info(f"✅ 转录完成 ({elapsed:.2f}s): {original_text}")
                        logger.info(f"✨ 润色后文本: {polished_text}")
                    else:
                        polished_text = original_text
                        logger.info(f"✅ 转录完成 ({elapsed:.2f}s): {original_text} (polish disabled)")

                    await websocket.send(json.dumps({
                        "type": "final",
                        "text": polished_text,
                        "original_text": original_text
                    }))

            elif isinstance(message, bytes) and recording:
                audio_chunks.append(message)

    except websockets.exceptions.ConnectionClosed:
        logger.info("客户端断开连接")
    except Exception as e:
        logger.error(f"❌ 错误: {e}", exc_info=True)


async def main():
    load_config()
    load_model()
    warmup_model()

    model_id = config.get("model_id", "mlx-community/Qwen3-ASR-0.6B-8bit")
    logger.info(f"🚀 WebSocket 服务器启动于 ws://{HOST}:{PORT}")
    logger.info(f"📊 当前模型: {model_id}")
    logger.info("✅ MLX原生Apple Silicon加速已启用")

    async with websockets.serve(handle_client, HOST, PORT):
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
