#!/usr/bin/env python3
"""User custom prompt configuration manager with persistent storage."""

import json
import logging
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

# 存储位置: ~/Library/Application Support/VoiceFlow/user_prompts.json
USER_PROMPTS_PATH = Path.home() / "Library" / "Application Support" / "VoiceFlow" / "user_prompts.json"


class PromptConfigManager:
    """用户自定义提示词管理器"""

    def __init__(self):
        self._user_prompts: dict = {}
        self._load()

    def _ensure_dir(self) -> None:
        """确保存储目录存在"""
        USER_PROMPTS_PATH.parent.mkdir(parents=True, exist_ok=True)

    def _load(self) -> None:
        """从文件加载用户自定义提示词"""
        try:
            if USER_PROMPTS_PATH.exists():
                with open(USER_PROMPTS_PATH, 'r', encoding='utf-8') as f:
                    self._user_prompts = json.load(f)
                logger.info(f"已加载 {len(self._user_prompts)} 个用户自定义提示词")
            else:
                self._user_prompts = {}
        except Exception as e:
            logger.warning(f"加载用户提示词失败: {e}")
            self._user_prompts = {}

    def _save(self) -> None:
        """保存用户自定义提示词到文件"""
        try:
            self._ensure_dir()
            with open(USER_PROMPTS_PATH, 'w', encoding='utf-8') as f:
                json.dump(self._user_prompts, f, ensure_ascii=False, indent=2)
            logger.info(f"已保存 {len(self._user_prompts)} 个用户自定义提示词")
        except Exception as e:
            logger.error(f"保存用户提示词失败: {e}")

    def get_prompt(self, scene_type: str, default_prompts: dict) -> str:
        """获取提示词，用户自定义优先

        Args:
            scene_type: 场景类型 (如 'general', 'coding', 'medical' 等)
            default_prompts: 默认提示词字典

        Returns:
            提示词字符串，优先返回用户自定义，否则返回默认
        """
        # 用户自定义优先
        if scene_type in self._user_prompts:
            return self._user_prompts[scene_type]

        # 回退到默认
        return default_prompts.get(scene_type, default_prompts.get("general", ""))

    def set_prompt(self, scene_type: str, prompt: str) -> None:
        """保存用户自定义提示词

        Args:
            scene_type: 场景类型
            prompt: 自定义提示词内容
        """
        self._user_prompts[scene_type] = prompt
        self._save()
        logger.info(f"已保存场景 '{scene_type}' 的自定义提示词")

    def reset_prompt(self, scene_type: str) -> None:
        """恢复默认（删除用户自定义）

        Args:
            scene_type: 场景类型
        """
        if scene_type in self._user_prompts:
            del self._user_prompts[scene_type]
            self._save()
            logger.info(f"已重置场景 '{scene_type}' 为默认提示词")

    def get_all_user_prompts(self) -> dict:
        """获取所有用户自定义提示词

        Returns:
            用户自定义提示词字典
        """
        return self._user_prompts.copy()

    def has_custom_prompt(self, scene_type: str) -> bool:
        """检查场景是否有用户自定义提示词

        Args:
            scene_type: 场景类型

        Returns:
            是否存在自定义提示词
        """
        return scene_type in self._user_prompts


# 单例
_config_manager: Optional[PromptConfigManager] = None


def get_prompt_config() -> PromptConfigManager:
    """获取提示词配置管理器单例

    Returns:
        PromptConfigManager 单例实例
    """
    global _config_manager
    if _config_manager is None:
        _config_manager = PromptConfigManager()
    return _config_manager
