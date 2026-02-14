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
    assert polisher.polish("呃我不太确定") == "我不太确定。"
    assert polisher.polish("哦原来如此") == "原来如此。"

    # "那个"、"然后" 在很多上下文中有意义，不应删除
    assert polisher.polish("那个我想说") == "那个我想说。"
    assert polisher.polish("今天然后明天") == "今天然后明天。"


def test_chinese_filler_e():
    """Test '额' filler removal without affecting real words like '额度'."""
    polisher = TextPolisher()

    # 语气词"额"应被删除（前后有标点/空格/句界）
    assert "额" not in polisher.polish("额，我觉得这个不错")
    assert "额" not in polisher.polish("额 我想想")
    assert "额" not in polisher.polish("今天天气，额，还不错")

    # 含"额"的词语不应被误删
    assert "额度" in polisher.polish("他只给了百分之六十的额度")
    assert "额度" in polisher.polish("额度不够用了")
    assert "金额" in polisher.polish("这笔金额太大了")
    assert "额外" in polisher.polish("额外的费用")
    assert "额外" in polisher.polish("额外收费太多")
    assert "超额" in polisher.polish("超额完成任务")
    assert "差额" in polisher.polish("差额有点多")
    assert "定额" in polisher.polish("定额分配资源")


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
    test_chinese_filler_e()
    test_korean_filler_removal()
    test_punctuation_addition()
    test_empty_input()
    test_whitespace_cleanup()
    print("All tests passed!")
