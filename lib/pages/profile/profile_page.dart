import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/api_config_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/wechat_colors.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiConfigs = ref.watch(apiConfigProvider).value ?? [];
    final contactsAsync = ref.watch(contactsProvider);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        title: const Text('我'),
        backgroundColor: WeChatColors.appBarBackground,
      ),
      body: ListView(
        children: [
          // 用户信息卡片
          _buildUserCard(apiConfigs, contactsAsync, ref),
          const SizedBox(height: 8),
          // 核心功能
          _buildSectionHeader('核心功能'),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildTile(
                  icon: Icons.api,
                  color: Colors.green,
                  title: 'API 配置',
                  subtitle: apiConfigs.isEmpty
                      ? '未配置（点击添加）'
                      : '${apiConfigs.length} 个配置',
                  warning: apiConfigs.isEmpty,
                  onTap: () => context.push('/settings/api'),
                ),
                const _Divider(),
                _buildTile(
                  icon: Icons.people,
                  color: const Color(0xFF576B95),
                  title: '角色管理',
                  subtitle: contactsAsync.when(
                    data: (contacts) => '${contacts.length} 个 AI 角色',
                    loading: () => '加载中...',
                    error: (error, stackTrace) => '加载失败',
                  ),
                  onTap: () => context.push('/contacts'),
                ),
                const _Divider(),
                _buildTile(
                  icon: Icons.computer,
                  color: Colors.blue,
                  title: '连接电脑',
                  subtitle: '扫描 PC 端二维码连接',
                  onTap: () => context.push('/pc-connect'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 设置
          _buildSectionHeader('设置'),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildTile(
                  icon: Icons.tune,
                  color: WeChatColors.primary,
                  title: '通用设置',
                  subtitle: settingsAsync.when(
                    data: (s) =>
                        s.globalPromptEnabled ? '通用提示词已启用' : '通用提示词未启用',
                    loading: () => '',
                    error: (error, stackTrace) => '',
                  ),
                  onTap: () => context.push('/settings/general'),
                ),
                const _Divider(),
                _buildTile(
                  icon: Icons.backup_outlined,
                  color: Colors.blue,
                  title: '备份与恢复',
                  subtitle: '导出 / 导入数据',
                  onTap: () => context.push('/settings/backup'),
                ),
                const _Divider(),
                _buildTile(
                  icon: Icons.system_update,
                  color: Colors.orange,
                  title: '检查更新',
                  subtitle: 'GitHub Release',
                  onTap: () => context.push('/settings/update'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // AI 状态诊断
          _AiStatusPanel(contactsAsync: contactsAsync),
          const SizedBox(height: 8),
          // 其他
          _buildSectionHeader('其他'),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildTile(
                  icon: Icons.school_outlined,
                  color: Colors.teal,
                  title: '新手引导',
                  subtitle: '重新查看引导教程',
                  onTap: () => _restartOnboarding(context),
                ),
                const _Divider(),
                _buildTile(
                  icon: Icons.info_outline,
                  color: WeChatColors.textSecondary,
                  title: '关于 SoulTalk',
                  subtitleWidget: FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Text(
                          'v${snapshot.data!.version}',
                          style: TextStyle(
                            fontSize: 12,
                            color: WeChatColors.textSecondary,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  onTap: () => _showAbout(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildUserCard(
    List apiConfigs,
    AsyncValue contactsAsync,
    WidgetRef ref,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [WeChatColors.primary, WeChatColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SoulTalk',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  apiConfigs.isEmpty
                      ? '请先配置 API'
                      : '已连接 ${apiConfigs.length} 个 API',
                  style: const TextStyle(
                    color: WeChatColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          color: WeChatColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color color,
    required String title,
    String subtitle = '',
    Widget? subtitleWidget,
    VoidCallback? onTap,
    bool warning = false,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle:
          subtitleWidget ??
          (subtitle.isNotEmpty
              ? Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: warning ? Colors.orange : WeChatColors.textSecondary,
                  ),
                )
              : null),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (warning)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.warning_amber, color: Colors.orange, size: 18),
            ),
          const Icon(Icons.chevron_right, color: WeChatColors.textHint),
        ],
      ),
      onTap: onTap,
    );
  }

  Future<void> _restartOnboarding(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重新开始引导'),
        content: const Text('将重新打开新手引导页面，不会影响已有数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '开始',
              style: TextStyle(color: WeChatColors.primary),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final router = GoRouter.of(context);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_done');
    router.go('/onboarding');
  }

  Future<void> _showAbout(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    showAboutDialog(
      context: context,
      applicationName: 'SoulTalk',
      applicationVersion: 'v${info.version}',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: WeChatColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.chat_bubble_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      applicationLegalese:
          'SoulTalk - AI 驱动的微信风格社交应用\n支持 OpenAI、Anthropic 等多种 LLM',
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 0, indent: 56, endIndent: 16);
  }
}

class _AiStatusPanel extends StatelessWidget {
  final AsyncValue contactsAsync;
  const _AiStatusPanel({required this.contactsAsync});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(
                  Icons.monitor_heart_outlined,
                  color: WeChatColors.primary,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'AI 状态诊断',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Divider(height: 8),
          contactsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: _StatusRow(
                icon: Icons.error_outline,
                color: Colors.red,
                label: '加载失败',
                detail: e.toString(),
              ),
            ),
            data: (contacts) {
              final contactList = (contacts as List).cast<dynamic>();
              if (contactList.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: _StatusRow(
                    icon: Icons.info_outline,
                    color: WeChatColors.textHint,
                    label: '暂无 AI 角色',
                    detail: '点击上方"角色管理"创建',
                  ),
                );
              }

              final total = contactList.length;
              final proactiveEnabled = contactList
                  .where((c) => c.proactiveEnabled == true)
                  .length;
              final withPrompt = contactList
                  .where((c) => (c.systemPrompt as String).isNotEmpty)
                  .length;
              final withApi = contactList
                  .where((c) => c.apiConfigId != null)
                  .length;
              final readyCount = contactList
                  .where(
                    (c) =>
                        c.proactiveEnabled == true &&
                        (c.systemPrompt as String).isNotEmpty,
                  )
                  .length;
              final progress = total > 0 ? readyCount / total : 0.0;

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text('自动行为就绪', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: const Color(0xFFE0E0E0),
                              valueColor: const AlwaysStoppedAnimation(
                                WeChatColors.primary,
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$readyCount/$total',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _StatusRow(
                      icon: Icons.auto_awesome,
                      color: proactiveEnabled > 0
                          ? WeChatColors.primary
                          : WeChatColors.textHint,
                      label: '主动消息',
                      detail: '$proactiveEnabled/$total 已启用',
                    ),
                    const SizedBox(height: 6),
                    _StatusRow(
                      icon: Icons.psychology,
                      color: withPrompt > 0
                          ? WeChatColors.primary
                          : Colors.orange,
                      label: '角色设定',
                      detail: withPrompt > 0
                          ? '$withPrompt/$total 已配置'
                          : '未配置（无法主动发消息）',
                    ),
                    const SizedBox(height: 6),
                    _StatusRow(
                      icon: Icons.api,
                      color: withApi > 0 ? WeChatColors.primary : Colors.orange,
                      label: 'API 绑定',
                      detail: '$withApi/$total 已绑定',
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String detail;

  const _StatusRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: WeChatColors.textPrimary),
        ),
        const Spacer(),
        Text(
          detail,
          style: const TextStyle(
            fontSize: 12,
            color: WeChatColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
