import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../models/chat_preset.dart';
import '../../models/regex_script.dart';
import '../../models/voice_config.dart';
import '../../providers/settings_provider.dart';
import '../../providers/preset_provider.dart';
import '../../providers/regex_script_provider.dart';
import '../../services/backup/cloud_storage.dart';
import '../../services/import/import_service.dart';
import '../../theme/wechat_colors.dart';

class GeneralSettingsPage extends ConsumerWidget {
  const GeneralSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final presetsAsync = ref.watch(presetProvider);
    final regexAsync = ref.watch(regexScriptProvider);

    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        backgroundColor: WeChatColors.appBarBackground,
        title: const Text('通用设置'),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (settings) {
          final presets = presetsAsync.value ?? [];
          final regexScripts = regexAsync.value ?? [];
          return ListView(
            children: [
              const SizedBox(height: 8),
              // 显示
              _SectionHeader(title: '显示'),
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('深色模式'),
                      subtitle: const Text('切换深色/浅色主题'),
                      value: settings.darkMode,
                      activeThumbColor: WeChatColors.primary,
                      onChanged: (v) =>
                          ref.read(settingsProvider.notifier).setDarkMode(v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 全局提示词
              _SectionHeader(title: '通用提示词'),
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('启用通用提示词'),
                      subtitle: const Text('对所有聊天生效'),
                      value: settings.globalPromptEnabled,
                      activeThumbColor: WeChatColors.primary,
                      onChanged: (v) => ref
                          .read(settingsProvider.notifier)
                          .setGlobalPromptEnabled(v),
                    ),
                    if (settings.globalPromptEnabled) ...[
                      const Divider(height: 0, indent: 16),
                      ListTile(
                        title: const Text('编辑提示词'),
                        subtitle: Text(
                          settings.globalPromptText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: WeChatColors.textSecondary,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: WeChatColors.textHint,
                        ),
                        onTap: () => _editGlobalPrompt(
                          context,
                          ref,
                          settings.globalPromptText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 用户自我设定
              _SectionHeader(title: '用户自我设定'),
              Container(
                color: Colors.white,
                child: ListTile(
                  title: const Text('编辑自我设定'),
                  subtitle: Text(
                    settings.selfProfile.isEmpty
                        ? '告诉 AI 关于你的信息（年龄、爱好、偏好等）'
                        : settings.selfProfile,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: WeChatColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: WeChatColors.textHint,
                  ),
                  onTap: () =>
                      _editSelfProfile(context, ref, settings.selfProfile),
                ),
              ),
              const SizedBox(height: 8),
              // 对话补全预设
              _SectionHeader(
                title: '对话补全预设',
                trailing: IconButton(
                  icon: const Icon(Icons.file_download_outlined, size: 20),
                  onPressed: () => _importPreset(context, ref),
                  tooltip: '导入预设',
                ),
              ),
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    if (presets.isEmpty)
                      const ListTile(
                        leading: Icon(
                          Icons.info_outline,
                          color: WeChatColors.textHint,
                        ),
                        title: Text('暂无预设'),
                        subtitle: Text(
                          '点击右上角导入 JSON 预设文件',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ...presets.map(
                      (preset) => _PresetTile(
                        preset: preset,
                        onToggle: () => ref
                            .read(presetProvider.notifier)
                            .togglePreset(preset.id),
                        onTap: () => _showPresetDetail(context, ref, preset),
                        onDelete: () =>
                            ref.read(presetProvider.notifier).remove(preset.id),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 正则脚本
              _SectionHeader(
                title: '正则脚本',
                trailing: IconButton(
                  icon: const Icon(Icons.file_download_outlined, size: 20),
                  onPressed: () => _importRegexScripts(context, ref),
                  tooltip: '导入正则脚本',
                ),
              ),
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    if (regexScripts.isEmpty)
                      const ListTile(
                        leading: Icon(
                          Icons.info_outline,
                          color: WeChatColors.textHint,
                        ),
                        title: Text('暂无正则脚本'),
                        subtitle: Text(
                          '导入 SillyTavern 正则包 JSON 文件',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ...regexScripts.map(
                      (script) => _RegexScriptTile(
                        script: script,
                        onToggle: () => ref
                            .read(regexScriptProvider.notifier)
                            .toggle(script.id),
                        onDelete: () => ref
                            .read(regexScriptProvider.notifier)
                            .remove(script.id),
                      ),
                    ),
                    if (regexScripts.isNotEmpty)
                      ListTile(
                        leading: const Icon(
                          Icons.delete_sweep,
                          color: Colors.red,
                          size: 20,
                        ),
                        title: const Text(
                          '清空所有正则脚本',
                          style: TextStyle(color: Colors.red, fontSize: 14),
                        ),
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('清空正则脚本'),
                              content: const Text('确定删除所有正则脚本？'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text(
                                    '清空',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            ref.read(regexScriptProvider.notifier).removeAll();
                          }
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 记忆表格设置
              _SectionHeader(title: '记忆表格'),
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('启用记忆表格'),
                      subtitle: const Text('AI 自动从对话中提取关键信息'),
                      value: settings.memoryEnabled,
                      activeThumbColor: WeChatColors.primary,
                      onChanged: (v) => ref
                          .read(settingsProvider.notifier)
                          .setMemoryEnabled(v),
                    ),
                    if (settings.memoryEnabled) ...[
                      const Divider(height: 0, indent: 16),
                      ListTile(
                        title: const Text('更新频率'),
                        subtitle: Text(
                          '每 ${settings.memoryInterval} 句对话更新一次',
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: WeChatColors.textHint,
                        ),
                        onTap: () => _editMemoryInterval(
                          context,
                          ref,
                          settings.memoryInterval,
                        ),
                      ),
                      const Divider(height: 0, indent: 16),
                      SwitchListTile(
                        title: const Text('使用主 API 填表'),
                        subtitle: const Text('关闭后需配置副 API 以节省消耗'),
                        value: settings.memoryUseMainApi,
                        activeThumbColor: WeChatColors.primary,
                        onChanged: (v) => ref
                            .read(settingsProvider.notifier)
                            .setMemoryUseMainApi(v),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 语音服务
              _SectionHeader(title: '语音服务'),
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.mic,
                        color: WeChatColors.primary,
                      ),
                      title: const Text('语音识别（STT）'),
                      subtitle: const Text(
                        '语音转文字',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: WeChatColors.textHint,
                      ),
                      onTap: () => _showVoiceConfigSheet(context, ref, 'stt'),
                    ),
                    const Divider(height: 0, indent: 56),
                    ListTile(
                      leading: const Icon(
                        Icons.volume_up,
                        color: WeChatColors.primary,
                      ),
                      title: const Text('语音合成（TTS）'),
                      subtitle: const Text(
                        '文字转语音',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: WeChatColors.textHint,
                      ),
                      onTap: () => _showVoiceConfigSheet(context, ref, 'tts'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 朋友圈更新间隔
              _SectionHeader(title: '朋友圈'),
              Container(
                color: Colors.white,
                child: ListTile(
                  title: const Text('自动更新间隔'),
                  subtitle: Text(
                    '${settings.momentsIntervalMinutes} 分钟',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: WeChatColors.textHint,
                  ),
                  onTap: () => _editMomentsInterval(
                    context,
                    ref,
                    settings.momentsIntervalMinutes,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 更新
              _SectionHeader(title: '更新'),
              Container(
                color: Colors.white,
                child: SwitchListTile(
                  title: const Text('启动时检查更新'),
                  subtitle: const Text('打开应用时自动检查 GitHub Release'),
                  value: settings.checkUpdateOnStartup,
                  activeThumbColor: WeChatColors.primary,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .setCheckUpdateOnStartup(v),
                ),
              ),
              const SizedBox(height: 8),
              // 钱包
              _SectionHeader(title: '钱包'),
              Container(
                color: Colors.white,
                child: ListTile(
                  title: const Text('钱包余额'),
                  subtitle: Text(
                    '¥${settings.walletBalance.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: WeChatColors.textHint,
                  ),
                  onTap: () =>
                      _editWalletBalance(context, ref, settings.walletBalance),
                ),
              ),
              const SizedBox(height: 8),
              // 自动备份
              _SectionHeader(title: '自动备份'),
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('启用自动备份'),
                      subtitle: const Text('定期备份数据到云端'),
                      value: settings.autoBackupEnabled,
                      activeThumbColor: WeChatColors.primary,
                      onChanged: (v) => ref
                          .read(settingsProvider.notifier)
                          .setAutoBackupEnabled(v),
                    ),
                    if (settings.autoBackupEnabled) ...[
                      const Divider(height: 0, indent: 16),
                      ListTile(
                        title: const Text('备份间隔'),
                        subtitle: Text(
                          '${settings.autoBackupInterval} 分钟',
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: WeChatColors.textHint,
                        ),
                        onTap: () => _editAutoBackupInterval(
                          context,
                          ref,
                          settings.autoBackupInterval,
                        ),
                      ),
                      const Divider(height: 0, indent: 16),
                      ListTile(
                        title: const Text('云存储配置'),
                        subtitle: Text(
                          settings.autoBackupCloudType.isEmpty
                              ? '未配置'
                              : settings.autoBackupCloudType.toUpperCase(),
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: WeChatColors.textHint,
                        ),
                        onTap: () =>
                            _showCloudConfigSheet(context, ref, settings),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  void _editSelfProfile(BuildContext context, WidgetRef ref, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑自我设定'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '告诉 AI 关于你的一切，让它更了解你：'
              '年龄、职业、爱好、性格、喜欢的食物、最近在忙什么...',
              style: TextStyle(fontSize: 12, color: WeChatColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText:
                    '示例：\n我今年25岁，程序员，喜欢喝奶茶和打游戏。'
                    '最近在学Flutter开发，养了一只叫小橘的猫。'
                    '不喜欢吃香菜，对海鲜过敏...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(settingsProvider.notifier)
                  .setSelfProfile(ctrl.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _editGlobalPrompt(BuildContext context, WidgetRef ref, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑通用提示词'),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '输入提示词内容...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(settingsProvider.notifier)
                  .setGlobalPromptText(ctrl.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _editMomentsInterval(BuildContext context, WidgetRef ref, int current) {
    final intervals = [15, 30, 60, 120, 360, 720, 1440];
    final labels = ['15 分钟', '30 分钟', '1 小时', '2 小时', '6 小时', '12 小时', '24 小时'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '选择更新间隔',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ...List.generate(
              intervals.length,
              (i) => ListTile(
                title: Text(labels[i]),
                selected: intervals[i] == current,
                trailing: intervals[i] == current
                    ? const Icon(Icons.check, color: WeChatColors.primary)
                    : null,
                onTap: () {
                  ref
                      .read(settingsProvider.notifier)
                      .setMomentsInterval(intervals[i]);
                  Navigator.of(ctx).pop();
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _importPreset(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: '选择预设 JSON 文件',
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    try {
      final content = await File(path).readAsString();
      final validation = ImportService.validatePreset(content);

      if (!validation.isValid) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('导入失败：${validation.error}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      final json = validation.data!;
      final preset = ChatPreset.fromJson(json);
      if (preset.segments.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('预设文件中没有找到有效的段落')));
        }
        return;
      }
      await ref.read(presetProvider.notifier).add(preset);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已导入预设「${preset.name}」')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    }
  }

  Future<void> _importRegexScripts(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: '选择正则脚本 JSON 文件',
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    try {
      final content = await File(path).readAsString();
      final validation = ImportService.validateRegexScripts(content);

      if (!validation.isValid) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('导入失败：${validation.error}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      final scriptsData = validation.data!;
      final scriptsList = scriptsData['scripts'] as List;
      final scripts = scriptsList
          .map((e) => RegexScript.fromJson(e as Map<String, dynamic>))
          .toList();

      if (scripts.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('未找到有效的正则脚本')));
        }
        return;
      }

      await ref.read(regexScriptProvider.notifier).importScripts(scripts);
      if (context.mounted) {
        String msg = '已导入 ${scripts.length} 个正则脚本';
        if (validation.warning != null) {
          msg += '（${validation.warning}）';
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    }
  }

  void _editMemoryInterval(BuildContext context, WidgetRef ref, int current) {
    final intervals = [5, 10, 15, 20, 30, 50];
    final labels = ['5 句', '10 句', '15 句', '20 句', '30 句', '50 句'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '选择记忆更新频率',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ...List.generate(
              intervals.length,
              (i) => ListTile(
                title: Text(labels[i]),
                selected: intervals[i] == current,
                trailing: intervals[i] == current
                    ? const Icon(Icons.check, color: WeChatColors.primary)
                    : null,
                onTap: () {
                  ref
                      .read(settingsProvider.notifier)
                      .setMemoryInterval(intervals[i]);
                  Navigator.of(ctx).pop();
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _editAutoBackupInterval(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) {
    final intervals = [15, 30, 60, 120, 360, 720, 1440];
    final labels = ['15 分钟', '30 分钟', '1 小时', '2 小时', '6 小时', '12 小时', '24 小时'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '选择备份间隔',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ...List.generate(
              intervals.length,
              (i) => ListTile(
                title: Text(labels[i]),
                selected: intervals[i] == current,
                trailing: intervals[i] == current
                    ? const Icon(Icons.check, color: WeChatColors.primary)
                    : null,
                onTap: () {
                  ref
                      .read(settingsProvider.notifier)
                      .setAutoBackupInterval(intervals[i]);
                  Navigator.of(ctx).pop();
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showVoiceConfigSheet(
    BuildContext context,
    WidgetRef ref,
    String type,
  ) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _VoiceConfigSheet(type: type),
    );
  }

  void _showCloudConfigSheet(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CloudConfigSheet(settings: settings, ref: ref),
    );
  }

  void _editWalletBalance(BuildContext context, WidgetRef ref, double current) {
    final ctrl = TextEditingController(text: current.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自定义钱包余额'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '仅用于测试调整，实际使用请通过钱包充值/支出',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '余额',
                prefixText: '¥ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(ctrl.text.trim());
              if (amount != null && amount >= 0) {
                ref.read(settingsProvider.notifier).setWalletBalance(amount);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('设置'),
          ),
        ],
      ),
    );
  }

  void _showPresetDetail(
    BuildContext context,
    WidgetRef ref,
    ChatPreset preset,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      preset.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    preset.enabled ? '已启用' : '已禁用',
                    style: TextStyle(
                      color: preset.enabled
                          ? WeChatColors.primary
                          : WeChatColors.textHint,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 0),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: preset.segments.length,
                itemBuilder: (_, index) {
                  final seg = preset.segments[index];
                  return Column(
                    children: [
                      SwitchListTile(
                        title: Text(
                          seg.label.isNotEmpty ? seg.label : '段落 ${index + 1}',
                        ),
                        subtitle: Text(
                          seg.content,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: seg.enabled,
                        activeThumbColor: WeChatColors.primary,
                        onChanged: (_) => ref
                            .read(presetProvider.notifier)
                            .toggleSegment(preset.id, index),
                      ),
                      const Divider(height: 0),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: WeChatColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final ChatPreset preset;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PresetTile({
    required this.preset,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final enabledCount = preset.segments.where((s) => s.enabled).length;
    return ListTile(
      title: Text(preset.name),
      subtitle: Text(
        '$enabledCount/${preset.segments.length} 段落已启用',
        style: const TextStyle(fontSize: 12),
      ),
      leading: Switch(
        value: preset.enabled,
        activeThumbColor: WeChatColors.primary,
        onChanged: (_) => onToggle(),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right, color: WeChatColors.textHint),
            onPressed: onTap,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: WeChatColors.textHint,
              size: 20,
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('删除预设'),
                  content: Text('确定删除「${preset.name}」？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text(
                        '删除',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) onDelete();
            },
          ),
        ],
      ),
    );
  }
}

class _CloudConfigSheet extends StatefulWidget {
  final AppSettings settings;
  final WidgetRef ref;

  const _CloudConfigSheet({required this.settings, required this.ref});

  @override
  State<_CloudConfigSheet> createState() => _CloudConfigSheetState();
}

class _CloudConfigSheetState extends State<_CloudConfigSheet> {
  late String _cloudType;
  bool _testing = false;
  String? _testResult;

  // WebDAV
  final _webdavUrlCtrl = TextEditingController();
  final _webdavUserCtrl = TextEditingController();
  final _webdavPassCtrl = TextEditingController();

  // S3
  final _s3EndpointCtrl = TextEditingController();
  final _s3RegionCtrl = TextEditingController();
  final _s3AccessKeyCtrl = TextEditingController();
  final _s3SecretKeyCtrl = TextEditingController();
  final _s3BucketCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cloudType = widget.settings.autoBackupCloudType.isEmpty
        ? 'webdav'
        : widget.settings.autoBackupCloudType;
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _webdavUrlCtrl.text = prefs.getString('auto_backup_webdav_url') ?? '';
    _webdavUserCtrl.text = prefs.getString('auto_backup_webdav_username') ?? '';
    _webdavPassCtrl.text = prefs.getString('auto_backup_webdav_password') ?? '';
    _s3EndpointCtrl.text = prefs.getString('auto_backup_s3_endpoint') ?? '';
    _s3RegionCtrl.text =
        prefs.getString('auto_backup_s3_region') ?? 'us-east-1';
    _s3AccessKeyCtrl.text = prefs.getString('auto_backup_s3_access_key') ?? '';
    _s3SecretKeyCtrl.text = prefs.getString('auto_backup_s3_secret_key') ?? '';
    _s3BucketCtrl.text = prefs.getString('auto_backup_s3_bucket') ?? '';
  }

  @override
  void dispose() {
    _webdavUrlCtrl.dispose();
    _webdavUserCtrl.dispose();
    _webdavPassCtrl.dispose();
    _s3EndpointCtrl.dispose();
    _s3RegionCtrl.dispose();
    _s3AccessKeyCtrl.dispose();
    _s3SecretKeyCtrl.dispose();
    _s3BucketCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    '云存储配置',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _save,
                    child: const Text(
                      '保存配置',
                      style: TextStyle(
                        color: WeChatColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 0),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    '存储类型',
                    style: TextStyle(
                      fontSize: 13,
                      color: WeChatColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'webdav', label: Text('WebDAV')),
                      ButtonSegment(value: 's3', label: Text('S3')),
                    ],
                    selected: {_cloudType},
                    onSelectionChanged: (v) =>
                        setState(() => _cloudType = v.first),
                  ),
                  const SizedBox(height: 16),
                  if (_cloudType == 'webdav') ..._buildWebDavFields(),
                  if (_cloudType == 's3') ..._buildS3Fields(),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      icon: _testing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_find, size: 18),
                      label: Text(_testing ? '测试中...' : '测试连接'),
                      onPressed: _testing ? null : _testConnection,
                    ),
                  ),
                  if (_testResult != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _testResult!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _testResult!.contains('成功')
                            ? WeChatColors.primary
                            : Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWebDavFields() {
    return [
      _buildField(
        '服务器 URL',
        _webdavUrlCtrl,
        hint: 'https://dav.example.com/backup',
      ),
      const SizedBox(height: 12),
      _buildField('用户名', _webdavUserCtrl, hint: '用户名'),
      const SizedBox(height: 12),
      _buildField('密码', _webdavPassCtrl, hint: '密码', obscure: true),
    ];
  }

  List<Widget> _buildS3Fields() {
    return [
      _buildField(
        'Endpoint',
        _s3EndpointCtrl,
        hint: 'https://s3.amazonaws.com',
      ),
      const SizedBox(height: 12),
      _buildField('Region', _s3RegionCtrl, hint: 'us-east-1'),
      const SizedBox(height: 12),
      _buildField('Access Key', _s3AccessKeyCtrl, hint: 'AKIA...'),
      const SizedBox(height: 12),
      _buildField(
        'Secret Key',
        _s3SecretKeyCtrl,
        hint: '••••••••',
        obscure: true,
      ),
      const SizedBox(height: 12),
      _buildField('Bucket', _s3BucketCtrl, hint: 'my-backup-bucket'),
    ];
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    String? hint,
    bool obscure = false,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 13),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        isDense: true,
      ),
    );
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auto_backup_cloud_type', _cloudType);
    if (_cloudType == 'webdav') {
      await prefs.setString('auto_backup_webdav_url', _webdavUrlCtrl.text);
      await prefs.setString(
        'auto_backup_webdav_username',
        _webdavUserCtrl.text,
      );
      await prefs.setString(
        'auto_backup_webdav_password',
        _webdavPassCtrl.text,
      );
    } else {
      await prefs.setString('auto_backup_s3_endpoint', _s3EndpointCtrl.text);
      await prefs.setString('auto_backup_s3_region', _s3RegionCtrl.text);
      await prefs.setString('auto_backup_s3_access_key', _s3AccessKeyCtrl.text);
      await prefs.setString('auto_backup_s3_secret_key', _s3SecretKeyCtrl.text);
      await prefs.setString('auto_backup_s3_bucket', _s3BucketCtrl.text);
    }
    widget.ref
        .read(settingsProvider.notifier)
        .setAutoBackupCloudType(_cloudType);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });

    try {
      // Import locally to avoid issues
      final storage = _cloudType == 'webdav'
          ? WebDavStorage(
              WebDavConfig(
                url: _webdavUrlCtrl.text,
                username: _webdavUserCtrl.text,
                password: _webdavPassCtrl.text,
              ),
            )
          : S3Storage(
              S3Config(
                endpoint: _s3EndpointCtrl.text,
                region: _s3RegionCtrl.text,
                accessKey: _s3AccessKeyCtrl.text,
                secretKey: _s3SecretKeyCtrl.text,
                bucket: _s3BucketCtrl.text,
              ),
            );

      final ok = await storage.testConnection();
      setState(() {
        _testing = false;
        _testResult = ok ? '连接成功' : '连接失败';
      });
    } catch (e) {
      setState(() {
        _testing = false;
        _testResult = '连接失败: $e';
      });
    }
  }
}

class _VoiceConfigSheet extends StatefulWidget {
  final String type;
  const _VoiceConfigSheet({required this.type});

  @override
  State<_VoiceConfigSheet> createState() => _VoiceConfigSheetState();
}

class _VoiceConfigSheetState extends State<_VoiceConfigSheet> {
  late final _apiKeyCtrl = TextEditingController();
  late final _baseUrlCtrl = TextEditingController();
  late final _modelCtrl = TextEditingController();
  late final _voiceCtrl = TextEditingController();
  late final _groupIdCtrl = TextEditingController();
  late final _languageCtrl = TextEditingController();
  late double _speed;
  late double _volume;
  late double _pitch;
  late String _audioFormat;
  late bool _autoPlay;
  late List<CustomVoice> _customVoices;
  late List<VoiceMapping> _voiceMappings;

  TtsProvider _ttsProvider = TtsProvider.openai;
  String _sttProvider = 'openai';
  bool _showKey = false;

  List<String> _availableModels = [];
  bool _isFetchingModels = false;
  String? _fetchModelError;

  bool get _isStt => widget.type == 'stt';

  @override
  void initState() {
    super.initState();
    _speed = 1.0;
    _volume = 1.0;
    _pitch = 1.0;
    _audioFormat = 'mp3';
    _autoPlay = false;
    _customVoices = [];
    _voiceMappings = [];
    _loadConfig().then((_) => setState(() {}));
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isStt) {
      final sttConfig = await SttConfig.load(prefs);
      _sttProvider = sttConfig.provider;
      _apiKeyCtrl.text = sttConfig.apiKey;
      _baseUrlCtrl.text = sttConfig.baseUrl;
      _modelCtrl.text = sttConfig.model;
      _languageCtrl.text = sttConfig.language;
    } else {
      final ttsConfig = await TtsConfig.load(prefs);
      _ttsProvider = ttsConfig.provider;
      _apiKeyCtrl.text = ttsConfig.apiKey;
      _baseUrlCtrl.text = ttsConfig.baseUrl;
      _modelCtrl.text = ttsConfig.model;
      _voiceCtrl.text = ttsConfig.voice;
      _groupIdCtrl.text = ttsConfig.groupId;
      _languageCtrl.text = ttsConfig.language;
      _speed = ttsConfig.speed;
      _volume = ttsConfig.volume;
      _pitch = ttsConfig.pitch;
      _audioFormat = ttsConfig.audioFormat;
      _autoPlay = ttsConfig.autoPlay;
      _customVoices = List.from(ttsConfig.customVoices);
      _voiceMappings = List.from(ttsConfig.voiceMappings);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isStt) {
      final sttConfig = SttConfig(
        provider: _sttProvider,
        apiKey: _apiKeyCtrl.text.trim(),
        baseUrl: _baseUrlCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        language: _languageCtrl.text.trim(),
      );
      await sttConfig.save(prefs);
    } else {
      final ttsConfig = TtsConfig(
        provider: _ttsProvider,
        apiKey: _apiKeyCtrl.text.trim(),
        baseUrl: _baseUrlCtrl.text.trim().isEmpty
            ? _ttsProvider.defaultBaseUrl
            : _baseUrlCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        voice: _voiceCtrl.text.trim(),
        groupId: _groupIdCtrl.text.trim(),
        language: _languageCtrl.text.trim(),
        speed: _speed,
        volume: _volume,
        pitch: _pitch,
        audioFormat: _audioFormat,
        autoPlay: _autoPlay,
        customVoices: _customVoices,
        voiceMappings: _voiceMappings,
      );
      await ttsConfig.save(prefs);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _fetchModels() async {
    final baseUrl = _baseUrlCtrl.text.trim();
    final apiKey = _apiKeyCtrl.text.trim();

    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先填写 API Key')));
      return;
    }
    if (baseUrl.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先填写 Base URL')));
      return;
    }

    setState(() {
      _isFetchingModels = true;
      _fetchModelError = null;
    });

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final normalizedUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final resp = await dio.get(
        '$normalizedUrl/models',
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      );
      final list = (resp.data['data'] as List?) ?? [];
      final models = list.map((m) => m['id'] as String).toList()..sort();

      if (!mounted) return;
      setState(() {
        _availableModels = models;
        _isFetchingModels = false;
        if (models.isNotEmpty && !models.contains(_modelCtrl.text)) {
          _modelCtrl.text = models.first;
        }
      });
    } on DioException catch (e) {
      if (!mounted) return;
      String msg;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        msg = '连接超时，请检查 URL 是否正确';
      } else if (e.response != null) {
        msg = 'HTTP ${e.response!.statusCode}：${e.response!.statusMessage}';
      } else {
        msg = '请求失败：${e.message}';
      }
      setState(() {
        _isFetchingModels = false;
        _fetchModelError = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFetchingModels = false;
        _fetchModelError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _modelCtrl.dispose();
    _voiceCtrl.dispose();
    _groupIdCtrl.dispose();
    _languageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    _isStt ? '语音识别（STT）' : '语音合成（TTS）',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _save,
                    child: const Text(
                      '保存',
                      style: TextStyle(
                        color: WeChatColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 0),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: _isStt ? _buildSttFields() : _buildTtsFields(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSttFields() {
    return [
      DropdownButtonFormField<String>(
        initialValue: _sttProvider,
        decoration: const InputDecoration(labelText: '提供商'),
        items: const [
          DropdownMenuItem(value: 'openai', child: Text('OpenAI Whisper')),
          DropdownMenuItem(value: 'azure', child: Text('Azure Speech')),
          DropdownMenuItem(value: 'custom', child: Text('自定义 API')),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _sttProvider = v);
        },
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _baseUrlCtrl,
        decoration: const InputDecoration(
          labelText: 'Base URL',
          hintText: 'https://api.openai.com/v1',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _apiKeyCtrl,
        obscureText: !_showKey,
        decoration: InputDecoration(
          labelText: 'API Key',
          hintText: 'sk-...',
          suffixIcon: IconButton(
            icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _showKey = !_showKey),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _buildModelField('whisper-1'),
      const SizedBox(height: 12),
      TextField(
        controller: _languageCtrl,
        decoration: const InputDecoration(labelText: '语言', hintText: 'zh'),
      ),
    ];
  }

  Widget _buildModelField(String hintText) {
    final dropdownModels = [
      ..._availableModels,
      if (_modelCtrl.text.isNotEmpty) _modelCtrl.text,
    ].toList()..sort();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _availableModels.isEmpty
              ? TextField(
                  controller: _modelCtrl,
                  decoration: InputDecoration(
                    labelText: '模型',
                    hintText: hintText,
                    errorText: _fetchModelError,
                    errorMaxLines: 2,
                  ),
                )
              : DropdownButtonFormField<String>(
                  key: ValueKey(_availableModels.join(',')),
                  initialValue:
                      _modelCtrl.text.isNotEmpty &&
                          dropdownModels.contains(_modelCtrl.text)
                      ? _modelCtrl.text
                      : dropdownModels.first,
                  decoration: const InputDecoration(labelText: '模型'),
                  isExpanded: true,
                  items: dropdownModels
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(m, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _modelCtrl.text = v);
                    }
                  },
                ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          height: 48,
          child: _isFetchingModels
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    _availableModels.isEmpty
                        ? Icons.cloud_download_outlined
                        : Icons.refresh,
                    color: WeChatColors.primary,
                  ),
                  tooltip: '从 API 获取模型列表',
                  onPressed: _fetchModels,
                ),
        ),
      ],
    );
  }

  List<Widget> _buildTtsFields() {
    return [
      DropdownButtonFormField<TtsProvider>(
        initialValue: _ttsProvider,
        decoration: const InputDecoration(labelText: '提供商'),
        items: TtsProvider.values
            .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
            .toList(),
        onChanged: (v) {
          if (v != null) {
            setState(() {
              _ttsProvider = v;
              if (_baseUrlCtrl.text.isEmpty) {
                _baseUrlCtrl.text = v.defaultBaseUrl;
              }
            });
          }
        },
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _baseUrlCtrl,
        decoration: InputDecoration(
          labelText: 'API 主机（Base URL）',
          hintText: _ttsProvider.defaultBaseUrl,
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _apiKeyCtrl,
        obscureText: !_showKey,
        decoration: InputDecoration(
          labelText: 'API Key',
          hintText: _ttsProvider == TtsProvider.elevenlabs
              ? 'xi_...'
              : 'sk-...',
          suffixIcon: IconButton(
            icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _showKey = !_showKey),
          ),
        ),
      ),
      if (_ttsProvider == TtsProvider.azure) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _groupIdCtrl,
          decoration: const InputDecoration(
            labelText: '资源组 ID（Region）',
            hintText: 'eastus',
          ),
        ),
      ],
      if (_ttsProvider == TtsProvider.elevenlabs) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _groupIdCtrl,
          decoration: const InputDecoration(
            labelText: 'Group ID',
            hintText: 'ElevenLabs Group ID',
          ),
        ),
      ],
      const SizedBox(height: 12),
      _buildModelField(
        _ttsProvider == TtsProvider.openai
            ? 'tts-1'
            : _ttsProvider == TtsProvider.elevenlabs
            ? 'eleven_multilingual_v2'
            : '',
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _voiceCtrl,
        decoration: InputDecoration(
          labelText: '语音（Voice ID）',
          hintText: _ttsProvider == TtsProvider.openai
              ? 'alloy / echo / fable / onyx / nova / shimmer'
              : _ttsProvider == TtsProvider.azure
              ? 'zh-CN-XiaoxiaoNeural'
              : _ttsProvider == TtsProvider.edge
              ? 'zh-CN-XiaoxiaoNeural'
              : _ttsProvider == TtsProvider.elevenlabs
              ? 'Voice ID from ElevenLabs'
              : 'Voice ID',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _languageCtrl,
        decoration: const InputDecoration(labelText: '语言', hintText: 'zh-CN'),
      ),
      const SizedBox(height: 16),
      const Text(
        '语音参数',
        style: TextStyle(
          fontSize: 13,
          color: WeChatColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 8),
      _buildSlider('语速', _speed, 0.25, 4.0, (v) => setState(() => _speed = v)),
      _buildSlider('音量', _volume, 0.0, 2.0, (v) => setState(() => _volume = v)),
      _buildSlider('音高', _pitch, 0.0, 2.0, (v) => setState(() => _pitch = v)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: _audioFormat,
        decoration: const InputDecoration(labelText: '音频格式'),
        items: const [
          DropdownMenuItem(value: 'mp3', child: Text('MP3')),
          DropdownMenuItem(value: 'wav', child: Text('WAV')),
          DropdownMenuItem(value: 'opus', child: Text('Opus')),
          DropdownMenuItem(value: 'aac', child: Text('AAC')),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _audioFormat = v);
        },
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        title: const Text('自动播放 AI 回复'),
        subtitle: const Text('收到 AI 回复后自动朗读'),
        value: _autoPlay,
        activeThumbColor: WeChatColors.primary,
        onChanged: (v) => setState(() => _autoPlay = v),
        contentPadding: EdgeInsets.zero,
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          const Text(
            '自定义语音',
            style: TextStyle(
              fontSize: 13,
              color: WeChatColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: _addCustomVoice,
            tooltip: '添加自定义语音',
          ),
        ],
      ),
      const SizedBox(height: 4),
      ..._customVoices.map(
        (v) => ListTile(
          dense: true,
          title: Text(v.name),
          subtitle: Text(
            '${v.language} · ${v.providerVoiceId ?? v.id}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => setState(() => _customVoices.remove(v)),
          ),
        ),
      ),
      if (_customVoices.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '暂无自定义语音，点击 + 添加',
            style: TextStyle(fontSize: 12, color: WeChatColors.textHint),
          ),
        ),
      const SizedBox(height: 16),
      Row(
        children: [
          const Text(
            '语音映射（角色→语音）',
            style: TextStyle(
              fontSize: 13,
              color: WeChatColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: _addVoiceMapping,
            tooltip: '添加语音映射',
          ),
        ],
      ),
      const SizedBox(height: 4),
      ..._voiceMappings.map(
        (m) => ListTile(
          dense: true,
          title: Text(m.characterName),
          subtitle: Text(
            '→ ${m.voiceName}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => setState(() => _voiceMappings.remove(m)),
          ),
        ),
      ),
      if (_voiceMappings.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '暂无语音映射，点击 + 为角色分配语音',
            style: TextStyle(fontSize: 12, color: WeChatColors.textHint),
          ),
        ),
    ];
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) * 10).toInt(),
            label: value.toStringAsFixed(1),
            activeColor: WeChatColors.primary,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Future<void> _addCustomVoice() async {
    final nameCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    final langCtrl = TextEditingController(text: 'zh-CN');
    final providerIdCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加自定义语音'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '语音名称 *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: idCtrl,
              decoration: const InputDecoration(labelText: '语音 ID *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: langCtrl,
              decoration: const InputDecoration(labelText: '语言'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: providerIdCtrl,
              decoration: const InputDecoration(
                labelText: '提供商语音 ID（可选）',
                hintText: '如 Azure 的完整语音名称',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty || idCtrl.text.trim().isEmpty) {
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _customVoices.add(
          CustomVoice(
            id: idCtrl.text.trim(),
            name: nameCtrl.text.trim(),
            language: langCtrl.text.trim(),
            providerVoiceId: providerIdCtrl.text.trim().isEmpty
                ? null
                : providerIdCtrl.text.trim(),
          ),
        );
      });
    }
  }

  Future<void> _addVoiceMapping() async {
    final charNameCtrl = TextEditingController();
    final voiceIdCtrl = TextEditingController();
    final voiceNameCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加语音映射'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: charNameCtrl,
              decoration: const InputDecoration(
                labelText: '角色名称 *',
                hintText: '输入角色名称',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: voiceIdCtrl,
              decoration: const InputDecoration(
                labelText: '语音 ID *',
                hintText: 'alloy / zh-CN-XiaoxiaoNeural',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: voiceNameCtrl,
              decoration: const InputDecoration(
                labelText: '语音显示名称',
                hintText: '晓晓',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (charNameCtrl.text.trim().isEmpty ||
                  voiceIdCtrl.text.trim().isEmpty) {
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _voiceMappings.add(
          VoiceMapping(
            characterId: '',
            characterName: charNameCtrl.text.trim(),
            voiceId: voiceIdCtrl.text.trim(),
            voiceName: voiceNameCtrl.text.trim().isEmpty
                ? voiceIdCtrl.text.trim()
                : voiceNameCtrl.text.trim(),
          ),
        );
      });
    }
  }
}

class _RegexScriptTile extends StatelessWidget {
  final RegexScript script;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _RegexScriptTile({
    required this.script,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final placements = script.placement
        .map((p) => RegexPlacement.label(p))
        .join(', ');
    return ListTile(
      title: Text(
        script.scriptName,
        style: TextStyle(
          color: script.disabled
              ? WeChatColors.textHint
              : WeChatColors.textPrimary,
        ),
      ),
      subtitle: Text(
        placements.isNotEmpty ? '作用: $placements' : '无作用范围',
        style: const TextStyle(fontSize: 12),
      ),
      leading: Switch(
        value: !script.disabled,
        activeThumbColor: WeChatColors.primary,
        onChanged: (_) => onToggle(),
      ),
      trailing: IconButton(
        icon: const Icon(
          Icons.delete_outline,
          color: WeChatColors.textHint,
          size: 20,
        ),
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('删除正则脚本'),
              content: Text('确定删除「${script.scriptName}」？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('删除', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          if (confirm == true) onDelete();
        },
      ),
    );
  }
}
