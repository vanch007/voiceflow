#!/usr/bin/env python3
"""Text polisher module for removing filler words and improving grammar."""

import logging
import re

logger = logging.getLogger(__name__)


class SelfCorrectionDetector:
    """Detects and handles self-correction phrases in transcribed text."""

    # 中文纠正词模式
    CHINESE_CORRECTION_PATTERNS = [
        r'不对[，,\s]*',  # "不对，"
        r'我说错了[，,\s]*',  # "我说错了，"
        r'改一下[，,\s]*',  # "改一下，"
        r'应该是[，,\s]*',  # "应该是，" - 保留后面的内容
        r'纠正一下[，,\s]*',  # "纠正一下，"
        r'错了[，,\s]*',  # "错了，"
        r'不是[，,\s]*',  # "不是，" - 需要上下文判断
    ]

    # 英文纠正词模式
    ENGLISH_CORRECTION_PATTERNS = [
        r'\bno wait[,\s]*',  # "no wait,"
        r'\bI mean[,\s]*',  # "I mean,"
        r'\bcorrection[,\s]*',  # "correction,"
        r'\bactually[,\s]*',  # "actually," - 需要上下文
        r'\bsorry[,\s]*',  # "sorry,"
        r'\blet me rephrase[,\s]*',  # "let me rephrase,"
    ]

    def __init__(self):
        # 编译正则表达式
        self.chinese_patterns = [re.compile(p, re.IGNORECASE) for p in self.CHINESE_CORRECTION_PATTERNS]
        self.english_patterns = [re.compile(p, re.IGNORECASE) for p in self.ENGLISH_CORRECTION_PATTERNS]
        logger.info("SelfCorrectionDetector initialized")

    def detect_and_correct(self, text: str) -> str:
        """
        Detect self-correction phrases and remove the corrected content.

        For example:
        - "明天见面，不对，周五见面" -> "周五见面"
        - "I'll call you tomorrow, no wait, next week" -> "next week"

        Args:
            text: The transcribed text

        Returns:
            Text with corrections applied
        """
        if not text or not text.strip():
            return text

        result = text

        # 处理中文纠正
        for pattern in self.chinese_patterns:
            match = pattern.search(result)
            if match:
                # 找到纠正词的位置
                correction_pos = match.start()
                correction_end = match.end()

                # 查找纠正词之前的最近断句符
                before_text = result[:correction_pos]
                sentence_breaks = [m.end() for m in re.finditer(r'[，,。.！!？?\s]', before_text)]

                if sentence_breaks:
                    # 删除从上一个断句到纠正词（包括纠正词）的内容
                    last_break = sentence_breaks[-1]
                    result = result[:last_break] + result[correction_end:]
                else:
                    # 没有断句符，删除开头到纠正词的内容
                    result = result[correction_end:]

                logger.info(f"Self-correction detected (Chinese): '{text}' -> '{result}'")

        # 处理英文纠正
        for pattern in self.english_patterns:
            match = pattern.search(result)
            if match:
                correction_pos = match.start()
                correction_end = match.end()

                before_text = result[:correction_pos]
                sentence_breaks = [m.end() for m in re.finditer(r'[,.\s]', before_text)]

                if sentence_breaks:
                    last_break = sentence_breaks[-1]
                    result = result[:last_break] + result[correction_end:]
                else:
                    result = result[correction_end:]

                logger.info(f"Self-correction detected (English): '{text}' -> '{result}'")

        return result.strip()


class StructuredFormatter:
    """Formats text with list/step structure when detected."""

    # 列表模式检测
    LIST_PATTERNS = [
        r'第[一二三四五六七八九十]+(步|点|条|个)',  # 第一步、第二点
        r'首先|其次|然后|最后|接着|之后',  # 顺序词
        r'\b(first|second|third|then|next|finally)\b',  # 英文顺序词
    ]

    def __init__(self):
        self.list_patterns = [re.compile(p, re.IGNORECASE) for p in self.LIST_PATTERNS]
        logger.info("StructuredFormatter initialized")

    def format_list(self, text: str) -> str:
        """
        Detect and format list/step structures.

        Args:
            text: The transcribed text

        Returns:
            Formatted text with proper list structure
        """
        if not text or not text.strip():
            return text

        # 检测是否包含列表模式
        has_list_pattern = any(p.search(text) for p in self.list_patterns)
        if not has_list_pattern:
            return text

        result = text

        # 在中文序数词前添加换行
        result = re.sub(r'(?<=[。.！!？?\s])?(第[一二三四五六七八九十]+[步点条个])', r'\n\1', result)

        # 在顺序词前添加换行（但不是句首）
        result = re.sub(r'(?<=[。.！!？?\s])(首先|其次|然后|最后|接着|之后)', r'\n\1', result)

        # 清理多余的换行
        result = re.sub(r'\n+', '\n', result)
        result = result.strip()

        if result != text:
            logger.info(f"List formatting applied: '{text[:50]}...' -> '{result[:50]}...'")

        return result


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
        r'怎么说呢[，,\s]*',  # "怎么说呢"
        r'反正[，,\s]*(?=[，。])',  # "反正" 在无实义时删除
    ]

    # English filler words (expanded)
    ENGLISH_FILLERS = [
        r'\bum+\b',
        r'\buh+\b',
        r'\blike\b(?=\s*,)',  # "like," as filler
        r'\byou know\b',
        r'\bbasically\b(?=\s*,)',
        r'\bliterally\b(?=\s*,)',
        r'\bright\b(?=\s*,)',
        r'\bso\b(?=\s*,)',  # "so," as filler
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
        all_fillers = self.CHINESE_FILLERS + self.ENGLISH_FILLERS + self.KOREAN_FILLERS
        # Create pattern that matches fillers with optional surrounding spaces
        self.filler_pattern = re.compile(
            r'\s*(' + '|'.join(all_fillers) + r')\s*',
            re.UNICODE
        )

        # Initialize helper classes
        self.self_correction = SelfCorrectionDetector()
        self.structured_formatter = StructuredFormatter()

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

        # Step 1: Apply self-correction detection
        polished = self.self_correction.detect_and_correct(text)

        # Step 2: Remove filler words
        polished = self.filler_pattern.sub(' ', polished)

        # Step 3: Clean up multiple spaces
        polished = re.sub(r'\s+', ' ', polished)

        # Step 4: Clean up orphaned punctuation at the start
        polished = re.sub(r'^[\s，,。.！!？?、;；:：]+', '', polished)

        # Step 5: Clean up orphaned punctuation patterns
        polished = re.sub(r'[，,]\s*[，,]', '，', polished)
        polished = re.sub(r'[。.]\s*[。.]', '。', polished)

        # Step 6: Strip leading/trailing whitespace
        polished = polished.strip()

        # Step 7: Apply list formatting
        polished = self.structured_formatter.format_list(polished)

        # Step 8: Add period at end if missing
        if polished and not re.search(r'[.!?。！？,，;；:：]$', polished):
            if re.search(r'[\u4e00-\u9fff\uac00-\ud7af]', polished):
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
