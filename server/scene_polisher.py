#!/usr/bin/env python3
"""Scene-aware text polisher for VoiceFlow."""

import logging
import re
from text_polisher import TextPolisher

logger = logging.getLogger(__name__)


class ScenePolisher:
    """Polishes transcribed text based on scene context."""

    # 场景风格对应的润色提示词（丰富版）
    STYLE_PROMPTS = {
        "casual": """将语音转录文本转换为适合社交聊天的形式：
- 保持口语化、简短自然
- 保留语气词和情感表达（如"哈哈"、"嗯"、"啊"）
- 不需要严格的标点符号
- 可以使用网络流行语和表情符号""",

        "formal": """将语音转录文本转换为正式书面语：
- 使用完整的句子结构
- 添加恰当的标点符号
- 去除口语化的语气词
- 确保逻辑清晰、段落分明""",

        "technical": """将语音转录文本转换为适合编程场景的形式：
- 严格保留代码术语、变量名、函数名
- 不翻译英文技术词汇（如 API、JSON、function）
- 保持专业准确，避免口语化表达
- 数字和符号保持原样""",

        "neutral": """对语音转录文本做最小程度的修正：
- 保持原意不变
- 仅修正明显的语法错误
- 添加基本标点符号""",
    }

    # 场景类型对应的默认风格
    SCENE_DEFAULT_STYLES = {
        "social": "casual",
        "coding": "technical",
        "writing": "formal",
        "general": "neutral",
    }

    def __init__(self, base_polisher: TextPolisher = None):
        """Initialize scene polisher with optional base polisher.

        Args:
            base_polisher: Base TextPolisher instance. If None, creates new one.
        """
        self.base_polisher = base_polisher or TextPolisher()
        logger.info("ScenePolisher initialized")

    def apply_glossary(self, text: str, glossary: list) -> str:
        """Apply glossary term replacements to text.

        Args:
            text: The text to process
            glossary: List of glossary entries, each with:
                      - term: The term to find
                      - replacement: The replacement text
                      - case_sensitive: Whether matching is case-sensitive

        Returns:
            Text with glossary terms replaced
        """
        if not text or not glossary:
            return text

        result = text
        for entry in glossary:
            term = entry.get("term", "")
            replacement = entry.get("replacement", "")
            case_sensitive = entry.get("case_sensitive", False)

            if not term or not replacement:
                continue

            try:
                if case_sensitive:
                    # 区分大小写的简单替换
                    result = result.replace(term, replacement)
                else:
                    # 不区分大小写的替换
                    pattern = re.compile(re.escape(term), re.IGNORECASE)
                    result = pattern.sub(replacement, result)

                if term in text or (not case_sensitive and term.lower() in text.lower()):
                    logger.debug(f"Glossary: '{term}' -> '{replacement}'")

            except Exception as e:
                logger.warning(f"Glossary replacement failed for '{term}': {e}")
                continue

        return result

    def polish(self, text: str, scene: dict = None) -> str:
        """Polish text based on scene context.

        Args:
            text: The raw transcribed text to polish
            scene: Scene context dictionary with optional keys:
                   - type: Scene type (social/coding/writing/general)
                   - polish_style: Polish style (casual/formal/technical/neutral)
                   - custom_prompt: Custom prompt to use instead of default
                   - glossary: List of term replacement entries

        Returns:
            The polished text
        """
        if not text or not text.strip():
            return text

        if scene is None:
            scene = {}

        # 获取场景类型和润色风格
        scene_type = scene.get("type", "general")
        polish_style = scene.get("polish_style")
        custom_prompt = scene.get("custom_prompt")
        glossary = scene.get("glossary", [])

        # 如果没有指定风格，使用场景默认风格
        if not polish_style:
            polish_style = self.SCENE_DEFAULT_STYLES.get(scene_type, "neutral")

        logger.info(f"Polishing with scene={scene_type}, style={polish_style}, glossary_count={len(glossary)}")

        # 第一步：应用术语字典替换
        text = self.apply_glossary(text, glossary)

        # 如果有自定义提示词，使用它
        if custom_prompt:
            return self._polish_with_prompt(text, custom_prompt)

        # 使用风格对应的提示词
        prompt = self.STYLE_PROMPTS.get(polish_style, self.STYLE_PROMPTS["neutral"])
        return self._polish_with_prompt(text, prompt)

    def _polish_with_prompt(self, text: str, prompt: str) -> str:
        """Polish text with a specific prompt.

        For now, we use the base polisher's simple rule-based approach.
        In the future, this could integrate with an LLM for more sophisticated polishing.

        Args:
            text: The text to polish
            prompt: The prompt describing the desired polishing style

        Returns:
            The polished text
        """
        # 目前使用基础润色器的规则
        # 后续可以扩展为调用 LLM 进行更智能的润色
        result = self.base_polisher.polish(text)

        logger.debug(f"Polished with prompt '{prompt[:30]}...': {text[:50]}... -> {result[:50]}...")
        return result

    def polish_for_scene_type(self, text: str, scene_type: str) -> str:
        """Convenience method to polish text for a specific scene type.

        Args:
            text: The text to polish
            scene_type: The scene type (social/coding/writing/general)

        Returns:
            The polished text
        """
        return self.polish(text, {"type": scene_type})
