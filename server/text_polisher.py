#!/usr/bin/env python3
"""Text polisher module for removing filler words and improving grammar."""

import logging
import re

logger = logging.getLogger(__name__)


class TextPolisher:
    """Polishes transcribed text by removing filler words and adding punctuation."""

    # Chinese filler words and patterns
    # 注意：只保留真正的语气词，避免误删有意义的词
    # "这个"、"那个"、"然后" 在很多上下文中是有意义的，不应删除
    CHINESE_FILLERS = [
        r'嗯+',      # um, uh (语气词)
        r'呃+',      # uh (语气词)
        r'啊{2,}',   # ah (只匹配连续2个以上的"啊")
        r'哦+',      # oh (语气词)
        r'额+',      # uh (语气词变体)
        r'(?:^|[，。！？\s])就是说(?=[，。！？\s]|$)',  # "就是说" 只在独立使用时删除
    ]

    # Korean filler words
    KOREAN_FILLERS = [
        r'어+',      # uh
        r'음+',      # um
        r'그+',      # well
        r'저+',      # well
        r'뭐+',      # well
    ]

    def __init__(self):
        """Initialize the text polisher with compiled regex patterns."""
        # Combine all filler patterns
        all_fillers = self.CHINESE_FILLERS + self.KOREAN_FILLERS
        # Create pattern that matches fillers with optional surrounding spaces
        self.filler_pattern = re.compile(
            r'\s*(' + '|'.join(all_fillers) + r')\s*',
            re.UNICODE
        )
        logger.info("TextPolisher initialized with filler word patterns")

    def polish(self, text: str) -> str:
        """
        Polish the input text by removing filler words and improving formatting.

        Args:
            text: The raw transcribed text to polish

        Returns:
            The polished text with filler words removed and basic punctuation added
        """
        if not text or not text.strip():
            return text

        original_text = text
        logger.debug(f"Polishing text: {text[:50]}...")

        # Remove filler words
        polished = self.filler_pattern.sub(' ', text)

        # Clean up multiple spaces
        polished = re.sub(r'\s+', ' ', polished)

        # Clean up orphaned punctuation at the start (e.g., "，那个" -> "，" after removing "那个")
        polished = re.sub(r'^[\s，,。.！!？?、;；:：]+', '', polished)

        # Clean up orphaned punctuation patterns (multiple punctuation marks in a row)
        polished = re.sub(r'[，,]\s*[，,]', '，', polished)
        polished = re.sub(r'[。.]\s*[。.]', '。', polished)

        # Strip leading/trailing whitespace
        polished = polished.strip()

        # Add period at end ONLY if missing and text doesn't end with any punctuation
        if polished and not re.search(r'[.!?。！？,，;；:：]$', polished):
            # Detect if text is primarily Chinese/Korean to choose appropriate punctuation
            if re.search(r'[\u4e00-\u9fff\uac00-\ud7af]', polished):
                # Use Chinese/Korean period
                polished += '。'
            else:
                polished += '.'

        logger.debug(f"Polished result: {polished[:50]}...")
        if polished != original_text:
            logger.info(f"Text polished: '{original_text}' -> '{polished}'")

        return polished

    def polish_with_comparison(self, text: str) -> dict:
        """
        Polish text and return both original and polished versions.

        Args:
            text: The raw transcribed text to polish

        Returns:
            Dictionary with 'original' and 'polished' keys
        """
        return {
            'original': text,
            'polished': self.polish(text)
        }
