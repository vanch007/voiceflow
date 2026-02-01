#!/usr/bin/env python3
"""Unit tests for text polisher module."""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from text_polisher import TextPolisher


def test_chinese_filler_removal():
    """Test removal of Chinese filler words."""
    polisher = TextPolisher()

    # Test single filler words
    assert polisher.polish("嗯今天天气很好") == "今天天气很好。"
    assert polisher.polish("那个我想说") == "我想说。"
    assert polisher.polish("今天然后明天") == "今天 明天。"

    # Test multiple fillers
    assert polisher.polish("嗯那个今天天气很好然后") == "今天天气很好。"


def test_korean_filler_removal():
    """Test removal of Korean filler words."""
    polisher = TextPolisher()

    assert polisher.polish("어 오늘 날씨") == "오늘 날씨。"
    assert polisher.polish("음 그것은") == "것은。"


def test_punctuation_addition():
    """Test automatic punctuation addition."""
    polisher = TextPolisher()

    # Should add period for Chinese text
    assert polisher.polish("今天天气很好").endswith("。")

    # Should not add if already present
    assert polisher.polish("今天天气很好。") == "今天天气很好。"
    assert polisher.polish("今天天气很好!") == "今天天气很好!"


def test_empty_input():
    """Test handling of empty or whitespace input."""
    polisher = TextPolisher()

    assert polisher.polish("") == ""
    # Whitespace-only input is returned as-is per the polisher logic
    assert polisher.polish("   ") == "   "


def test_whitespace_cleanup():
    """Test cleanup of excessive whitespace."""
    polisher = TextPolisher()

    # Multiple spaces should be collapsed
    result = polisher.polish("今天  天气  很好")
    assert "  " not in result
    assert result == "今天 天气 很好。"


if __name__ == "__main__":
    test_chinese_filler_removal()
    test_korean_filler_removal()
    test_punctuation_addition()
    test_empty_input()
    test_whitespace_cleanup()
    print("All tests passed!")
