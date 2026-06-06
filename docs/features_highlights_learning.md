# SoulTalk 特性亮点与开发学习笔记

本文档用于开发学习，帮助快速理解 SoulTalk 的产品亮点、核心模块和可借鉴的工程设计。

## 1. 产品定位

SoulTalk 是一款 AI 驱动的微信风格社交应用。

它不是普通的单窗口 Chat App，而是围绕 AI 角色构建了完整的社交体验，包括：

- 聊天
- 通讯录
- 发现 / 朋友圈
- 个人中心
- 角色卡
- 长期记忆
- 主动消息
- API 配置与余额管理
- 数据备份与恢复

一句话概括：

> SoulTalk 试图把 AI 角色从“聊天机器人”升级成“有记忆、有动态、有关系感的虚拟社交对象”。

## 2. 核心亮点总览

| 亮点 | 说明 | 学习价值 |
|---|---|---|
| 微信风格 UI | 底部导航：聊天、通讯录、发现、我 | 学习 Flutter 多页面 App 结构 |
| 三层记忆系统 | Hot State / Warm Memory / Cold Retrieval | 学习长期对话记忆架构 |
| 多 Provider API 管理 | 支持多平台配置、模型拉取、余额查询 | 学习 LLM Provider 抽象设计 |
| SillyTavern 角色卡 | 支持 V2/V3 PNG/JSON 导入 | 学习角色卡解析与兼容 |
| Prompt 组装管线 | 状态、记忆、模板、上下文裁剪统一组装 | 学习复杂 Prompt 工程 |
| 朋友圈系统 | AI 角色动态、点赞、评论 | 学习类社交产品模块设计 |
| 主动消息 | AI 角色可主动发起聊天 | 学习定时任务与拟人化交互 |
| 正则脚本系统 | 对用户输入和 AI 输出做处理 | 学习可配置文本处理管线 |
| 备份恢复 | ZIP、AES 加密、WebDAV/S3 云同步 | 学习本地数据导入导出 |
| 平台差异化配置 | Android / Windows 使用不同参数 | 学习跨端性能参数设计 |

## 3. 微信风格社交结构

SoulTalk 使用类似微信的底部导航结构：

- SoulTalk / 聊天
- 通讯录
- 发现
- 我

相关代码：

- `lib/pages/main_scaffold.dart`
- `lib/pages/chat_list/`
- `lib/pages/chat/`
- `lib/pages/contacts/`
- `lib/pages/discover/`
- `lib/pages/profile/`
- `lib/theme/wechat_colors.dart`

开发学习点：

1. 使用 `BottomNavigationBar` 构建主导航。
2. 使用 `go_router` 管理页面跳转。
3. 将页面模块拆分到 `pages/` 下，保持结构清晰。
4. 通过主题文件统一微信风格颜色。

## 4. 三层记忆系统

这是项目最值得学习的架构之一。

### 4.1 三层结构

| 层级 | 名称 | 作用 |
|---|---|---|
| Hot State | 状态板 | 保存当前会话的实时状态，例如心情、话题、进度 |
| Warm Memory | 记忆卡片 | 保存经过审核的长期记忆 |
| Cold Retrieval | 关键词检索 | 根据上下文召回相关记忆卡片 |

### 4.2 数据流

```text
用户输入
→ RegexService.applyScripts(userInput)
→ MemoryService.beforeRequest()
   → StateRenderer.render()
   → StateInjector.inject()
   → RetrievalGate.decide()
   → CardRetriever.retrieve()
   → CardInjector.inject()
→ PromptAssemblyService.assemble()
→ ContextManager.trim()
→ LlmService.sendMessageStream()
→ RegexService.applyScripts(aiOutput)
→ MemoryService.afterResponse()
   → StateFiller.fillFromResponse()
   → CardExtractor.extractFromResponse()
   → ReviewPolicy.review()
   → Insert
```

相关代码：

- `lib/services/memory/memory_service.dart`
- `lib/services/memory/state_renderer.dart`
- `lib/services/memory/state_injector.dart`
- `lib/services/memory/retrieval_gate.dart`
- `lib/services/memory/card_retriever.dart`
- `lib/services/memory/card_injector.dart`
- `lib/services/memory/state_filler.dart`
- `lib/services/memory/card_extractor.dart`
- `lib/services/memory/review_policy.dart`
- `lib/models/memory_state.dart`
- `lib/models/memory_card.dart`

开发学习点：

1. 不要把所有历史消息都塞进上下文。
2. 将短期状态和长期记忆分层管理。
3. 通过检索门控控制是否召回长期记忆。
4. 对新记忆做审核，避免低质量内容污染记忆库。
5. 用关键词检索替代向量检索，可以降低移动端复杂度和 API 成本。

## 5. Prompt 组装管线

SoulTalk 有专门的 Prompt 组装服务，而不是在聊天接口里临时拼字符串。

相关模块：

- `lib/services/api/prompt_assembly_service.dart`
- `lib/services/api/context_manager.dart`
- `lib/models/prompt_system.dart`

Prompt 组装可能包含：

- 系统提示词
- 角色设定
- 用户名 / 角色名宏替换
- 状态板
- 长期记忆卡片
- 世界信息
- 历史消息
- 上下文裁剪

开发学习点：

1. Prompt 组装应作为独立服务，避免散落在 UI 或聊天逻辑里。
2. 长上下文前需要裁剪，避免超出模型限制。
3. 角色、人设、记忆、世界信息应有清晰的注入顺序。

## 6. 多模型 API 管理

SoulTalk 抽象了 LLM 服务，支持不同 Provider。

相关代码：

- `lib/services/api/llm_service.dart`
- `lib/services/api/openai_adapter.dart`
- `lib/services/api/anthropic_adapter.dart`
- `lib/services/api/balance_service.dart`
- `lib/providers/api_config_provider.dart`
- `lib/providers/balance_provider.dart`
- `lib/models/api_config.dart`
- `lib/models/balance_info.dart`

已确认支持余额查询的平台包括：

- DeepSeek
- StepFun
- SiliconFlow
- OpenRouter
- Novita AI
- Anthropic

功能亮点：

- 多套 API 配置
- 自动获取模型列表
- 余额查询
- 余额低于 20% 时提醒
- 角色可以绑定不同后端配置

开发学习点：

1. 用 Adapter 隔离不同 Provider 的接口差异。
2. 将 API 配置做成数据模型，便于持久化和切换。
3. 余额查询和聊天调用应分离，避免耦合。
4. Provider 判断可以基于 Base URL、类型字段或配置项。

## 7. 角色卡系统

SoulTalk 支持 SillyTavern V2/V3 PNG/JSON 角色卡导入。

相关代码：

- `lib/services/character/character_card_service.dart`
- `lib/services/character/character_png_service.dart`
- `lib/models/character_card.dart`
- `lib/models/contact.dart`

功能亮点：

- 支持角色卡导入
- 支持 PNG 角色卡解析
- 支持 JSON 角色卡解析
- 支持自定义系统提示词
- 支持预设模板
- 支持 Handlebars 风格宏替换
- 支持角色标签、置顶、未读计数

开发学习点：

1. 兼容外部生态可以显著降低用户迁移成本。
2. 角色卡解析应独立成 Service，不应写在 UI 层。
3. 外部导入数据需要校验和容错。
4. 角色数据模型要兼顾展示信息和 Prompt 信息。

## 8. 朋友圈与发现页

SoulTalk 有类似微信朋友圈的功能。

相关代码：

- `lib/pages/discover/discover_page.dart`
- `lib/pages/discover/moments_page.dart`
- `lib/services/moments/moments_service.dart`
- `lib/providers/moments_provider.dart`
- `lib/models/moment.dart`

功能亮点：

- AI 角色可发动态
- 支持点赞
- 支持评论
- 支持发现页入口

开发学习点：

1. AI 社交应用可以不局限于聊天页。
2. 朋友圈动态可以增强角色的存在感。
3. 动态、评论、点赞适合独立建模，便于后续扩展。

## 9. 主动消息机制

SoulTalk 支持 AI 角色定时主动找用户聊天。

相关代码：

- `lib/services/proactive/proactive_service.dart`

开发学习点：

1. 主动消息可以提升陪伴感。
2. 主动触发需要控制频率，避免打扰用户。
3. 主动消息适合结合角色状态、记忆和最近互动生成。

## 10. 正则脚本系统

SoulTalk 有独立的正则脚本能力，用于处理输入和输出文本。

相关代码：

- `lib/services/regex/regex_service.dart`
- `lib/models/regex_script.dart`
- `lib/providers/regex_script_provider.dart`
- `lib/services/database/regex_script_dao.dart`

处理阶段包括：

- 用户输入阶段
- AI 输出阶段

开发学习点：

1. 文本预处理和后处理适合做成可配置脚本。
2. 正则脚本可以用于清理模型输出、替换宏、过滤格式。
3. 脚本系统应注意执行顺序和启用状态。

## 11. 外卖、购物车与钱包交易

SoulTalk 包含一些生活化模拟模块。

相关代码：

- `lib/pages/delivery/delivery_page.dart`
- `lib/providers/cart_provider.dart`
- `lib/providers/wallet_provider.dart`
- `lib/models/cart_item.dart`
- `lib/models/wallet_transaction.dart`
- `lib/services/database/cart_dao.dart`
- `lib/services/database/wallet_transaction_dao.dart`

功能亮点：

- 外卖点餐
- 购物车
- 钱包交易记录

开发学习点：

1. AI 陪伴类产品可以通过生活化场景增强沉浸感。
2. 购物车、钱包等模块适合用独立 Provider 和 DAO 管理。
3. 这些模块可以作为角色互动剧情或模拟生活的一部分。

## 12. 备份恢复与云同步

SoulTalk 支持较完整的数据备份能力。

相关代码：

- `lib/services/backup/backup_service.dart`
- `lib/services/backup/backup_encryption.dart`
- `lib/services/backup/cloud_storage.dart`
- `lib/providers/backup_provider.dart`
- `lib/pages/settings/backup_page.dart`

功能亮点：

- ZIP 导出
- ZIP 导入
- AES 加密
- WebDAV 云同步
- S3 云同步
- 自动定时备份

开发学习点：

1. AI 社交应用的数据很重要，备份是核心能力。
2. 本地备份应考虑加密。
3. 云同步应抽象存储后端，避免绑定单一服务。
4. 导入恢复需要注意数据库版本和兼容性。

## 13. SQLite 本地数据库与 DAO 分层

SoulTalk 使用 SQLite 做本地持久化，并使用多个 DAO 管理不同数据。

相关代码：

- `lib/services/database/database_service.dart`
- `lib/services/database/message_dao.dart`
- `lib/services/database/contact_dao.dart`
- `lib/services/database/memory_card_dao.dart`
- `lib/services/database/memory_state_dao.dart`
- `lib/services/database/moment_dao.dart`

已确认数据库版本包含：

| 版本 | 新增内容 |
|---|---|
| v1 | api_configs, contacts, messages |
| v2 | moments, proactive 字段 |
| v3 | chat_presets, cart_items |
| v4 | regex_scripts, memory_entries |
| v5 | wallet_transactions |
| v6 | memory_states, memory_cards, WAL 模式 |

开发学习点：

1. 本地优先应用适合使用 SQLite。
2. DAO 分层可以降低数据库操作和业务逻辑耦合。
3. 数据库迁移需要版本化管理。
4. WAL 模式适合提升并发读写稳定性。

## 14. 平台差异化配置

SoulTalk 针对不同平台设置不同参数。

相关代码：

- `lib/platform/platform_config.dart`
- `lib/platform/platform_config_mobile.dart`
- `lib/platform/platform_config_desktop.dart`
- `lib/platform/platform_config_stub.dart`

示例参数：

| 参数 | Android | Windows |
|---|---:|---:|
| 状态板上限 | 600 chars | 1200 chars |
| 检索 Top-K | 3 张卡片 | 5 张卡片 |
| 检索间隔 | 每 8 轮 | 每 6 轮 |
| API 超时 | 15s | 10s |
| DB 批处理 | 100 条 | 500 条 |

开发学习点：

1. 移动端和桌面端性能约束不同。
2. 上下文窗口、检索数量、批处理大小可以按平台调优。
3. 平台差异应集中管理，不应散落在业务代码中。

## 15. 应用内更新

SoulTalk 支持通过 GitHub Release 检查更新。

相关代码：

- `lib/services/update/update_service.dart`
- `lib/providers/update_provider.dart`
- `lib/pages/settings/update_page.dart`

更新流程：

1. 用户打开检查更新。
2. App 调用 GitHub Releases API。
3. 比较当前版本与最新 Release。
4. 展示新版本号、安装包大小、完整更新日志。
5. 用户选择是否下载。
6. 下载完成后安装 APK。

开发学习点：

1. 版本检查逻辑应独立成 Service。
2. 更新 UI 应展示清楚版本差异和更新日志。
3. 下载和安装属于高风险操作，需要用户明确确认。

## 16. 语音相关能力

项目包含语音相关依赖和模块。

相关代码：

- `lib/services/tts/tts_service.dart`
- `lib/models/voice_config.dart`

相关依赖：

- `just_audio`
- `record`
- `permission_handler`

开发学习点：

1. AI 角色语音化可以增强沉浸体验。
2. 音频播放、录音、权限处理应拆分清楚。
3. 语音配置适合独立建模，方便角色绑定不同声音。

## 17. PC 连接能力

项目包含 PC 连接相关模块。

相关代码：

- `lib/pc_connect/connection_manager.dart`
- `lib/pc_connect/sync_handler.dart`
- `lib/pc_connect/api_config_sender.dart`
- `lib/pc_connect/models/pc_device.dart`

开发学习点：

1. 移动端和 PC 端协同可以提升配置和同步体验。
2. 连接、同步、数据发送应拆成独立模块。
3. 设备模型可以保存连接状态、设备信息和认证信息。

## 18. 工程技术栈

主要技术：

- Flutter
- Dart
- Riverpod
- GoRouter
- Freezed
- JSON Serializable
- SQLite / sqflite
- Dio
- WebSocket / Shelf
- Archive
- Encrypt
- File Picker
- Image Picker
- Just Audio

学习价值：

1. Flutter 中大型应用的目录结构。
2. Riverpod 状态管理实践。
3. Freezed 数据模型生成。
4. SQLite 本地持久化。
5. LLM API Adapter 设计。
6. 本地数据备份与恢复。
7. AI 角色长期记忆系统。

## 19. 最值得重点学习的模块

如果以开发学习为目标，建议优先看这些模块：

### 第一优先级：AI 核心链路

- `lib/services/chat/chat_service.dart`
- `lib/services/api/prompt_assembly_service.dart`
- `lib/services/api/context_manager.dart`
- `lib/services/api/llm_service.dart`
- `lib/services/api/openai_adapter.dart`
- `lib/services/api/anthropic_adapter.dart`

学习目标：理解一次聊天请求从用户输入到模型回复的完整流程。

### 第二优先级：记忆系统

- `lib/services/memory/`
- `lib/models/memory_state.dart`
- `lib/models/memory_card.dart`
- `lib/services/database/memory_state_dao.dart`
- `lib/services/database/memory_card_dao.dart`

学习目标：理解长期记忆如何注入、召回、更新和审核。

### 第三优先级：角色系统

- `lib/services/character/character_card_service.dart`
- `lib/services/character/character_png_service.dart`
- `lib/models/character_card.dart`
- `lib/models/contact.dart`

学习目标：理解角色卡生态如何接入应用。

### 第四优先级：数据层

- `lib/services/database/database_service.dart`
- `lib/services/database/*_dao.dart`

学习目标：理解 SQLite 表结构、迁移和 DAO 分层。

### 第五优先级：产品化能力

- `lib/services/backup/`
- `lib/services/update/`
- `lib/services/api/balance_service.dart`
- `lib/platform/`

学习目标：理解一个 AI App 如何从 Demo 走向可用产品。

## 20. 可借鉴的设计思想

1. **AI 应用不只是调用模型**  
   还需要角色、记忆、上下文、配置、备份、更新等完整系统。

2. **长期记忆需要分层**  
   短期状态、长期记忆、按需检索应分开处理。

3. **Prompt 需要工程化**  
   Prompt 组装不应散落在业务代码中，而应形成可维护的管线。

4. **Provider 差异需要 Adapter**  
   不同模型服务商接口不同，用 Adapter 可以减少业务层复杂度。

5. **本地优先适合 AI 角色应用**  
   聊天记录、记忆、角色卡都适合保存在本地，并支持加密备份。

6. **社交壳可以增强 AI 陪伴感**  
   聊天、朋友圈、主动消息、外卖、钱包等模块能让 AI 角色更像生活中的对象。

## 21. 后续学习建议

建议按以下顺序阅读代码：

```text
main.dart
→ router.dart
→ pages/main_scaffold.dart
→ pages/chat/
→ services/chat/chat_service.dart
→ services/api/prompt_assembly_service.dart
→ services/memory/memory_service.dart
→ services/database/database_service.dart
```

然后再扩展阅读：

```text
services/character/
services/regex/
services/backup/
services/update/
services/proactive/
services/moments/
```

## 22. 注意事项

本文档主要根据当前项目 README、代码目录和模块命名整理，用于开发学习和架构理解。

部分模块是否完全可用，需要结合实际运行、测试结果和具体实现进一步确认。