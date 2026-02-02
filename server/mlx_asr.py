#!/usr/bin/env python3
"""MLX-based Qwen3-ASR wrapper for Apple Silicon acceleration."""

import logging
from typing import Generator, Tuple, Union

import numpy as np

logger = logging.getLogger(__name__)


class MLXQwen3ASR:
    """MLX版Qwen3-ASR封装，原生支持Apple Silicon GPU加速。"""

    def __init__(self, model_id: str = "mlx-community/Qwen3-ASR-0.6B-8bit"):
        """初始化MLX ASR模型。

        Args:
            model_id: HuggingFace模型ID，默认使用8bit量化版本
        """
        self.model_id = model_id
        self.model = None
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
        language: str = "Chinese"
    ) -> str:
        """同步转录音频。

        Args:
            audio: 音频数据，可以是(samples, sample_rate)元组、numpy数组或文件路径
            language: 语言设置，默认Chinese

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

            result = self.model.generate(audio=audio_input, language=language)
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

    @classmethod
    def from_pretrained(cls, model_id: str = "mlx-community/Qwen3-ASR-0.6B-8bit"):
        """工厂方法，兼容原有接口。

        Args:
            model_id: 模型ID

        Returns:
            MLXQwen3ASR实例
        """
        return cls(model_id=model_id)
