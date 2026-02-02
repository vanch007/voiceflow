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

# 模型访问锁，防止并发转录导致 MLX 崩溃
import threading
model_lock = threading.Lock()


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


# ============== VAD 流式转录相关函数 ==============

def calculate_rms(samples: np.ndarray) -> float:
    """计算音频片段的 RMS 能量"""
    if len(samples) == 0:
        return 0.0
    return float(np.sqrt(np.mean(samples ** 2)))


def is_silence(samples: np.ndarray, threshold: float = 0.01) -> bool:
    """判断音频片段是否为静音"""
    return calculate_rms(samples) < threshold


def extract_text(result) -> str:
    """从模型结果中提取文本"""
    if isinstance(result, str):
        return result
    elif isinstance(result, list) and len(result) > 0:
        return result[0].text if hasattr(result[0], 'text') else str(result[0])
    elif hasattr(result, 'text'):
        return result.text
    else:
        return str(result)


async def vad_streaming_transcribe(
    websocket,
    audio_chunks: list,
    model,
    language,
    silence_threshold: float = 0.01,
    silence_duration_ms: int = 500,
    check_interval_ms: int = 100
):
    """
    基于 VAD 的流式转录：检测到停顿时触发转录

    Args:
        websocket: WebSocket 连接
        audio_chunks: 音频数据块列表
        model: ASR 模型实例
        language: 语言设置
        silence_threshold: 静音阈值 (RMS)，降低更敏感
        silence_duration_ms: 需要持续静音多久才触发 (毫秒)
        check_interval_ms: 检查间隔 (毫秒)
    """
    silence_frames = 0
    frames_needed = silence_duration_ms // check_interval_ms
    last_transcribed_length = 0
    last_text = ""

    logger.info(f"🎙️ VAD 流式转录已启动 (threshold={silence_threshold}, duration={silence_duration_ms}ms)")

    try:
        while True:
            await asyncio.sleep(check_interval_ms / 1000)

            if not audio_chunks:
                continue

            # 获取当前所有音频
            raw = b"".join(audio_chunks)
            samples = np.frombuffer(raw, dtype=np.float32)

            if len(samples) < 1600:  # 至少 100ms (16000Hz * 0.1s)
                continue

            # 检查最近 100ms 的音频能量
            recent_samples = samples[-1600:]

            if is_silence(recent_samples, silence_threshold):
                silence_frames += 1
            else:
                silence_frames = 0

            # 检测到停顿，且有新音频需要转录
            if silence_frames >= frames_needed and len(samples) > last_transcribed_length:
                try:
                    # 使用锁保护模型访问
                    def transcribe_with_lock():
                        with model_lock:
                            return model.transcribe((samples, 16000), language)

                    result = await asyncio.to_thread(transcribe_with_lock)
                    text = extract_text(result)

                    # 只在文本变化时发送
                    if text and text != last_text:
                        last_text = text
                        last_transcribed_length = len(samples)
                        await websocket.send(json.dumps({
                            "type": "partial",
                            "text": text
                        }))
                        logger.info(f"📝 Partial (pause detected): {text}")

                except Exception as e:
                    logger.warning(f"⚠️ VAD 转录失败: {e}")

                # 重置静音计数，等待下一次停顿
                silence_frames = 0

    except asyncio.CancelledError:
        logger.info("🛑 VAD 流式转录任务已取消")
        raise


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
    transcription_task: asyncio.Task = None

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

                    # 启动 VAD 流式转录任务
                    transcription_task = asyncio.create_task(
                        vad_streaming_transcribe(
                            websocket,
                            audio_chunks,
                            get_model(session_model_id),
                            session_language
                        )
                    )

                elif msg_type == "stop":
                    logger.info("⏹️ 停止录音，正在处理音频...")
                    recording = False

                    # 取消 VAD 转录任务
                    if transcription_task:
                        transcription_task.cancel()
                        try:
                            await transcription_task
                        except asyncio.CancelledError:
                            pass
                        transcription_task = None

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
                    # 使用锁保护模型访问，防止并发崩溃
                    with model_lock:
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
