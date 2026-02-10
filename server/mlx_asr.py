#!/usr/bin/env python3
"""MLX-based Qwen3-ASR wrapper for Apple Silicon acceleration."""

import logging
from typing import Dict, Generator, List, Tuple, Union

import numpy as np

logger = logging.getLogger(__name__)


class MLXQwen3ForcedAligner:
    """MLX版Qwen3-ForcedAligner封装，用于词级时间戳对齐。"""

    def __init__(self, model_id: str = "mlx-community/Qwen3-ForcedAligner-0.6B-8bit"):
        """初始化ForcedAligner模型。

        Args:
            model_id: HuggingFace模型ID，默认使用8bit量化版本
        """
        self.model_id = model_id
        self.model = None
        self._load_model()

    def _load_model(self):
        """加载ForcedAligner模型。"""
        try:
            from mlx_audio.stt import load
            logger.info(f"正在加载ForcedAligner模型: {self.model_id}")
            self.model = load(self.model_id)
            logger.info(f"✅ ForcedAligner模型加载成功: {self.model_id}")
        except ImportError as e:
            logger.error(f"❌ 缺少mlx-audio依赖: {e}")
            logger.error("请运行: pip install mlx-audio")
            raise
        except Exception as e:
            logger.error(f"❌ ForcedAligner模型加载失败: {e}")
            raise

    def align(
        self,
        audio: Union[np.ndarray, Tuple[np.ndarray, int]],
        text: str,
        language: str = "Chinese"
    ) -> Dict[str, Union[str, List[Dict[str, Union[str, float]]]]]:
        """对音频和文本进行强制对齐，生成词级时间戳。

        Args:
            audio: 音频数据，可以是numpy数组或(samples, sample_rate)元组
            text: ASR识别的文本
            language: 语言设置，默认Chinese

        Returns:
            {
                "text": "完整文本",
                "words": [
                    {"word": "今天", "start": 0.0, "end": 0.5},
                    {"word": "天气", "start": 0.5, "end": 1.0},
                    ...
                ]
            }
        """
        if self.model is None:
            raise RuntimeError("ForcedAligner模型未加载")

        try:
            # 处理音频输入格式
            if isinstance(audio, tuple):
                audio_input, _ = audio
            else:
                audio_input = audio

            # 调用ForcedAligner
            logger.debug(f"ForcedAligner对齐文本: {text[:50]}...")
            result = self.model.generate(audio=audio_input, text=text, language=language)

            # 解析返回结果
            words = []
            if hasattr(result, 'segments'):
                # 使用segments属性（返回list of dict）
                for seg in result.segments:
                    words.append({
                        "word": seg.get("text", ""),
                        "start": seg.get("start", 0.0),
                        "end": seg.get("end", 0.0)
                    })
            elif hasattr(result, 'items'):
                # 使用items属性（返回list of ForcedAlignItem）
                for item in result.items:
                    words.append({
                        "word": item.text,
                        "start": item.start_time,
                        "end": item.end_time
                    })
            else:
                logger.warning("ForcedAligner返回结果格式未知，降级为无时间戳模式")

            return {
                "text": text,
                "words": words
            }
        except Exception as e:
            logger.error(f"❌ ForcedAligner对齐失败: {e}")
            # 降级：返回无时间戳的结果
            logger.warning("降级为无时间戳模式")
            return {
                "text": text,
                "words": []
            }


class MLXQwen3ASR:
    """MLX版Qwen3-ASR封装，原生支持Apple Silicon GPU加速。"""

    def __init__(self, model_id: str = "mlx-community/Qwen3-ASR-0.6B-8bit"):
        """初始化MLX ASR模型。

        Args:
            model_id: HuggingFace模型ID，默认使用8bit量化版本
        """
        self.model_id = model_id
        self.model = None
        self.aligner = None  # 延迟加载ForcedAligner
        self._load_model()

    def _load_model(self):
        """加载MLX模型。"""
        try:
            from mlx_audio.stt import load
            logger.info(f"正在加载MLX模型: {self.model_id}")
            self.model = load(self.model_id)
            logger.info(f"✅ MLX模型加载成功: {self.model_id}")
        except ImportError as e:
            logger.error(f"❌ 缺少mlx-audio依赖: {e}")
            logger.error("请运行: pip install mlx-audio")
            raise
        except Exception as e:
            logger.error(f"❌ 模型加载失败: {e}")
            raise

    def transcribe(
        self,
        audio: Union[Tuple[np.ndarray, int], str, np.ndarray],
        language: str = None,
        hotwords: List[str] = None
    ) -> str:
        """同步转录音频。

        Args:
            audio: 音频数据，可以是(samples, sample_rate)元组、numpy数组或文件路径
            language: 语言设置，默认Chinese
            hotwords: 热词列表，用于ASR偏向识别

        Returns:
            转录文本
        """
        if self.model is None:
            raise RuntimeError("模型未加载")

        try:
            # 处理音频输入格式
            if isinstance(audio, tuple):
                samples, sample_rate = audio
                # mlx-audio期望直接传numpy数组
                audio_input = samples
            else:
                audio_input = audio

            # 构建 generate() 参数
            generate_kwargs = {"audio": audio_input}

            # 添加语言参数（如果不是自动检测）
            if language is not None:
                generate_kwargs["language"] = language

            # 添加热词上下文（如果提供）
            if hotwords and len(hotwords) > 0:
                generate_kwargs["context"] = hotwords
                logger.debug(f"🎯 使用热词: {len(hotwords)} 个 - {hotwords[:5]}...")

            # 调用 ASR 模型
            try:
                result = self.model.generate(**generate_kwargs)
            except TypeError as e:
                # 如果 context 参数不支持，回退到无热词模式
                if "context" in str(e) and hotwords:
                    logger.warning(f"⚠️ MLX ASR 不支持 context 参数，忽略热词")
                    generate_kwargs.pop("context", None)
                    result = self.model.generate(**generate_kwargs)
                else:
                    raise

            # 处理不同返回类型
            if isinstance(result, str):
                return result
            elif hasattr(result, 'text'):
                return result.text
            elif isinstance(result, dict) and 'text' in result:
                return result['text']
            else:
                return str(result)
        except Exception as e:
            logger.error(f"❌ 转录失败: {e}")
            raise

    def stream_transcribe(
        self,
        audio: Union[Tuple[np.ndarray, int], str],
        language: str = "Chinese"
    ) -> Generator[str, None, None]:
        """流式转录音频（如果模型支持）。

        Args:
            audio: 音频数据
            language: 语言设置

        Yields:
            部分转录文本
        """
        if self.model is None:
            raise RuntimeError("模型未加载")

        try:
            # 检查模型是否支持流式转录
            if hasattr(self.model, 'stream_transcribe'):
                for text in self.model.stream_transcribe(audio=audio, language=language):
                    yield text
            elif hasattr(self.model, 'stream_generate'):
                for text in self.model.stream_generate(audio=audio, language=language):
                    yield text
            else:
                # 回退到同步模式
                logger.debug("模型不支持流式转录，使用同步模式")
                yield self.transcribe(audio, language)
        except Exception as e:
            logger.error(f"❌ 流式转录失败: {e}")
            raise

    def transcribe_with_timestamps(
        self,
        audio: Union[Tuple[np.ndarray, int], str, np.ndarray],
        language: str = None,
        hotwords: List[str] = None
    ) -> Dict[str, Union[str, List[Dict[str, Union[str, float]]]]]:
        """转录音频并返回词级时间戳。

        两阶段处理：
        1. 使用ASR模型识别文本
        2. 使用ForcedAligner模型生成时间戳

        Args:
            audio: 音频数据，可以是(samples, sample_rate)元组、numpy数组或文件路径
            language: 语言设置，None表示自动检测
            hotwords: 热词列表，用于ASR偏向识别

        Returns:
            {
                "text": "完整转录文本",
                "words": [
                    {"word": "今天", "start": 0.0, "end": 0.5},
                    {"word": "天气", "start": 0.5, "end": 1.0},
                    ...
                ]
            }
        """
        # 阶段1: ASR识别（传递热词）
        asr_text = self.transcribe(audio, language, hotwords)

        if not asr_text or not asr_text.strip():
            logger.warning("ASR识别结果为空，跳过时间戳对齐")
            return {
                "text": asr_text,
                "words": []
            }

        # 阶段2: ForcedAligner对齐
        try:
            # 延迟加载ForcedAligner（仅在首次使用时加载）
            if self.aligner is None:
                logger.info("首次使用时间戳功能，正在加载ForcedAligner...")
                self.aligner = MLXQwen3ForcedAligner()

            # 使用与ASR相同的language参数，如果为None则使用默认Chinese
            align_language = language if language is not None else "Chinese"
            alignment_result = self.aligner.align(audio, asr_text, align_language)

            logger.info(f"✅ 时间戳对齐完成，共 {len(alignment_result['words'])} 个词")
            return alignment_result

        except Exception as e:
            logger.error(f"❌ 时间戳对齐失败: {e}")
            # 降级：返回无时间戳的ASR结果
            logger.warning("降级为无时间戳模式")
            return {
                "text": asr_text,
                "words": []
            }

    @classmethod
    def from_pretrained(cls, model_id: str = "mlx-community/Qwen3-ASR-0.6B-8bit"):
        """工厂方法，兼容原有接口。

        Args:
            model_id: 模型ID

        Returns:
            MLXQwen3ASR实例
        """
        return cls(model_id=model_id)
