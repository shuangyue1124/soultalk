import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/connection_provider.dart';
import '../websocket_client.dart';
import '../theme/desktop_theme.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connState = ref.watch(pcConnectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SoulTalk PC'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildConnectionStatus(connState),
                const SizedBox(height: 32),
                _buildActionButtons(context, ref, connState),
                if (connState.error != null) ...[
                  const SizedBox(height: 16),
                  _buildError(connState.error!),
                ],
                if (connState.messages.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _buildMessagePreview(connState),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(PCConnectionState state) {
    final isConnected = state.connectionState == WsConnectionState.connected;
    final isConnecting =
        state.connectionState == WsConnectionState.connecting ||
        state.connectionState == WsConnectionState.reconnecting;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              isConnected ? Icons.computer : Icons.computer_outlined,
              size: 64,
              color: isConnected ? DesktopTheme.primary : DesktopTheme.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              isConnected
                  ? '已连接'
                  : isConnecting
                  ? '连接中...'
                  : '未连接',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isConnected
                    ? DesktopTheme.primary
                    : DesktopTheme.textSecondary,
              ),
            ),
            if (isConnected && state.deviceId != null) ...[
              const SizedBox(height: 8),
              Text(
                '设备 ID: ${state.deviceId}',
                style: const TextStyle(
                  fontSize: 12,
                  color: DesktopTheme.textHint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    PCConnectionState state,
  ) {
    final isConnected = state.connectionState == WsConnectionState.connected;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!isConnected) ...[
          ElevatedButton.icon(
            onPressed: () => context.push('/scan'),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('扫码连接'),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: () => _showManualConnectDialog(context, ref),
            icon: const Icon(Icons.edit),
            label: const Text('手动输入'),
          ),
        ] else ...[
          ElevatedButton.icon(
            onPressed: () =>
                ref.read(pcConnectionProvider.notifier).requestSync(),
            icon: const Icon(Icons.sync),
            label: const Text('同步消息'),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: () =>
                ref.read(pcConnectionProvider.notifier).disconnect(),
            icon: const Icon(Icons.link_off),
            label: const Text('断开连接'),
            style: OutlinedButton.styleFrom(
              foregroundColor: DesktopTheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildError(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DesktopTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DesktopTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: DesktopTheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: DesktopTheme.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagePreview(PCConnectionState state) {
    final messages = state.messages.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '最近消息',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '共 ${state.messages.length} 条',
                  style: const TextStyle(
                    fontSize: 12,
                    color: DesktopTheme.textHint,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...messages.map(
              (msg) => ListTile(
                dense: true,
                title: Text(
                  msg['content'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  msg['timestamp'] as String? ?? '',
                  style: const TextStyle(fontSize: 11),
                ),
                leading: Icon(
                  msg['fromPC'] == true ? Icons.computer : Icons.phone_android,
                  size: 20,
                  color: msg['fromPC'] == true
                      ? DesktopTheme.primary
                      : DesktopTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualConnectDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('手动连接（备用）'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '如无法扫码，可手动输入手机端的 WebSocket 地址：',
              style: TextStyle(fontSize: 13, color: DesktopTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'WebSocket 地址',
                hintText: 'ws://192.168.1.100:12345/ws?token=xxx',
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
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                ref.read(pcConnectionProvider.notifier).connect(url);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('连接'),
          ),
        ],
      ),
    );
  }
}
