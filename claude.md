# SoulTalk 项目状态与续接说明

真实项目根目录：C:/Users/Admin/Desktop/AI_talk。C:/Users/Admin/Desktop/soultalk 主要是文档目录。技术栈固定为 Flutter/Dart + Riverpod + SQLite/sqflite。

## 1. 项目目标

SoulTalk 是 AI 微信风格社交应用，已有聊天、通讯录、发现/朋友圈、个人中心、角色卡、长期记忆、主动消息、文件发送、API 配置、余额管理、ZIP/AES/WebDAV/S3 备份。

当前重构目标：保留 SoulTalk 现有体验；完成 SillyTavern L1 兼容；建立文件为权威源、SQLite 为索引和私有数据的本地优先架构；为 LanSync、统一 Scheduler、AI 自动朋友圈、主动对话、ExtensionBridge 打基础。

## 2. 已完成的功能清单

### 规划文档

已创建 SOULTALK_REFACTOR_PLAN.md 和 SOULTALK_IMPLEMENTATION_SEQUENCE.md，包含架构蓝图、模块拆分、SQLite 表规划、LanSync 协议、阶段顺序、验收标准。

### 文件权威源基础设施

已完成 st_compat/ 与 soultalk/ 目录初始化、原子写入、路径清洗、文件 manifest 扫描、file_index 写入、ST 兼容索引写入。

关键文件：
- lib/core/app_paths.dart
- lib/core/file_store/path_sanitizer.dart
- lib/core/file_store/atomic_file_writer.dart
- lib/core/file_store/compat_file_store.dart
- lib/core/file_store/file_manifest_service.dart
- lib/services/st_compat/compat_storage_bootstrap_service.dart

### SQLite 迁移与 DAO

当前数据库版本：9。

迁移文件：
- lib/services/database/migrations/migration_v7.dart：file_index、st_character_index、st_chat_index、st_world_index、st_preset_index
- lib/services/database/migrations/migration_v8.dart：attachment_index
- lib/services/database/migrations/migration_v9.dart：scheduler_jobs、scheduler_run_log

新增 DAO：
- lib/services/database/file_index_dao.dart
- lib/services/database/st_character_index_dao.dart
- lib/services/database/st_chat_index_dao.dart
- lib/services/database/st_world_index_dao.dart
- lib/services/database/st_preset_index_dao.dart
- lib/services/database/attachment_index_dao.dart
- lib/services/database/scheduler_job_dao.dart

### SillyTavern L1 只读解析

已完成角色卡 JSON/PNG chara chunk、聊天 JSONL、世界书 JSON、OpenAI/Context/Instruct/通用 preset、ST regex parser 和 mapper。

相关目录：
- lib/services/st_compat/character/
- lib/services/st_compat/chat/
- lib/services/st_compat/world_info/
- lib/services/st_compat/presets/
- lib/services/st_compat/regex/

### L1 辅助层

已完成 MacroService、STWorldInfoMatcher、STPromptCompatAssembler。支持基础宏、if 条件块、世界书关键词/正则匹配、Context preset 与角色卡字段组装。

关键文件：
- lib/services/st_compat/macros/macro_service.dart
- lib/services/st_compat/world_info/st_world_info_matcher.dart
- lib/services/st_compat/prompt/st_prompt_compat_assembler.dart

### st_compat 文件仓库层

已完成 STCharacterRepository、STChatRepository、STWorldInfoRepository、STPresetRepository。

### PromptAssemblyService 最小接入

文件：lib/services/api/prompt_assembly_service.dart。

已接入 ST 角色卡 data.description、data.personality、data.scenario、data.system_prompt、data.post_history_instructions、data.extensions.regex_scripts。非流式请求已使用 requestMessages。postHistoryPrompt 不再作为 fake user 消息追加到最后，而是并入 system prompt。换行分隔符使用 String.fromCharCodes([10, 10])，避免脚本写坏字符串。

### 附件基础设施

已完成 AttachmentService 和 attachment_index。附件导入到 soultalk/attachments/{chatId}/，记录 sha256、size、originalName、mime、relativePath，并可生成聊天 extra metadata。尚未接入旧文件发送 UI/流程。

关键文件：
- lib/services/file_send/attachment_service.dart
- lib/services/database/attachment_index_dao.dart

### 备份适配

文件：lib/services/backup/backup_service.dart。已扩展 BackupSection：compatFiles、attachments。备份可包含 st_compat/ 与 soultalk/attachments/，恢复可还原对应目录。路径归一化使用 p.relative(...).split(p.separator).join("/")。

### ProactiveService 修复

文件：lib/services/proactive/proactive_service.dart。计划消息 key 改为 JSON 字符串；App 重启后恢复未来计划消息 Timer；过期 key 清理；已发送 key 持久化；立即发送时使用当前时间作为 createdAt。

### 旧 SQLite 数据导出到 st_compat

文件：lib/services/st_compat/legacy/legacy_compat_export_service.dart。

支持 contacts 导出为 st_compat/characters/{name}.json；messages 导出为 st_compat/chats/{characterName}/{characterName} - imported.jsonl；导出后自动调用 CompatStorageBootstrapService.initializeAndRebuildIndex；不修改旧表；不覆盖已有文件，使用 .imported-N 后缀。

## 3. 当前关键代码结构

核心文件：
- lib/main.dart：App 入口，初始化 sqflite FFI，后台执行兼容索引重建。
- lib/services/database/database_service.dart：SQLite 初始化与迁移，当前版本 9。
- lib/services/chat/chat_service.dart：聊天主链路，流式/非流式统一 request messages。
- lib/services/api/prompt_assembly_service.dart：Prompt 主组装，已接入 ST 角色卡字段和 regex。
- lib/services/backup/backup_service.dart：ZIP/AES 导入导出，已纳入 st_compat 与附件。
- lib/services/proactive/proactive_service.dart：旧主动消息服务，已修复调度状态恢复。

兼容层目录：lib/services/st_compat/ 下的 character、chat、world_info、presets、regex、macros、prompt、legacy。

重要测试：
- test/services/st_compat/legacy_compat_export_service_test.dart
- test/services/st_compat/compat_storage_bootstrap_service_test.dart
- test/services/api/prompt_assembly_service_test.dart
- test/services/st_compat/st_repositories_test.dart
- test/services/st_compat/character/st_character_card_parser_test.dart
- test/services/st_compat/chat/st_chat_jsonl_codec_test.dart
- test/services/st_compat/world_info/st_world_info_matcher_test.dart
- test/services/st_compat/regex/st_regex_mapper_test.dart

## 4. 正在进行中的任务与问题

当前推进方向：
1. 现有文件发送 UI/流程接入 AttachmentService。
2. 备份恢复后自动重建 file_index 与 ST 索引。
3. 统一 Scheduler 服务层。
4. 后续迁移 Proactive/FriendCircle/LanSync。

已知未完成：附件服务层已完成但旧文件发送 UI 尚未接入；备份 manifest 尚未包含 hash/size/mtime 校验；恢复流程尚未在完成后自动重建索引；Scheduler 只有 DB/DAO 基础；LanSync 尚未实现；ExtensionBridge L2/L3 尚未实现。

最近修复：chat_service.dart 字符串跨行语法错误；backup_service.dart enum switch 和反斜杠语法错误；ProactiveService JSON key 和 Timer 恢复。

## 5. 下一步计划

P0：补齐文件权威源闭环。搜索 file_picker、metadata、MessageType.file、open_filex、send file、attachment，找到现有文件发送入口，接入 AttachmentService.importFile，并将附件 metadata 写入 message metadata 或 ST JSONL extra.soultalk_attachments，保持旧 UI 不变。

P1：备份恢复补强。备份 manifest 增加 st_compat 和 attachments 文件 hash、size、mtime；恢复时校验 hash；恢复完成后调用 CompatStorageBootstrapService.initializeAndRebuildIndex；恢复前创建本地恢复点。

P2：统一 Scheduler 服务层。实现 UnifiedScheduler、SchedulerTaskHandler、SchedulerPolicy、SchedulerRunLogDao，并先把 AutoBackup 接入 scheduler_jobs。

P3：Proactive/FriendCircle 迁移到 Scheduler。新增 proactive_rules、proactive_events、friend_circle_rules、新版发布日志，保留旧服务并逐步切换。

P4：LanSync v1。顺序：手动 IP + WebSocket -> device id/key -> 配对授权 -> manifest exchange -> 单向 pull -> 双向 push -> 冲突处理 -> mDNS/UDP。

P5：ExtensionBridge L2/L3。顺序：manifest parser -> event bus -> context provider -> flutter_js adapter -> SillyTavern.getContext -> WebView 沙箱。

## 6. 重要注意事项

1. 不要切换技术栈，必须保持 Flutter/Dart + Riverpod + SQLite/sqflite。
2. 不要删除旧表，旧 contacts/messages/moments 仍是兼容期数据来源。
3. ST 生态数据以 st_compat/ 文件为权威源，SQLite 只做索引。
4. LanSync 后续不得同步 API key、secrets、WebDAV/S3 凭据。
5. S3/WebDAV/AES/ZIP 备份必须保留。
6. 冷启动不能阻塞，索引重建使用后台 unawaited。
7. 每次改动后至少跑 flutter analyze，涉及测试逻辑时跑相关 flutter test。
8. 当前有 CLAUDE.md 和 claude.md 两个文件，内容应保持同步。

## 7. 如何运行和测试

进入项目根目录：cd C:/Users/Admin/Desktop/AI_talk

获取依赖：flutter pub get

静态检查：flutter analyze

运行全部测试：flutter test

当前最新完整结果：flutter analyze 无问题；flutter test 全部通过，+116。

运行部分新增测试：
- flutter test test/services/st_compat/legacy_compat_export_service_test.dart
- flutter test test/services/st_compat/compat_storage_bootstrap_service_test.dart
- flutter test test/services/api/prompt_assembly_service_test.dart

Windows debug：flutter run -d windows，或 flutter build windows --debug。

## 8. 建议下一次对话从这里开始

继续补齐文件权威源闭环：读取现有文件发送实现，将旧文件发送流程最小接入 AttachmentService，并保证 flutter analyze / flutter test 通过。
