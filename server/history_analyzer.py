#!/usr/bin/env python3
"""History analyzer for extracting keywords and terms from recording history."""

import logging
from collections import Counter
from typing import Optional
import re

from llm_client import LLMClient, get_llm_client

logger = logging.getLogger(__name__)


class HistoryAnalyzer:
    """Analyzes recording history to extract keywords and suggest terms."""

    def __init__(self, llm_client: Optional[LLMClient] = None):
        """
        Initialize history analyzer.

        Args:
            llm_client: LLM client for intelligent analysis
        """
        self._llm_client = llm_client

    @property
    def llm_client(self) -> Optional[LLMClient]:
        """Get LLM client, preferring instance then global."""
        return self._llm_client or get_llm_client()

    def _extract_words(self, text: str) -> list[str]:
        """Extract words from text, handling both CJK and Latin."""
        words = []

        # Extract CJK words (Chinese/Japanese/Korean)
        cjk_pattern = re.compile(r'[\u4e00-\u9fff\u3400-\u4dbf\uac00-\ud7af]+')
        cjk_matches = cjk_pattern.findall(text)
        words.extend(cjk_matches)

        # Extract Latin words
        latin_pattern = re.compile(r'[a-zA-Z]+')
        latin_matches = latin_pattern.findall(text)
        words.extend([w.lower() for w in latin_matches if len(w) > 1])

        return words

    def _local_word_frequency(self, texts: list[str]) -> list[dict]:
        """
        Calculate local word frequency without LLM.

        Args:
            texts: List of transcribed texts

        Returns:
            List of keyword entries with term and frequency
        """
        all_words = []
        for text in texts:
            all_words.extend(self._extract_words(text))

        # Count frequencies
        counter = Counter(all_words)

        # Filter and format results
        keywords = []
        for term, freq in counter.most_common(50):
            if freq >= 2 and len(term) >= 2:  # At least 2 occurrences, 2+ chars
                keywords.append({
                    "term": term,
                    "frequency": freq,
                    "confidence": min(1.0, freq / 10),  # Simple confidence
                })

        return keywords

    async def analyze_app_history(
        self,
        entries: list[dict],
        app_name: str,
        existing_terms: Optional[list[str]] = None,
    ) -> dict:
        """
        Analyze recording history for an application.

        Args:
            entries: List of recording entries with 'text' field
            app_name: Application name for context
            existing_terms: Already known terms to avoid duplicating

        Returns:
            Analysis result dict with keywords and suggested_terms
        """
        if not entries:
            return {
                "app_name": app_name,
                "analyzed_count": 0,
                "keywords": [],
                "suggested_terms": [],
            }

        # Extract texts from entries
        texts = [e.get("text", "") for e in entries if e.get("text")]

        # Local word frequency analysis
        local_keywords = self._local_word_frequency(texts)

        # Try LLM analysis for intelligent term extraction
        suggested_terms = []
        llm_keywords = []

        if self.llm_client:
            try:
                result = await self.llm_client.analyze_keywords(
                    texts, app_name, existing_terms
                )
                llm_keywords = result.get("keywords", [])
                suggested_terms = result.get("suggested_terms", [])
                logger.info(f"LLM analysis complete: {len(llm_keywords)} keywords, {len(suggested_terms)} suggestions")
            except Exception as e:
                logger.warning(f"LLM analysis failed, using local only: {e}")

        # Merge local and LLM keywords
        merged_keywords = self._merge_keywords(local_keywords, llm_keywords)

        return {
            "app_name": app_name,
            "analyzed_count": len(entries),
            "keywords": merged_keywords[:30],  # Top 30
            "suggested_terms": suggested_terms[:20],  # Top 20
        }

    def _merge_keywords(
        self,
        local: list[dict],
        llm: list[dict],
    ) -> list[dict]:
        """Merge local and LLM keyword results."""
        # Create lookup by term
        merged = {k["term"]: k for k in local}

        # Add/update with LLM results (higher confidence)
        for kw in llm:
            term = kw.get("term", "")
            if term in merged:
                # Update confidence if LLM has higher
                if kw.get("confidence", 0) > merged[term].get("confidence", 0):
                    merged[term]["confidence"] = kw["confidence"]
            else:
                merged[term] = kw

        # Sort by frequency then confidence
        result = list(merged.values())
        result.sort(key=lambda x: (x.get("frequency", 0), x.get("confidence", 0)), reverse=True)

        return result

    def analyze_sync(
        self,
        entries: list[dict],
        app_name: str,
        existing_terms: Optional[list[str]] = None,
    ) -> dict:
        """Synchronous wrapper for analyze_app_history."""
        import asyncio

        try:
            loop = asyncio.get_running_loop()
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as executor:
                future = executor.submit(
                    asyncio.run,
                    self.analyze_app_history(entries, app_name, existing_terms)
                )
                return future.result(timeout=30.0)
        except RuntimeError:
            return asyncio.run(
                self.analyze_app_history(entries, app_name, existing_terms)
            )


# Global analyzer instance
_history_analyzer: Optional[HistoryAnalyzer] = None


def get_history_analyzer() -> Optional[HistoryAnalyzer]:
    """Get global history analyzer instance."""
    return _history_analyzer


def init_history_analyzer(llm_client: Optional[LLMClient] = None) -> HistoryAnalyzer:
    """Initialize global history analyzer."""
    global _history_analyzer
    _history_analyzer = HistoryAnalyzer(llm_client)
    logger.info("History analyzer initialized")
    return _history_analyzer
