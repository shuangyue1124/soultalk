# SoulTalk Code Review Report

> Generated: 2026-05-05
> Scope: Full codebase audit (models, services, providers, pages/widgets, pc module, tests)
> `dart analyze`: 0 issues | `flutter test`: 88/88 passed

---

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 12 |
| HIGH | 22 |
| MEDIUM | 40 |
| LOW | 32 |
| **Total** | **106** |

---

## 1. CRITICAL Issues (12)

### C-01 Timer Memory Leak in BalanceProvider
- **File:** `lib/providers/balance_provider.dart:18, 34-43`
- **Description:** `BalanceNotifier` holds a `Timer.periodic` but has no `ref.onDispose()` callback. When the provider is disposed, the timer keeps firing indefinitely, leaking memory and causing unbounded API calls.
- **Fix:** Add `ref.onDispose(() => _timer?.cancel());` inside `build()`.

### C-02 Weak JWT Secret Generation -- Predictable Randomness
- **File:** `lib/pc_connect/websocket_server.dart:111-117`
- **Description:** `_generateSecret()` uses `DateTime.now().microsecondsSinceEpoch % 256` in a tight loop. All 32 bytes are nearly identical, making JWT tokens trivially predictable on the LAN.
- **Fix:** Use `Random.secure()` from `dart:math`.

### C-03 Port Collision in Server Startup
- **File:** `lib/pc_connect/websocket_server.dart:48-51`
- **Description:** Port derived from `millisecondsSinceEpoch` is deterministic for calls within the same millisecond. No retry logic or port-availability check.
- **Fix:** Use `Random.secure().nextInt()` for port selection, add bind-retry loop.

### C-04 Device ID Collision
- **File:** `lib/pc_connect/websocket_server.dart:385-387`
- **Description:** `_generateDeviceId()` uses timestamp + device count. Two simultaneous connections can get the same ID because `addDevice` happens after listener setup.
- **Fix:** Use UUID for device IDs.

### C-05 Unsafe Non-nullable Casts in `fromDbMap`
- **Files:** `lib/models/regex_script.dart:150-153`, `lib/models/cart_item.dart:35-36`, `lib/models/chat_preset.dart:62-64`
- **Description:** Bare `as String` / `as int` casts crash on null DB values (corrupt row, partial migration). The same files use `as String? ?? ''` in `fromJson`, creating inconsistent safety.
- **Fix:** Use `as String? ?? ''` pattern everywhere.

### C-06 Un-awaited Future in try-catch
- **File:** `lib/services/chat/chat_service.dart:242`
- **Description:** `_memoryService.afterResponse(...)` returns a `Future` but is never `await`ed. The `catch (_) {}` block is unreachable. Exceptions become unhandled Future errors.
- **Fix:** Add `await` before the call.

### C-07 Cast Crash When JSON Root is a List
- **File:** `lib/services/import/import_service.dart:60`
- **Description:** If `decoded` is a `List`, it passes the guard check then hits `decoded as Map<String, dynamic>` which throws a `TypeError`.
- **Fix:** Add explicit `if (decoded is List)` handling before the cast.

### C-08 Database Double Initialization Race
- **File:** `lib/services/database/database_service.dart:11-14`
- **Description:** `_db ??= await _initDatabase()` is not atomic across `await` boundaries. Two concurrent callers can initialize the database twice.
- **Fix:** Use a `Completer`-based latch pattern.

### C-09 TOCTOU Race in Moment DAO
- **File:** `lib/services/database/moment_dao.dart:88-141`
- **Description:** `addLike`, `removeLike`, `addComment` read-modify-write without a transaction. Concurrent callers can silently lose updates.
- **Fix:** Wrap in `db.transaction()`.

### C-10 Zero Test Coverage for PC Module
- **File:** `pc/test/widget_test.dart` (only 1 test)
- **Description:** `WebSocketClient`, `SyncManager`, `ConflictResolver`, `ApiConfigManager`, all UI pages -- zero tests. Critical connection lifecycle logic is untested.

### C-11 Zero Test Coverage for `lib/pc_connect/`
- **Description:** `WebSocketServer`, `ConnectionManager`, `SyncHandler`, `ApiConfigSender`, `PcDevice` model -- all completely untested.

### C-12 Non-atomic Cascade Delete
- **File:** `lib/services/chat/chat_service.dart:60-63`
- **Description:** `deleteContact` deletes messages first, then the contact. If contact deletion fails, messages are permanently lost but contact remains.
- **Fix:** Wrap both operations in a single database transaction.

---

## 2. HIGH Issues (22)

### H-01 Silent Error Swallowing (`catch (_) {}`)
- **Files:** `lib/models/voice_config.dart:233,306`, `lib/models/prompt_system.dart:370`, `lib/models/memory_entry.dart:132`
- **Description:** Deserialization errors are silently discarded. Corrupted data returns default objects with no indication of failure.
- **Fix:** At minimum log errors; consider returning a result type or throwing.

### H-02 `copyWith` Cannot Clear Nullable Fields to Null
- **Scope:** All 11 hand-written models
- **Description:** Pattern `field: field ?? this.field` prevents ever setting a nullable field to null via `copyWith(contactId: null)` -- the old value is silently kept.
- **Fix:** Use sentinel values, `Optional<T>` wrapper, or code generation (freezed).

### H-03 API Keys Stored in Plain Text
- **Files:** `lib/models/api_config.dart:15`, `lib/models/voice_config.dart:112,255`
- **Description:** All API keys serialized to plain-text JSON and stored in SharedPreferences (XML/plist). Readable with root access or from backups.
- **Fix:** Use platform secure storage (Keychain / KeyStore).

### H-04 Race Condition / Lost-Update in SettingsNotifier
- **File:** `lib/providers/settings_provider.dart:106-223`
- **Description:** Every setter `await`s SharedPreferences first, then reads `state.value`. Two concurrent setters can lose one update from in-memory state (SharedPreferences will be correct but Riverpod state will be stale).
- **Fix:** Read `state.value` before `await`, or use optimistic update pattern.

### H-05 No Error Handling in SettingsNotifier Setters
- **File:** `lib/providers/settings_provider.dart:106-223`
- **Description:** None of the 12 setter methods catch exceptions. If SharedPreferences throws, Riverpod state and disk state become inconsistent.

### H-06 Missing Error Handling in Provider Mutations
- **Files:** `lib/providers/api_config_provider.dart`, `lib/providers/contacts_provider.dart`, `lib/providers/messages_provider.dart`, `lib/providers/wallet_provider.dart`
- **Description:** All mutation methods (add, update, remove) propagate unhandled exceptions to UI. No rollback on partial failure.

### H-07 Race Condition in `WebSocketClient.dispose()`
- **File:** `pc/lib/websocket_client.dart:215-219`
- **Description:** `disconnect()` is async but called without `await` in `dispose()`. Controllers are closed immediately, causing `StateError` if disconnect emits events afterward.

### H-08 Broken Reconnect Guard on Manual Disconnect
- **File:** `pc/lib/websocket_client.dart:62-77 vs 169-178`
- **Description:** `_serverUrl` is never cleared on manual disconnect. Stale URL can trigger unwanted reconnect.

### H-09 Stream Subscription Never Cancelled
- **File:** `pc/lib/websocket_client.dart:10-11, 48`
- **Description:** `_subscription` is assigned but never cancelled in `disconnect()` or `dispose()`. Listener callbacks can fire on a stale channel.

### H-10 SyncManager Leak on Reconnect
- **File:** `pc/lib/providers/connection_provider.dart:83-91`
- **Description:** `connect()` replaces `_syncManager` without disposing the old one, leaking StreamControllers. Same for `_messagesSubscription`.

### H-11 Pervasive Silent Exception Swallowing
- **Scope:** 30+ locations across services
- **Description:** `catch (_) {}` with no logging, no user feedback. Makes production debugging impossible. Affects SSE parsing, memory pipeline, backup, proactive messages, cloud storage, update service.
- **Fix:** At minimum `debugPrint('Error: $e')` or use a proper logging framework.

### H-12 DioException Not Handled in LLM Adapters
- **Files:** `lib/services/api/openai_adapter.dart:34-49`, `lib/services/api/anthropic_adapter.dart:49-61`
- **Description:** Network timeouts, 401, 429, 500 errors propagate as unhandled exceptions. No user-friendly error messages for common API failures.

### H-13 N+1 Queries in Memory DAOs
- **Files:** `lib/services/database/memory_entry_dao.dart:41-64`, `lib/services/database/memory_state_dao.dart:46-49`
- **Description:** `upsertAll` does SELECT + INSERT/UPDATE per entry = 2N database round-trips. Should batch in a single transaction.

### H-14 Streaming Per-Chunk Database Writes
- **File:** `lib/services/chat/chat_service.dart:211-217`
- **Description:** Every streaming chunk triggers `_messageDao.updateContent()`. Hundreds of UPDATE statements per response. Should debounce.

### H-15 `PlatformConfig` Import of `dart:io` Blocks Web
- **File:** `lib/platform/platform_config.dart:1`
- **Description:** Unconditional `import 'dart:io'` prevents compilation on web. The `StubPlatformConfig` exists but can never be used as default.
- **Fix:** Use conditional import pattern.

### H-16 Blocking Synchronous I/O in `build()`
- **Files:** `lib/widgets/avatar_widget.dart:35`, `lib/pages/chat/widgets/message_bubble.dart:275`
- **Description:** `file.existsSync()` blocks the UI thread inside `build()`. On slow storage, causes visible frame drops.

### H-17 TextEditingController Leaks in Dialogs
- **Scope:** 7 locations across `input_bar.dart`, `moments_page.dart`, `delivery_page.dart`, `general_settings_page.dart`
- **Description:** Controllers created inside dialog-opening methods are never disposed. Each dialog open leaks controllers and FocusNodes.

### H-18 SharedPreferences Read on Every Route Redirect
- **File:** `lib/router.dart:27-33`
- **Description:** `redirect` calls `await isOnboardingDone()` which reads SharedPreferences on every navigation event. Adds latency to every route change.
- **Fix:** Cache the onboarding state in memory after first read.

### H-19 Regex Processing in `build()` Per Message Bubble
- **File:** `lib/pages/chat/widgets/message_bubble.dart:42-44`
- **Description:** `_applyRegex()` runs all enabled scripts synchronously for every visible bubble. Causes frame drops during scrolling.
- **Fix:** Memoize per message ID.

### H-20 O(n) Contact Lookup Per Moment Card
- **File:** `lib/pages/discover/moments_page.dart:127-129`
- **Description:** `contacts.where(...).firstOrNull` inside `SliverChildBuilderDelegate` = O(N*M). Should build a `Map<String, Contact>` once.

### H-21 APK Install Flow on Non-Android Platforms
- **File:** `lib/pages/settings/update_page.dart:387-390`
- **Description:** `OpenFilex.open(apkPath)` on iOS/desktop fails silently. No platform check for different behavior.

### H-22 Balance Service Silently Swallows All Errors
- **File:** `lib/services/api/balance_service.dart:75-77, 111-113, 145-147, 178-180, 208-210`
- **Description:** Every `_query*` method catches `DioException` and returns empty `BalanceInfo`. User gets no feedback about why balance checking failed.

---

## 3. MEDIUM Issues (40)

### Models (6)

| ID | File | Issue |
|----|------|-------|
| M-01 | `memory_card.dart:71 vs 106` | Tags: comma-join in DB vs JSON array. Commas in tags corrupt data on round-trip |
| M-02 | `prompt_system.dart:68-69` | Enum `.index` for persistence. Fragile to enum reordering; use `.name` instead |
| M-03 | `message.dart:24` | `isStreaming` is transient UI state in immutable data model. Causes unnecessary object churn |
| M-04 | 5 files | `DateTime.now()` as fallback for missing timestamps masks data corruption |
| M-05 | Multiple files | No range validation on bounded numeric fields (`confidence`, `temperature`, `speed`, etc.) |
| M-06 | Multiple files | Free-form String where enum/constants would prevent typos (`type`, `slotType`, `status`, `scope`) |

### Services (10)

| ID | File | Issue |
|----|------|-------|
| M-07 | `backup_service.dart:80-102` | N+1 query: one message query per contact for backup. Fetch all at once |
| M-08 | `auto_backup_service.dart:48-56` | Change detection uses only row count. Content edits are invisible |
| M-09 | `memory_card_dao.dart:21-41` | Dynamic LIKE queries with OR clauses. No FTS index |
| M-10 | `proactive_service.dart:56,95` | Full table scans every 5 minutes with no caching |
| M-11 | `prompt_assembly_service.dart:17` | `SharedPreferences.getInstance()` called on every `assemble()` invocation |
| M-12 | `regex_service.dart:72-101` | No protection against ReDoS. User-supplied regex compiled with no complexity limit |
| M-13 | `cloud_storage.dart:104-105` | WebDAV Basic auth sends credentials over HTTP if user misconfigures URL |
| M-14 | `backup_encryption.dart:63-74` | Hand-rolled PBKDF2-like KDF. Salt encoding bug for bytes > 127 |
| M-15 | `moment_dao.dart:95,114,131` | Silent no-op when moment not found. Hides data integrity issues |
| M-16 | `contact_dao.dart:43`, `message_dao.dart:39` | Unsafe non-null cast on `pinned`/`is_streaming`. No null guard |

### Providers (6)

| ID | File | Issue |
|----|------|-------|
| M-17 | `update_provider.dart:82-101` | No guard against concurrent downloads. Rapid tapping launches multiple |
| M-18 | `balance_provider.dart:34-43` | Stale config captured in timer callback closure |
| M-19 | `messages_provider.dart:14-25, 29-44` | `loadMore()` fetches ALL messages from DB every time. O(N) on every scroll-to-top |
| M-20 | `messages_provider.dart:29-44` | No concurrency guard on `loadMore()`. Rapid scrolls corrupt offset |
| M-21 | `pc_connect_provider.dart:87-105` | No `ref.onDispose` for subscription cleanup |
| M-22 | `wallet_provider.dart:70-74` | Cross-provider mutation + fire-and-forget async. Balance update can silently fail |

### Pages & Widgets (8)

| ID | File | Issue |
|----|------|-------|
| M-23 | `chat_page.dart:297-309` | Deep link shows "contact not found" on transient errors instead of loading state |
| M-24 | `chat_list_page.dart:42` | `RefreshIndicator` doesn't wait for data. Spinner dismisses immediately |
| M-25 | `input_bar.dart:346` | Keyboard inset triggers per-frame rebuild of entire InputBar |
| M-26 | `input_bar.dart:395-399` | Emoji button is a non-functional stub that looks interactive |
| M-27 | Multiple pages | `DropdownButtonFormField` uses `initialValue` instead of `value`. Won't respond to state changes |
| M-28 | `profile_page.dart:131-143` | `PackageInfo.fromPlatform()` creates new Future on every `build()` |
| M-29 | `contacts_page.dart:129-172` | Contact grouping computed from scratch on every `build()` |
| M-30 | Multiple files | Deprecated `Color.withAlpha()` mixed with new `Color.withValues()` |

### PC Module (6)

| ID | File | Issue |
|----|------|-------|
| M-31 | `websocket_server.dart:337-349` | `_handleNewMessage` mutates the original map before broadcast. Should clone |
| M-32 | `connection_manager.dart:48-63` | Recreates `_DeviceConnection` on every send just to update timestamp |
| M-33 | `scan_page.dart:98-99` | URL validator rejects `wss://` URLs |
| M-34 | `connection_provider.dart:83-91` | Reconnect creates new SyncManager without disposing old one |
| M-35 | `platform_config_stub.dart` vs `mobile` | Stub has different tuning params (800 vs 600 chars, 200 vs 100 batch) |
| M-36 | `platform_config_desktop.dart:7` | Desktop `dataDirBase` same as mobile (`'app_flutter'`) |

### Accessibility (4)

| ID | File | Issue |
|----|------|-------|
| M-37 | Entire codebase | Zero `Semantics` widgets. No screen reader support anywhere |
| M-38 | `delivery_page.dart:758-773` | Touch target 24x24 (minimum 48x48). Fails accessibility guidelines |
| M-39 | Entire codebase | All strings hardcoded in Chinese. No i18n/l10n support |
| M-40 | Multiple files | Potential WCAG contrast issues with `WeChatColors.textHint` |

---

## 4. LOW Issues (32)

### Models (8)

| ID | File | Issue |
|----|------|-------|
| L-01 | `memory_state.dart:48-57 vs 74-83` | `toJson` and `toDbMap` are identical. One is dead code |
| L-02 | All hand-written models | No `==`/`hashCode` overrides. Causes unnecessary Riverpod rebuilds |
| L-03 | `character_card.dart:30-69` | `fromV2Json`/`fromV3Json` ~90% code duplication |
| L-04 | `cart_item.dart:16-22` | `copyWith` only supports `quantity` |
| L-05 | `regex_script.dart:28` | No regex syntax validation on `findRegex` |
| L-06 | Multiple files | Inconsistent JSON key casing (snake_case vs camelCase) |
| L-07 | `voice_config.dart:254` | `SttConfig.provider` is String, not enum like `TtsConfig.provider` |
| L-08 | `memory_entry.dart:119,149` | LLM-parsed entries get empty `id`, risking DB primary key collisions |

### Services (7)

| ID | File | Issue |
|----|------|-------|
| L-09 | `database_service.dart:330-417` | Redundant migration blocks for v6 and v7 |
| L-10 | `update_service.dart:37-38` | Hardcoded GitHub repo owner/name. Breaks on fork or rename |
| L-11 | `proactive_service.dart:316` | Debug `print` statement left in production code |
| L-12 | `openai_adapter.dart:50-58`, `anthropic_adapter.dart:54-60` | No handling of API error response shapes |
| L-13 | `openai_adapter.dart:67-71`, `anthropic_adapter.dart:70-74` | New Dio instance per stream call, never closed |
| L-14 | `openai_adapter.dart:96-126`, `anthropic_adapter.dart:100-129` | Duplicated SSE stream parsing logic |
| L-15 | `proactive_service.dart:293-299, 503-508` | Bypasses DAO layer with direct SQL |

### Providers (4)

| ID | File | Issue |
|----|------|-------|
| L-16 | `preset_provider.dart:7`, `cart_provider.dart:7`, `wallet_provider.dart:9` | `late final` DAO throws `LateInitializationError` if `build()` fails |
| L-17 | All provider files | Zero `select()` usage. Every `ref.watch()` triggers full state rebuild |
| L-18 | `regex_script_provider.dart:49-52` | Coarse-grained watch. Rebuilds even when only script name changes |
| L-19 | `settings_provider.dart:142-147` | `deductBalance` silently fails on insufficient funds |

### Architecture (6)

| ID | File | Issue |
|----|------|-------|
| L-20 | `chat_service.dart` | God class (300 lines, 9 DAOs, 2 adapters, 4 services) |
| L-21 | `proactive_service.dart` | God class (522 lines, 4+ responsibilities) |
| L-22 | Multiple services | No dependency injection. Constructors create dependencies directly |
| L-23 | `moments_service.dart`, `proactive_service.dart` | Manual `init()` pattern. Fragile, easy to forget |
| L-24 | `proactive_service.dart`, `moments_service.dart` | Circular coupling between services |
| L-25 | `backup_provider.dart`, `update_provider.dart`, `pc_connect_provider.dart` | Services instantiated inline. Impossible to mock in tests |

### PC Module (3)

| ID | File | Issue |
|----|------|-------|
| L-26 | `websocket_server.dart:146-164` | `_getClientIp` always returns null for direct connections. LAN IP check is no-op |
| L-27 | `api_config_sender.dart:46-50` | `_getEnabledConfigs()` is a stub. "Follow phone" mode is non-functional |
| L-28 | `sync_handler.dart:7-17` | `getSyncData()` is a stub. All sync operations are no-ops |

### Platform (4)

| ID | File | Issue |
|----|------|-------|
| L-29 | 6 files | `dart:io` imports block Flutter Web compilation |
| L-30 | `main.dart:21-24` | sqflite FFI init missing `Platform.isMacOS` check |
| L-31 | `general_settings_page.dart:1011-1015` | Anti-pattern: `WidgetRef` passed as constructor parameter |
| L-32 | `moment.dart:7-18` | `MomentComment` has no unique identifier |

---

## 5. Optimization Recommendations

### Priority 1 -- Fix Critical Bugs (C-01 to C-12)
All 12 critical issues can cause data loss, security vulnerabilities, or app crashes. Fix immediately.

### Priority 2 -- Error Handling & Observability (H-01, H-05, H-06, H-11)
Replace all `catch (_) {}` with at minimum `debugPrint('$e\n$stackTrace')`. Consider a lightweight logging framework. This alone will save hours of debugging.

### Priority 3 -- Database Performance (H-13, H-14, M-19, M-07, M-09)
- Implement batch operations for `upsertAll`
- Add database-level pagination for messages (`LIMIT`/`OFFSET`)
- Debounce streaming writes
- Consider FTS index for memory card search

### Priority 4 -- Security (H-03, C-02, M-12, M-14)
- Migrate API keys to platform secure storage
- Use `Random.secure()` for all cryptographic operations
- Add regex complexity limits to prevent ReDoS
- Replace hand-rolled KDF with standard library

### Priority 5 -- Provider Architecture (H-04, M-21, M-22, L-17)
- Fix SettingsNotifier race condition with optimistic updates
- Add `ref.onDispose()` for all resource-holding providers
- Introduce `ref.select()` for fine-grained rebuilds

### Priority 6 -- Test Coverage
- Add unit tests for `WebSocketClient`, `SyncManager`, `ConflictResolver`
- Add integration tests for database operations
- Mock services in provider tests for testability

### Priority 7 -- Accessibility
- Add `Semantics` widgets to all interactive elements
- Fix touch target sizes (minimum 48x48)
- Extract strings for future i18n

### Priority 8 -- Code Quality
- Replace hand-written models with freezed code generation
- Split god classes (`ChatService`, `ProactiveService`)
- Introduce dependency injection
- Remove unused code and dead stubs

---

## 6. Test Coverage Assessment

| Module | Coverage | Notes |
|--------|----------|-------|
| Models | Partial | `fromJson`/`fromDbMap` tested, but no round-trip tests |
| Services (memory) | Good | `RetrievalGate`, `ReviewPolicy`, `StateRenderer`, `RegexService` all tested |
| Services (other) | Poor | `ChatService`, `BackupService`, `ProactiveService`, `MomentsService` untested |
| Providers | None | Zero provider tests |
| PC module | None | 1 smoke test only |
| UI pages | Minimal | 1 smoke test for main app |
| Platform config | None | Factory logic untested |

---

*End of report*
