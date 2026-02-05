#!/usr/bin/env python3
"""LLM-based text polisher with fallback to rule-based polishing."""

import logging
from typing import Optional, Tuple

from llm_client import LLMClient, get_llm_client
from text_polisher import TextPolisher

logger = logging.getLogger(__name__)


# Default polish prompts for different scenes
DEFAULT_POLISH_PROMPTS = {
    "general": """你是一个语音转文字的后处理助手。请对以下语音识别结果进行润色：
1. 修正明显的语音识别错误
2. 删除口语化的语气词（嗯、啊、那个等）
3. 添加适当的标点符号
4. 保持原意，不要添加或删除实质内容
5. 如果用户使用纠正语（如"不对"、"应该是"），移除被纠正部分，只保留纠正后内容

直接输出润色后的文本，不要任何解释。""",

    "coding": """你是一个编程场景的语音转文字助手。请润色以下语音识别结果：
1. 识别并正确格式化代码相关术语（变量名、函数名、技术术语）
2. 修正常见的编程术语识别错误
3. 删除口语化表达
4. 保持技术准确性
5. 如果用户使用纠正语，移除被纠正部分

直接输出润色后的文本，不要任何解释。""",

    "writing": """你是一个写作场景的语音转文字助手。请润色以下语音识别结果：
1. 修正语法错误和不通顺的表达
2. 优化句子结构，使其更加书面化
3. 添加适当的标点符号
4. 保持原意和风格
5. 如果用户使用纠正语，移除被纠正部分

直接输出润色后的文本，不要任何解释。""",

    "social": """你是一个社交聊天场景的语音转文字助手。请润色以下语音识别结果：
1. 保持口语化和轻松的风格
2. 修正明显的识别错误
3. 适当保留一些表达情感的语气词
4. 添加适当的标点和表情提示
5. 如果用户使用纠正语，移除被纠正部分

直接输出润色后的文本，不要任何解释。""",
}

# 应用 Bundle ID 到场景类型的映射
APP_SCENE_MAPPING = {
    # 邮件应用 -> 正式风格
    "com.apple.mail": "formal",
    "com.readdle.smartemail": "formal",
    "com.microsoft.Outlook": "formal",
    "com.sparkmailapp.Spark": "formal",

    # 聊天应用 -> 社交风格
    "com.tencent.xinWeChat": "social",
    "com.apple.MobileSMS": "social",
    "com.slack.Slack": "social",
    "com.discord.Discord": "social",
    "com.telegram.desktop": "social",
    "com.whatsapp.WhatsApp": "social",

    # IDE/编辑器 -> 技术风格
    "com.microsoft.VSCode": "coding",
    "com.apple.dt.Xcode": "coding",
    "com.jetbrains.intellij": "coding",
    "com.sublimehq.Sublime-Text": "coding",
    "com.googlecode.iterm2": "coding",
    "com.apple.Terminal": "coding",

    # 文档应用 -> 写作风格
    "com.apple.iWork.Pages": "writing",
    "com.microsoft.Word": "writing",
    "notion.id": "writing",
    "com.google.Chrome": "writing",  # 可能是文档编辑
}

# 应用名称到场景类型的映射（备用）
APP_NAME_SCENE_MAPPING = {
    "mail": "formal",
    "outlook": "formal",
    "spark": "formal",
    "微信": "social",
    "wechat": "social",
    "slack": "social",
    "discord": "social",
    "telegram": "social",
    "whatsapp": "social",
    "messages": "social",
    "信息": "social",
    "vscode": "coding",
    "visual studio code": "coding",
    "xcode": "coding",
    "terminal": "coding",
    "终端": "coding",
    "iterm": "coding",
    "pages": "writing",
    "word": "writing",
    "notion": "writing",
}


class LLMPolisher:
    """LLM-based text polisher with rule-based fallback."""

    def __init__(
        self,
        llm_client: Optional[LLMClient] = None,
        base_polisher: Optional[TextPolisher] = None,
    ):
        """
        Initialize LLM polisher.

        Args:
            llm_client: LLM client instance (uses global if not provided)
            base_polisher: Rule-based polisher for fallback
        """
        self._llm_client = llm_client
        self.base_polisher = base_polisher or TextPolisher()

    @property
    def llm_client(self) -> Optional[LLMClient]:
        """Get LLM client, preferring instance then global."""
        return self._llm_client or get_llm_client()

    def _apply_glossary(self, text: str, glossary: list[dict]) -> str:
        """
        Apply glossary term replacements.

        Args:
            text: Input text
            glossary: List of glossary entries with 'term', 'replacement', 'case_sensitive'

        Returns:
            Text with glossary terms replaced
        """
        if not glossary:
            return text

        result = text
        for entry in glossary:
            term = entry.get("term", "")
            replacement = entry.get("replacement", "")
            case_sensitive = entry.get("case_sensitive", False)

            if not term or not replacement:
                continue

            if case_sensitive:
                result = result.replace(term, replacement)
            else:
                # Case-insensitive replacement
                import re
                pattern = re.compile(re.escape(term), re.IGNORECASE)
                result = pattern.sub(replacement, result)

        return result

    def _get_prompt(self, scene: dict) -> str:
        """
        Get polishing prompt for scene.

        Args:
            scene: Scene info dict with 'type', 'custom_prompt', 'polish_style'

        Returns:
            Prompt string
        """
        # First check for custom prompt
        custom_prompt = scene.get("custom_prompt")
        if custom_prompt:
            return custom_prompt

        # Check for active app context (for automatic style adaptation)
        active_app = scene.get("active_app", {})
        if active_app:
            bundle_id = active_app.get("bundle_id", "")
            app_name = active_app.get("name", "").lower()

            # Try bundle ID mapping first
            if bundle_id in APP_SCENE_MAPPING:
                scene_type = APP_SCENE_MAPPING[bundle_id]
                logger.info(f"Auto-detected scene from bundle_id: {bundle_id} -> {scene_type}")
                return DEFAULT_POLISH_PROMPTS.get(scene_type, DEFAULT_POLISH_PROMPTS["general"])

            # Try app name mapping
            for name_pattern, mapped_scene in APP_NAME_SCENE_MAPPING.items():
                if name_pattern in app_name:
                    logger.info(f"Auto-detected scene from app_name: {app_name} -> {mapped_scene}")
                    return DEFAULT_POLISH_PROMPTS.get(mapped_scene, DEFAULT_POLISH_PROMPTS["general"])

        # Fall back to scene type default
        scene_type = scene.get("type", "general")
        return DEFAULT_POLISH_PROMPTS.get(scene_type, DEFAULT_POLISH_PROMPTS["general"])

    async def polish_async(
        self,
        text: str,
        scene: Optional[dict] = None,
        use_llm: bool = True,
    ) -> Tuple[str, str]:
        """
        Polish text asynchronously.

        Args:
            text: Raw transcribed text
            scene: Scene configuration dict
            use_llm: Whether to attempt LLM polishing

        Returns:
            Tuple of (polished_text, polish_method: 'llm'|'rules'|'none')
        """
        if not text or not text.strip():
            return text, "none"

        scene = scene or {}

        # Step 1: Apply glossary replacements (always)
        glossary = scene.get("glossary", [])
        text_with_glossary = self._apply_glossary(text, glossary)

        # Step 2: Try LLM polishing if enabled
        if use_llm and self.llm_client:
            try:
                prompt = self._get_prompt(scene)
                polished = await self.llm_client.polish_text(text_with_glossary, prompt)
                polished = polished.strip()
                if polished:
                    logger.info(f"LLM polish success: '{text[:30]}...' -> '{polished[:30]}...'")
                    return polished, "llm"
            except Exception as e:
                logger.warning(f"LLM polish failed, falling back to rules: {e}")

        # Step 3: Fallback to rule-based polishing
        polished = self.base_polisher.polish(text_with_glossary)
        return polished, "rules"

    def polish(
        self,
        text: str,
        scene: Optional[dict] = None,
        use_llm: bool = True,
    ) -> Tuple[str, str]:
        """
        Synchronous wrapper for polish_async.

        For use in sync contexts. Creates new event loop if needed.
        """
        import asyncio

        try:
            loop = asyncio.get_running_loop()
            # Already in async context, create task
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as executor:
                future = executor.submit(
                    asyncio.run,
                    self.polish_async(text, scene, use_llm)
                )
                return future.result(timeout=15.0)
        except RuntimeError:
            # No running loop, safe to use asyncio.run
            return asyncio.run(self.polish_async(text, scene, use_llm))


# Global LLM polisher instance
_llm_polisher: Optional[LLMPolisher] = None


def get_llm_polisher() -> Optional[LLMPolisher]:
    """Get global LLM polisher instance."""
    return _llm_polisher


def init_llm_polisher(
    llm_client: Optional[LLMClient] = None,
    base_polisher: Optional[TextPolisher] = None,
) -> LLMPolisher:
    """Initialize global LLM polisher."""
    global _llm_polisher
    _llm_polisher = LLMPolisher(llm_client, base_polisher)
    logger.info("LLM polisher initialized")
    return _llm_polisher
