# Changelog

## Unreleased - 2026-06-07

### Added

- Added the local-first file authority layer for `st_compat/` and `soultalk/`, including path sanitization, atomic writes, manifest scanning, and SQLite-backed file indexes.
- Added SillyTavern L1 read compatibility for character cards, chat JSONL, world info, presets, regex scripts, macros, and prompt assembly.
- Added repository and DAO layers for ST-compatible characters, chats, worlds, presets, attachments, scheduler jobs, and scheduler run logs.
- Added managed attachment import support under `soultalk/attachments/{chatId}/`, with SHA-256, size, MIME type, original filename, and chat metadata export.
- Added backup coverage for `st_compat/` files and SoulTalk attachments, including manifest file metadata, restore points, hash verification, and index rebuild hooks.
- Added unified scheduler foundations and initial proactive/friend-circle scheduling handlers.
- Added LanSync protocol, pairing, manifest, push/pull, and PC mirror database foundations.
- Added ExtensionBridge models, manifest parsing, guarded sandbox adapter, event bus, context provider, and settings entry.
- Added tests for ST parsers/repositories, prompt assembly, legacy export, backups, attachments, scheduler behavior, LanSync protocol, and extension bridge behavior.

### Changed

- Prompt assembly now incorporates ST character card fields, regex scripts, and post-history instructions into request messages without appending fake user messages.
- Chat sending now uses unified request message assembly for streaming and non-streaming paths.
- Existing image/file sending now imports files through `AttachmentService` while keeping the chat UI behavior.
- Proactive message scheduling now persists JSON keys, restores future timers on restart, cleans expired keys, and records immediate sends with current timestamps.
- Backup restore now performs safer path handling and rebuilds compatibility indexes after file restoration.
- Flutter/Dart dependencies were refreshed with the portable SDK environment installed under `E:\env`.

### Fixed

- Fixed attachment directory traversal risk by sanitizing chat IDs before building managed attachment paths.
- Removed duplicate image/file attachment save logic in the chat page.
- Removed duplicate attachment file resolution logic in message bubbles.
- Replaced a production `print` in proactive time mismatch logging with `developer.log`.
- Fixed prior syntax and string separator regressions in chat, backup, prompt assembly, and proactive scheduling code paths.

### Notes

- Flutter SDK `3.44.1` and Dart `3.12.1` are installed under `E:\env\flutter`; Pub cache is under `E:\env\pub-cache`.
- Windows Developer Mode, Android SDK license setup, Android cmdline-tools, and Visual Studio are not configured by this change because they are system-level setup outside the portable `E:\env` dependency install.
