import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/extensions/extension_bridge_service.dart';
import '../../services/extensions/extension_registry_service.dart';
import '../../theme/wechat_colors.dart';

class ExtensionSettingsPage extends StatefulWidget {
  const ExtensionSettingsPage({super.key});

  @override
  State<ExtensionSettingsPage> createState() => _ExtensionSettingsPageState();
}

class _ExtensionSettingsPageState extends State<ExtensionSettingsPage> {
  final ExtensionRegistryService _registry = ExtensionRegistryService();
  late Future<List<InstalledExtension>> _extensions;

  @override
  void initState() {
    super.initState();
    _extensions = _registry.scan();
  }

  void _reload() {
    setState(() {
      _extensions = _registry.scan();
    });
  }

  Future<void> _importExtension() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      await _registry.installFromManifest(File(path));
      _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('扩展已导入')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入失败: $e')));
    }
  }

  Future<void> _toggle(String id, bool enabled) async {
    await _registry.setEnabled(id, enabled);
    await ExtensionBridgeService().initialize().then(
      (bridge) => bridge.loadEnabledExtensions(),
    );
    _reload();
  }

  Future<void> _uninstall(InstalledExtension extension) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('卸载扩展'),
        content: Text('确定卸载 ${extension.manifest.displayName}？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('卸载', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _registry.uninstall(extension.manifest.id);
    _reload();
  }

  Future<void> _clearError(InstalledExtension extension) async {
    await _registry.clearLastError(extension.manifest.id);
    _reload();
  }

  void _showDetails(InstalledExtension extension) {
    final manifest = extension.manifest;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(manifest.displayName),
              subtitle: Text(manifest.id),
            ),
            ListTile(
              title: const Text('版本'),
              subtitle: Text(manifest.version ?? '未知'),
            ),
            ListTile(
              title: const Text('作者'),
              subtitle: Text(manifest.author ?? '未知'),
            ),
            ListTile(
              title: const Text('目录'),
              subtitle: Text(extension.directory.path),
            ),
            ListTile(
              title: const Text('JS'),
              subtitle: Text(manifest.js.join('\n')),
            ),
            if (manifest.css.isNotEmpty)
              ListTile(
                title: const Text('CSS'),
                subtitle: Text(manifest.css.join('\n')),
              ),
            if (extension.lastError != null)
              ListTile(
                title: const Text('最近错误'),
                subtitle: Text(extension.lastError!),
                trailing: TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _clearError(extension);
                  },
                  child: const Text('清除'),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('卸载扩展', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(ctx).pop();
                _uninstall(extension);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        backgroundColor: WeChatColors.appBarBackground,
        title: const Text('扩展管理'),
        actions: [
          IconButton(
            tooltip: '导入扩展',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _importExtension,
          ),
        ],
      ),
      body: FutureBuilder<List<InstalledExtension>>(
        future: _extensions,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }
          final extensions = snapshot.data ?? const [];
          if (extensions.isEmpty) {
            return const Center(child: Text('暂无扩展，点击右上角导入 manifest.json'));
          }
          return ListView.separated(
            itemCount: extensions.length,
            separatorBuilder: (_, _) => const Divider(height: 0, indent: 16),
            itemBuilder: (context, index) {
              final extension = extensions[index];
              final manifest = extension.manifest;
              return SwitchListTile(
                value: extension.enabled,
                activeThumbColor: WeChatColors.primary,
                onChanged: (value) => _toggle(manifest.id, value),
                secondary: IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => _showDetails(extension),
                ),
                title: Text(manifest.displayName),
                subtitle: Text(
                  [
                    if (manifest.version != null) 'v${manifest.version}',
                    if (manifest.author != null) manifest.author!,
                    'JS: ${manifest.js.join(', ')}',
                    if (extension.lastError != null)
                      '错误: ${extension.lastError}',
                  ].join(' · '),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
