#!/usr/bin/env python3
"""OpenAI-compatible LLM client for VoiceFlow text polishing and analysis."""

import asyncio
import logging
from dataclasses import dataclass, field
from typing import Optional

import aiohttp

logger = logging.getLogger(__name__)


@dataclass
class LLMConfig:
    """LLM connection configuration."""
    api_url: str = "http://localhost:11434/v1"  # Ollama default
    api_key: str = ""
    model: str = "qwen2.5:7b"
    temperature: float = 0.3
    max_tokens: int = 512
    timeout: float = 10.0

    def to_dict(self) -> dict:
        return {
            "api_url": self.api_url,
            "api_key": self.api_key,
            "model": self.model,
            "temperature": self.temperature,
            "max_tokens": self.max_tokens,
            "timeout": self.timeout,
        }

    @classmethod
    def from_dict(cls, data: dict) -> "LLMConfig":
        return cls(
            api_url=data.get("api_url", "http://localhost:11434/v1"),
            api_key=data.get("api_key", ""),
            model=data.get("model", "qwen2.5:7b"),
            temperature=data.get("temperature", 0.3),
            max_tokens=data.get("max_tokens", 512),
            timeout=data.get("timeout", 10.0),
        )


class LLMClient:
    """OpenAI-compatible LLM client supporting Ollama, vLLM, OpenAI, etc."""

    def __init__(self, config: Optional[LLMConfig] = None):
        self.config = config or LLMConfig()
        self._session: Optional[aiohttp.ClientSession] = None

    async def _get_session(self) -> aiohttp.ClientSession:
        """Get or create aiohttp session."""
        if self._session is None or self._session.closed:
            timeout = aiohttp.ClientTimeout(total=self.config.timeout)
            self._session = aiohttp.ClientSession(timeout=timeout)
        return self._session

    async def close(self):
        """Close the aiohttp session."""
        if self._session and not self._session.closed:
            await self._session.close()
            self._session = None

    def update_config(self, config: LLMConfig):
        """Update LLM configuration."""
        self.config = config
        logger.info(f"LLM config updated: model={config.model}, url={config.api_url}")

    async def chat_completion(
        self,
        messages: list[dict],
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
    ) -> str:
        """
        Send chat completion request to LLM.

        Args:
            messages: List of message dicts with 'role' and 'content'
            temperature: Override default temperature
            max_tokens: Override default max_tokens

        Returns:
            Generated text response

        Raises:
            Exception: On API errors or timeout
        """
        session = await self._get_session()
        url = f"{self.config.api_url.rstrip('/')}/chat/completions"

        headers = {"Content-Type": "application/json"}
        if self.config.api_key:
            headers["Authorization"] = f"Bearer {self.config.api_key}"

        payload = {
            "model": self.config.model,
            "messages": messages,
            "temperature": temperature if temperature is not None else self.config.temperature,
            "max_tokens": max_tokens if max_tokens is not None else self.config.max_tokens,
            "stream": False,
        }

        try:
            async with session.post(url, json=payload, headers=headers) as resp:
                if resp.status != 200:
                    error_text = await resp.text()
                    raise Exception(f"LLM API error {resp.status}: {error_text}")

                data = await resp.json()
                return data["choices"][0]["message"]["content"]

        except asyncio.TimeoutError:
            raise Exception(f"LLM request timeout after {self.config.timeout}s")
        except aiohttp.ClientError as e:
            raise Exception(f"LLM connection error: {e}")

    async def polish_text(self, text: str, system_prompt: str) -> str:
        """
        Polish transcribed text using LLM.

        Args:
            text: Raw transcribed text
            system_prompt: Scene-specific polishing prompt

        Returns:
            Polished text
        """
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": text},
        ]
        return await self.chat_completion(messages)

    async def analyze_keywords(
        self,
        texts: list[str],
        app_name: str,
        existing_terms: Optional[list[str]] = None,
    ) -> dict:
        """
        Analyze texts to extract keywords and domain-specific terms.

        Args:
            texts: List of transcribed texts to analyze
            app_name: Application name for context
            existing_terms: Already known terms to avoid duplicating

        Returns:
            Dict with 'keywords' and 'suggested_terms' lists
        """
        if not texts:
            return {"keywords": [], "suggested_terms": []}

        # Join texts with newlines, limit to avoid token overflow
        combined_text = "\n".join(texts[:100])  # Limit to 100 entries
        if len(combined_text) > 10000:
            combined_text = combined_text[:10000]

        existing_str = ", ".join(existing_terms) if existing_terms else "无"

        system_prompt = f"""你是一个专业术语分析助手。分析以下来自"{app_name}"应用的语音转录文本，提取：
1. 高频关键词：出现频率高的专业词汇或常用表达
2. 建议术语：可能是专业术语但被ASR错误转录的词，提供正确写法

已有术语（避免重复）：{existing_str}

输出JSON格式：
{{
  "keywords": [
    {{"term": "词汇", "frequency": 5, "confidence": 0.9}}
  ],
  "suggested_terms": [
    {{"original": "可能的错误写法", "correction": "正确写法", "reason": "简短理由"}}
  ]
}}

只输出JSON，不要其他内容。"""

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": combined_text},
        ]

        try:
            response = await self.chat_completion(messages, max_tokens=1024)
            # Parse JSON response
            import json
            # Try to extract JSON from response
            response = response.strip()
            if response.startswith("```"):
                # Remove markdown code block
                lines = response.split("\n")
                response = "\n".join(lines[1:-1])
            return json.loads(response)
        except Exception as e:
            logger.warning(f"Failed to parse keyword analysis: {e}")
            return {"keywords": [], "suggested_terms": []}

    async def health_check(self) -> tuple[bool, Optional[int]]:
        """
        Check if LLM service is available.

        Returns:
            Tuple of (is_healthy, latency_ms)
        """
        import time

        try:
            session = await self._get_session()
            url = f"{self.config.api_url.rstrip('/')}/models"

            headers = {}
            if self.config.api_key:
                headers["Authorization"] = f"Bearer {self.config.api_key}"

            start = time.perf_counter()
            async with session.get(url, headers=headers) as resp:
                latency = int((time.perf_counter() - start) * 1000)
                if resp.status == 200:
                    logger.info(f"LLM health check passed: {latency}ms")
                    return True, latency
                else:
                    logger.warning(f"LLM health check failed: status {resp.status}")
                    return False, None

        except Exception as e:
            logger.warning(f"LLM health check error: {e}")
            return False, None


# Global LLM client instance
_llm_client: Optional[LLMClient] = None


def get_llm_client() -> Optional[LLMClient]:
    """Get global LLM client instance."""
    return _llm_client


def init_llm_client(config: Optional[LLMConfig] = None) -> LLMClient:
    """Initialize global LLM client."""
    global _llm_client
    _llm_client = LLMClient(config)
    logger.info(f"LLM client initialized: {config.model if config else 'default'}")
    return _llm_client


async def shutdown_llm_client():
    """Shutdown global LLM client."""
    global _llm_client
    if _llm_client:
        await _llm_client.close()
        _llm_client = None
        logger.info("LLM client shutdown")
