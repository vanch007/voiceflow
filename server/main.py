#!/usr/bin/env python3
"""VoiceFlow ASR WebSocket Server using MLX Qwen3-ASR with Apple Silicon acceleration."""

import asyncio
import json
import logging
import shutil
import threading
import time
from pathlib import Path

import numpy as np
import websockets
from mlx_asr import MLXQwen3ASR
from text_polisher import TextPolisher, TimestampAwarePunctuator
from scene_polisher import ScenePolisher
from llm_client import LLMConfig, init_llm_client, get_llm_client
from llm_polisher import LLMPolisher, init_llm_polisher, get_llm_polisher, DEFAULT_POLISH_PROMPTS
from prompt_config import get_prompt_config
from history_analyzer import init_history_analyzer, get_history_analyzer
from audio_denoiser import get_denoiser

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

HOST = "localhost"
PORT = 9876

# 模型缓存：model_id -> MLXQwen3ASR 实例
models: dict[str, MLXQwen3ASR] = {}
current_model_id: str = None
polisher: TextPolisher = None
scene_polisher: ScenePolisher = None
llm_polisher: LLMPolisher = None
config = {}

# 模型访问锁，防止并发转录导致 MLX 崩溃
model_lock = threading.Lock()

# 后台任务集合，防止被 GC 回收
background_tasks: set = set()

# Plugin system
plugins: list = []

# 用户插件目录
USER_PLUGINS_DIR = Path.home() / "Library" / "Application Support" / "VoiceFlow" / "Plugins"

# 内置插件列表（相对于项目根目录的 Plugins/ 目录）
BUNDLED_PLUGINS = [
    "ChinesePunctuationPlugin",
]


def install_bundled_plugins():
    """将内置插件安装到用户插件目录（首次运行或更新时）"""
    # 获取项目根目录下的 Plugins 目录
    server_dir = Path(__file__).parent
    project_root = server_dir.parent
    bundled_plugins_dir = project_root / "Plugins"

    if not bundled_plugins_dir.exists():
        logger.warning(f"⚠️ 内置插件目录不存在: {bundled_plugins_dir}")
        return

    # 确保用户插件目录存在
    USER_PLUGINS_DIR.mkdir(parents=True, exist_ok=True)

    for plugin_name in BUNDLED_PLUGINS:
        src_dir = bundled_plugins_dir / plugin_name
        dst_dir = USER_PLUGINS_DIR / plugin_name

        if not src_dir.exists():
            logger.warning(f"⚠️ 内置插件不存在: {plugin_name}")
            continue

        # 检查是否需要安装或更新
        src_manifest = src_dir / "manifest.json"
        dst_manifest = dst_dir / "manifest.json"

        should_install = False

        if not dst_dir.exists():
            should_install = True
            logger.info(f"📦 首次安装插件: {plugin_name}")
        elif src_manifest.exists() and dst_manifest.exists():
            # 比较版本号决定是否更新
            try:
                with open(src_manifest, 'r', encoding='utf-8') as f:
                    src_version = json.load(f).get("version", "0.0.0")
                with open(dst_manifest, 'r', encoding='utf-8') as f:
                    dst_version = json.load(f).get("version", "0.0.0")

                if src_version > dst_version:
                    should_install = True
                    logger.info(f"📦 更新插件: {plugin_name} ({dst_version} -> {src_version})")
            except Exception as e:
                logger.warning(f"⚠️ 无法比较插件版本: {e}")

        if should_install:
            try:
                # 删除旧版本（如果存在）
                if dst_dir.exists():
                    shutil.rmtree(dst_dir)

                # 复制插件目录
                shutil.copytree(src_dir, dst_dir)
                logger.info(f"✅ 插件已安装: {plugin_name} -> {dst_dir}")
            except Exception as e:
                logger.error(f"❌ 插件安装失败 {plugin_name}: {e}")


def register_plugin(plugin_func):
    """Register a plugin function to process transcription results.

    Plugin function should accept text (str) and return modified text (str).
    """
    plugins.append(plugin_func)
    logger.info(f"Registered plugin: {plugin_func.__name__}")


def run_plugins(text: str) -> str:
    """Run all registered plugins on the transcribed text."""
    result = text
    for plugin in plugins:
        try:
            result = plugin(result)
        except Exception as e:
            logger.error(f"Plugin {plugin.__name__} failed: {e}")
    return result


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
    # 中国方言（Qwen3-ASR 独占优势）
    "zh-sichuan": "Sichuanese",      # 四川话
    "zh-dongbei": "Northeastern",    # 东北话
    "zh-shanghai": "Shanghainese",   # 上海话
    "zh-minnan": "Hokkien",          # 闽南语
    "zh-hakka": "Hakka",             # 客家话
    "zh-wenzhou": "Wenzhou",         # 温州话
    "zh-changsha": "Changsha",       # 长沙话
    "zh-nanchang": "Nanchang",       # 南昌话
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
    silence_duration_ms: int = 300,
    check_interval_ms: int = 100,
    subtitle_mode: bool = False,
    subtitle_interval_s: float = 1.5
):
    """
    基于 VAD 的流式转录：仅在检测到停顿时触发转录

    Args:
        websocket: WebSocket 连接
        audio_chunks: 音频数据块列表
        model: ASR 模型实例
        language: 语言设置
        silence_threshold: 静音阈值 (RMS)，降低更敏感
        silence_duration_ms: 需要持续静音多久才触发 (毫秒)
        check_interval_ms: 检查间隔 (毫秒)
        subtitle_mode: 字幕模式，启用定时转录
        subtitle_interval_s: 字幕模式下定时转录间隔 (秒)
    """
    silence_frames = 0
    frames_needed = silence_duration_ms // check_interval_ms
    last_transcribed_length = 0
    last_text = ""
    is_transcribing = False  # 防止并发转录
    last_periodic_time = time.monotonic()  # 上次定时转录时间

    # 字幕模式：滑动窗口转录
    subtitle_window_s = 6.0        # 转录窗口大小（秒）
    subtitle_window_samples = int(subtitle_window_s * 16000)
    last_sent_text = ""            # 上次发送给客户端的字幕内容（去重用）

    mode_label = "subtitle" if subtitle_mode else "voice_input"
    logger.info(f"🎙️ VAD 流式转录已启动 (mode={mode_label}, threshold={silence_threshold}, pause={silence_duration_ms}ms, periodic={subtitle_interval_s}s)" if subtitle_mode else f"🎙️ VAD 流式转录已启动 (mode={mode_label}, threshold={silence_threshold}, pause={silence_duration_ms}ms)")

    async def do_transcribe(samples, trigger_reason: str):
        """执行转录并发送结果"""
        nonlocal last_text, last_transcribed_length, is_transcribing
        nonlocal last_sent_text

        if is_transcribing:
            return  # 避免并发转录

        is_transcribing = True
        try:
            if subtitle_mode:
                # 字幕模式：只转录最近 N 秒的音频窗口
                window_samples = samples[-subtitle_window_samples:] if len(samples) > subtitle_window_samples else samples

                def transcribe_window():
                    with model_lock:
                        return model.transcribe((window_samples, 16000), language)

                result = await asyncio.to_thread(transcribe_window)
                text = extract_text(result).strip()
                last_transcribed_length = len(samples)

                if not text or text == last_sent_text:
                    is_transcribing = False
                    return

                last_sent_text = text

                # 只取最后一句（最后一个句末标点之后的部分）作为实时字幕
                # 如果没有句末标点就显示全部
                break_chars = '。！？.!?\n'
                last_break = -1
                for i in range(len(text) - 2, -1, -1):  # 跳过最后一个字符（可能就是标点）
                    if text[i] in break_chars:
                        last_break = i
                        break

                if last_break >= 0:
                    display_text = text[last_break + 1:].strip()
                    if not display_text:
                        display_text = text  # 标点在末尾，显示全部
                else:
                    display_text = text

                await websocket.send(json.dumps({
                    "type": "partial",
                    "text": display_text,
                    "trigger": "periodic"
                }))
                logger.info(f"📝 Subtitle: {display_text}")

            else:
                # 语音输入模式：转录全部音频（保持原有行为）
                def transcribe_with_lock():
                    with model_lock:
                        return model.transcribe((samples, 16000), language)

                result = await asyncio.to_thread(transcribe_with_lock)
                text = extract_text(result)

                if text and text != last_text:
                    last_text = text
                    last_transcribed_length = len(samples)
                    await websocket.send(json.dumps({
                        "type": "partial",
                        "text": text,
                        "trigger": trigger_reason
                    }))
                    logger.info(f"📝 Partial ({trigger_reason}): {text}")

        except Exception as e:
            logger.warning(f"⚠️ 转录失败 ({trigger_reason}): {e}")
        finally:
            is_transcribing = False

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

            # 触发条件1：检测到停顿，且有新音频
            pause_trigger = silence_frames >= frames_needed and len(samples) > last_transcribed_length

            # 触发条件2（仅字幕模式）：定时转录，不等停顿也出字幕
            now = time.monotonic()
            periodic_trigger = (
                subtitle_mode
                and not is_transcribing
                and len(samples) > last_transcribed_length
                and (now - last_periodic_time) >= subtitle_interval_s
            )

            if pause_trigger:
                await do_transcribe(samples, "pause")
                silence_frames = 0
                last_periodic_time = now
            elif periodic_trigger:
                await do_transcribe(samples, "periodic")
                last_periodic_time = now

    except asyncio.CancelledError:
        logger.info("🛑 VAD 流式转录任务已取消")
        raise


def warmup_model():
    """Warm up the model with a short silent audio segment."""
    global polisher, scene_polisher, llm_polisher
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

    # Warmup denoiser to avoid first-call latency
    logger.info("Warming up denoiser...")
    try:
        denoiser = get_denoiser()
        _ = denoiser.denoise(silent_audio, sample_rate=16000)
        logger.info("✅ Denoiser warmup completed.")
    except Exception as e:
        logger.warning(f"⚠️ Denoiser warmup failed: {e}")

    logger.info("Initializing text polisher...")
    polisher = TextPolisher()
    scene_polisher = ScenePolisher(polisher)
    logger.info("✅ Text polisher and scene polisher initialized.")

    # Initialize LLM components (with default config, will be updated by client)
    logger.info("Initializing LLM components...")
    init_llm_client()
    llm_polisher = init_llm_polisher(base_polisher=polisher)
    init_history_analyzer()
    logger.info("✅ LLM polisher and history analyzer initialized.")


async def handle_client(websocket):
    """处理客户端连接"""
    logger.info("客户端已连接")
    audio_chunks: list[bytes] = []
    recording = False
    enable_polish = False
    use_llm_polish = False  # LLM 润色开关
    use_timestamps = False  # 时间戳智能断句开关
    session_model_id = None
    session_language = None
    session_scene = None  # 场景信息
    session_denoise = False  # 降噪开关
    session_hotwords = []  # 自定义词汇表/热词列表
    transcription_task: asyncio.Task = None

    try:
        async for message in websocket:
            if isinstance(message, str):
                data = json.loads(message)
                msg_type = data.get("type")

                if msg_type == "config_llm":
                    # 配置 LLM 连接参数
                    llm_config = LLMConfig.from_dict(data.get("config", {}))
                    llm_client = get_llm_client()
                    if llm_client:
                        llm_client.update_config(llm_config)
                        logger.info(f"🔧 LLM 配置已更新: model={llm_config.model}, url={llm_config.api_url}")
                        await websocket.send(json.dumps({
                            "type": "config_llm_ack",
                            "success": True
                        }))
                    else:
                        await websocket.send(json.dumps({
                            "type": "config_llm_ack",
                            "success": False,
                            "error": "LLM client not initialized"
                        }))

                elif msg_type == "test_llm_connection":
                    # 测试 LLM 连接
                    llm_client = get_llm_client()
                    if llm_client:
                        success, latency = await llm_client.health_check()
                        await websocket.send(json.dumps({
                            "type": "test_llm_connection_result",
                            "success": success,
                            "latency_ms": latency
                        }))
                    else:
                        await websocket.send(json.dumps({
                            "type": "test_llm_connection_result",
                            "success": False,
                            "error": "LLM client not initialized"
                        }))

                elif msg_type == "analyze_history":
                    # 分析录音历史
                    entries = data.get("entries", [])
                    app_name = data.get("app_name", "Unknown")
                    existing_terms = data.get("existing_terms", [])

                    analyzer = get_history_analyzer()
                    if analyzer:
                        result = await analyzer.analyze_app_history(entries, app_name, existing_terms)
                        await websocket.send(json.dumps({
                            "type": "analysis_result",
                            "result": result
                        }))
                    else:
                        await websocket.send(json.dumps({
                            "type": "analysis_result",
                            "error": "History analyzer not initialized"
                        }))

                elif msg_type == "get_default_prompts":
                    # 获取默认提示词
                    await websocket.send(json.dumps({
                        "type": "default_prompts",
                        "prompts": DEFAULT_POLISH_PROMPTS
                    }))
                    logger.info("📤 已发送默认提示词")

                elif msg_type == "get_custom_prompts":
                    # 获取用户自定义提示词
                    prompt_config = get_prompt_config()
                    await websocket.send(json.dumps({
                        "type": "custom_prompts",
                        "prompts": prompt_config.get_all_user_prompts()
                    }))
                    logger.info("📤 已发送用户自定义提示词")

                elif msg_type == "save_custom_prompt":
                    # 保存或重置用户自定义提示词
                    scene_type = data.get("scene_type", "")
                    prompt = data.get("prompt")  # None 表示重置为默认

                    prompt_config = get_prompt_config()
                    try:
                        if prompt is None:
                            # 重置为默认
                            prompt_config.reset_prompt(scene_type)
                            await websocket.send(json.dumps({
                                "type": "save_custom_prompt_ack",
                                "success": True,
                                "scene_type": scene_type,
                                "action": "reset"
                            }))
                            logger.info(f"🔄 已重置场景 '{scene_type}' 为默认提示词")
                        else:
                            # 保存自定义
                            prompt_config.set_prompt(scene_type, prompt)
                            await websocket.send(json.dumps({
                                "type": "save_custom_prompt_ack",
                                "success": True,
                                "scene_type": scene_type,
                                "action": "save"
                            }))
                            logger.info(f"💾 已保存场景 '{scene_type}' 的自定义提示词")
                    except Exception as e:
                        await websocket.send(json.dumps({
                            "type": "save_custom_prompt_ack",
                            "success": False,
                            "scene_type": scene_type,
                            "error": str(e)
                        }))
                        logger.error(f"❌ 保存提示词失败: {e}")

                elif msg_type == "start":
                    enable_polish = data.get("enable_polish") == "true"
                    use_llm_polish = data.get("use_llm_polish", False)  # 新增 LLM 润色开关
                    use_timestamps = data.get("use_timestamps", False)  # 新增时间戳智能断句开关
                    session_model_id = data.get("model_id")
                    lang_code = data.get("language", "auto")
                    session_language = LANGUAGE_MAP.get(lang_code, None)
                    session_scene = data.get("scene", {})  # 解析场景信息
                    active_app = data.get("active_app", {})  # 解析活跃应用信息
                    session_denoise = data.get("enable_denoise", False)  # 解析降噪开关
                    session_mode = data.get("mode", "voice_input")  # 录音模式: voice_input / subtitle
                    session_hotwords = data.get("hotwords", [])  # 解析自定义词汇表/热词列表

                    # 将 active_app 信息合并到 session_scene
                    if active_app:
                        session_scene["active_app"] = active_app

                    # 记录热词信息
                    hotwords_info = f"{len(session_hotwords)} terms" if session_hotwords else "none"
                    logger.info(f"🎤 开始录音. Mode: {session_mode}, Polish: {enable_polish}, LLM: {use_llm_polish}, Timestamps: {use_timestamps}, Denoise: {session_denoise}, Model: {session_model_id}, Language: {lang_code} -> {session_language}, Scene: {session_scene.get('type', 'auto')}, App: {active_app.get('name', 'unknown')}, Hotwords: {hotwords_info}")

                    # 确保模型已加载
                    if session_model_id:
                        get_model(session_model_id)

                    audio_chunks.clear()
                    recording = True

                    # 启动 VAD 流式转录任务
                    is_subtitle = (session_mode == "subtitle")
                    transcription_task = asyncio.create_task(
                        vad_streaming_transcribe(
                            websocket,
                            audio_chunks,
                            get_model(session_model_id),
                            session_language,
                            subtitle_mode=is_subtitle,
                            silence_duration_ms=200 if is_subtitle else 300
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
                        await websocket.send(json.dumps({"type": "final", "text": "", "polish_method": "none"}))
                        continue

                    raw = b"".join(audio_chunks)
                    samples = np.frombuffer(raw, dtype=np.float32)

                    # 注意：降噪已在音频接收时实时处理，此处无需再次降噪

                    duration = len(samples) / 16000
                    logger.info(f"📊 音频: {len(samples)} 采样点 ({duration:.1f}s)")

                    # 使用会话指定的模型和语言
                    model = get_model(session_model_id)
                    language = session_language  # None 表示自动检测

                    # ASR 转录（带超时保护）
                    t0 = time.perf_counter()
                    try:
                        # 使用锁保护模型访问，防止并发崩溃
                        if use_timestamps:
                            # 使用时间戳模式（两阶段处理）
                            def transcribe_with_timestamps_lock():
                                with model_lock:
                                    return model.transcribe_with_timestamps(
                                        audio=(samples, 16000),
                                        language=language
                                    )

                            result = await asyncio.wait_for(
                                asyncio.to_thread(transcribe_with_timestamps_lock),
                                timeout=60.0  # 时间戳模式需要更长超时（两个模型）
                            )
                            # result 是字典: {"text": "...", "words": [...]}
                        else:
                            # 使用普通模式
                            def transcribe_with_lock():
                                with model_lock:
                                    return model.transcribe(audio=(samples, 16000), language=language)

                            result = await asyncio.wait_for(
                                asyncio.to_thread(transcribe_with_lock),
                                timeout=30.0
                            )

                    except asyncio.TimeoutError:
                        timeout_msg = "60s" if use_timestamps else "30s"
                        logger.error(f"❌ ASR 转录超时 ({timeout_msg})")
                        await websocket.send(json.dumps({
                            "type": "final",
                            "text": "",
                            "original_text": "",
                            "polish_method": "none"
                        }))
                        continue

                    elapsed = time.perf_counter() - t0

                    # 提取文本并处理时间戳断句
                    if use_timestamps and isinstance(result, dict):
                        # 时间戳模式：先用时间戳断句
                        words = result.get("words", [])
                        original_text = result.get("text", "")

                        if words:
                            # 使用 TimestampAwarePunctuator 智能断句
                            punctuator = TimestampAwarePunctuator()
                            original_text = punctuator.punctuate(words)
                            logger.info(f"✅ 时间戳断句完成 ({elapsed:.2f}s, {len(words)} 词): {original_text[:50]}...")
                        else:
                            logger.warning("⚠️ 时间戳对齐失败，使用原始文本")
                    else:
                        # 普通模式：提取文本
                        if isinstance(result, str):
                            original_text = result
                        elif isinstance(result, list) and len(result) > 0:
                            original_text = result[0].text if hasattr(result[0], 'text') else str(result[0])
                        elif hasattr(result, 'text'):
                            original_text = result.text
                        else:
                            original_text = str(result)

                        logger.info(f"✅ 转录完成 ({elapsed:.2f}s): {original_text}")

                    # 两步响应策略
                    if enable_polish:
                        # 第一步：立即用规则润色返回 (快速响应)
                        rule_polished_text = scene_polisher.polish(original_text, session_scene)
                        rule_polished_text = run_plugins(rule_polished_text)

                        await websocket.send(json.dumps({
                            "type": "final",
                            "text": rule_polished_text,
                            "original_text": original_text,
                            "polish_method": "rules"
                        }))
                        logger.info(f"⚡ 快速响应 (rules): {rule_polished_text}")

                        # 第二步：后台 LLM 润色（如果启用）
                        llm_pol = get_llm_polisher()
                        logger.info(f"🔍 LLM 条件检查: llm_pol={llm_pol is not None}, use_llm_polish={use_llm_polish}")
                        if llm_pol and use_llm_polish:
                            async def llm_polish_background():
                                try:
                                    logger.info("🚀 后台 LLM 润色任务开始...")
                                    polished_text, polish_method = await llm_pol.polish_async(
                                        original_text, session_scene, use_llm=True
                                    )
                                    logger.info(f"📝 LLM 润色返回: method={polish_method}")
                                    if polish_method == "llm":
                                        # LLM 润色成功，发送更新
                                        polished_text = run_plugins(polished_text)
                                        await websocket.send(json.dumps({
                                            "type": "polish_update",
                                            "text": polished_text
                                        }))
                                        logger.info(f"✨ LLM 润色完成: {polished_text}")
                                    else:
                                        logger.info(f"ℹ️ LLM 未生效，使用 {polish_method} 方法")
                                except Exception as e:
                                    logger.warning(f"⚠️ 后台 LLM 润色失败: {e}", exc_info=True)

                            # 启动后台任务并保存引用防止 GC 回收
                            task = asyncio.create_task(llm_polish_background())
                            background_tasks.add(task)
                            task.add_done_callback(background_tasks.discard)
                    else:
                        # 不启用润色，直接返回原文
                        polished_text = run_plugins(original_text)
                        await websocket.send(json.dumps({
                            "type": "final",
                            "text": polished_text,
                            "original_text": original_text,
                            "polish_method": "none"
                        }))

            elif isinstance(message, bytes) and recording:
                # 解码音频数据（支持格式标识）
                if len(message) > 1:
                    format_id = message[0]

                    if format_id == 0x01:
                        # Float32 格式：跳过格式标识字节
                        samples = np.frombuffer(message[1:], dtype=np.float32)
                    elif format_id == 0x02:
                        # Int16 格式：转换为 Float32
                        audio_data = message[1:]
                        samples = np.frombuffer(audio_data, dtype=np.int16).astype(np.float32) / 32767.0
                    else:
                        # 旧格式（无标识，整个 message 直接是 Float32 数据）
                        samples = np.frombuffer(message, dtype=np.float32)

                    # 实时降噪（在存入 chunks 之前）
                    if session_denoise and len(samples) >= 160:
                        try:
                            denoiser = get_denoiser()
                            if denoiser.is_enabled:
                                samples = denoiser.denoise(samples, sample_rate=16000)
                        except Exception as e:
                            pass  # 静默失败，使用原始音频

                    audio_chunks.append(samples.tobytes())
                else:
                    # 空数据或单字节，忽略
                    pass

    except websockets.exceptions.ConnectionClosed:
        logger.info("客户端断开连接")
    except Exception as e:
        logger.error(f"❌ 错误: {e}", exc_info=True)


async def main():
    load_config()
    install_bundled_plugins()  # 安装内置插件到用户目录
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
