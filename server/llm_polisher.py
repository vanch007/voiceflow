#!/usr/bin/env python3
"""LLM-based text polisher with fallback to rule-based polishing."""

import logging
from typing import Optional, Tuple

from llm_client import LLMClient, get_llm_client
from text_polisher import TextPolisher

logger = logging.getLogger(__name__)


# Default polish prompts for different scenes
DEFAULT_POLISH_PROMPTS = {
    "general": """修正语音识别错误。只输出修正后的文本，不要解释。

示例1:
输入: 他门在那里
输出: 他们在那里

示例2:
输入: 我想要在试一下
输出: 我想要再试一下

示例3:
输入: 嗯嗯那个就是说我觉得
输出: 我觉得

现在修正以下文本：""",

    "coding": """修正语音识别错误，识别编程术语。只输出修正后的文本，不要解释。

术语对照：派森→Python、克劳德→Claude、阿派→API、吉特→Git

示例1:
输入: 我用派森写代码
输出: 我用Python写代码

示例2:
输入: 调用克劳德的阿派
输出: 调用Claude的API

示例3:
输入: 用吉特提交代码
输出: 用Git提交代码

现在修正以下文本：""",

    "writing": """修正语音识别错误，优化标点。只输出修正后的文本，不要解释。

示例1:
输入: 他门去了那里然后又回来了
输出: 他们去了那里，然后又回来了。

示例2:
输入: 这个东西的确很好
输出: 这个东西确实很好。

现在修正以下文本：""",

    "social": """修正语音识别错误。只输出修正后的文本，不要解释，不要改变原意。

示例1:
输入: 他门好厉害
输出: 他们好厉害

示例2:
输入: 在见啊
输出: 再见啊

现在修正以下文本：""",

    "medical": """你是医疗领域的语音识别纠错助手。请修正以下ASR转录文本：

## 核心任务
修正语音识别错误，正确识别医学专业术语。

## 医学术语纠错（高优先级）
1. **检查项目**：西踢/希提→CT、核磁→MRI、心电→ECG/EKG、彩超→B超、批踢→PT、欧踢→OT
2. **药品名称**：阿莫西林、头孢、布洛芬、奥美拉唑、二甲双胍、阿司匹林、氯雷他定
3. **疾病名称**：糖尿病、高血压、冠心病、肺炎、胃炎、肝硬化、甲亢、乙肝
4. **医学缩写**：ICU、CCU、BP（血压）、HR（心率）、SpO2（血氧）、BMI、HbA1c
5. **解剖学**：股骨、胫骨、腓骨、颈椎、腰椎、胸椎、主动脉、冠状动脉
6. **中医术语**：气血、阴阳、经络、穴位、脉象、舌苔、肾虚、脾虚

## 通用ASR错误
- 同音字、近音词、语气词冗余、重复词

## 保留规则
- 药品剂量和用法保持原样
- 检查数值不修改
- 病历描述保持完整

直接输出修正后的文本：""",

    "legal": """你是法律领域的语音识别纠错助手。请修正以下ASR转录文本：

## 核心任务
修正语音识别错误，正确识别法律专业术语。

## 法律术语纠错（高优先级）
1. **诉讼术语**：原告、被告、上诉人、被上诉人、第三人、代理人、辩护人
2. **法律文书**：起诉状、答辩状、判决书、裁定书、调解书、执行令、传票
3. **法条引用**：民法典、刑法、民事诉讼法、刑事诉讼法、公司法、合同法
4. **法院名称**：最高人民法院、高级人民法院、中级人民法院、基层人民法院
5. **合同条款**：甲方、乙方、违约金、定金、订金、保证金、履约保证
6. **法律概念**：管辖权、诉讼时效、举证责任、不可抗力、善意取得、连带责任

## 通用ASR错误
- 同音字（如：权利/权力、法治/法制）、近音词、语气词冗余

## 保留规则
- 法条编号保持原样（如：第XX条第X款）
- 当事人名称不修改
- 金额数字保持完整

直接输出修正后的文本：""",

    "technical": """你是技术标准领域的语音识别纠错助手。请修正以下ASR转录文本：

## 核心任务
修正语音识别错误，正确识别技术标准和硬件术语。

## 技术术语纠错（高优先级）
1. **标准组织**：ISO、IEEE、ANSI、IEC、GB（国标）、ASTM、UL、CE
2. **网络协议**：TCP/IP、HTTP/HTTPS、FTP、SSH、DNS、DHCP、UDP、SMTP
3. **硬件组件**：CPU、GPU、RAM、SSD、HDD、主板、显卡、电源、散热器
4. **接口标准**：USB、HDMI、DisplayPort、Thunderbolt、PCIe、SATA、NVMe
5. **网络设备**：路由器、交换机、防火墙、网关、调制解调器、AP
6. **技术规格**：带宽、延迟、吞吐量、频率、功率、电压、电流

## 通用ASR错误
- 同音字、近音词、语气词冗余、重复词

## 保留规则
- 型号规格保持原样
- 数值单位不修改（如：100Mbps、5GHz）
- 版本号保持完整

直接输出修正后的文本：""",

    "finance": """你是金融领域的语音识别纠错助手。请修正以下ASR转录文本：

## 核心任务
修正语音识别错误，正确识别金融专业术语。

## 金融术语纠错（高优先级）
1. **投资工具**：股票、债券、基金、期货、期权、ETF、理财产品、信托
2. **财务报表**：资产负债表、利润表、现金流量表、所有者权益表
3. **金融指标**：ROI（投资回报率）、ROE（净资产收益率）、PE（市盈率）、PB（市净率）、EPS（每股收益）
4. **交易术语**：多头、空头、做多、做空、平仓、建仓、止损、止盈、杠杆
5. **银行业务**：存款、贷款、利率、汇率、外汇、信用证、承兑汇票
6. **监管机构**：证监会、银保监会、央行、交易所、结算中心

## 通用ASR错误
- 同音字（如：利率/利绿、股市/骨石）、近音词、语气词冗余

## 保留规则
- 金额数字保持原样
- 股票代码不修改
- 日期时间保持完整

直接输出修正后的文本：""",

    "engineering": """你是工程领域的语音识别纠错助手。请修正以下ASR转录文本：

## 核心任务
修正语音识别错误，正确识别工程专业术语。

## 工程术语纠错（高优先级）
1. **材料名称**：不锈钢、碳钢、铝合金、钛合金、铜、塑料、复合材料、玻璃钢
2. **加工工艺**：车削、铣削、钻孔、攻丝、焊接、铸造、锻造、冲压、注塑
3. **设计软件**：CAD、CAM、CAE、SolidWorks、AutoCAD、CATIA、Pro/E、UG/NX
4. **工程标准**：公差、配合、表面粗糙度、硬度、强度、刚度、韧性
5. **测量工具**：卡尺、千分尺、百分表、三坐标、投影仪、粗糙度仪
6. **机械元件**：轴承、齿轮、皮带、链条、联轴器、弹簧、密封圈、螺栓

## 通用ASR错误
- 同音字、近音词、语气词冗余、重复词

## 保留规则
- 尺寸规格保持原样（如：M8×1.25、φ50）
- 公差标注不修改
- 图号编号保持完整

直接输出修正后的文本：""",
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

        # Try LLM polishing if enabled
        if use_llm and self.llm_client:
            try:
                prompt = self._get_prompt(scene)
                polished = await self.llm_client.polish_text(text, prompt)
                polished = polished.strip()
                if polished:
                    logger.info(f"LLM polish success: '{text[:30]}...' -> '{polished[:30]}...'")
                    return polished, "llm"
            except Exception as e:
                logger.warning(f"LLM polish failed, falling back to rules: {e}")

        # Fallback to rule-based polishing
        polished = self.base_polisher.polish(text)
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
