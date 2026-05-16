import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/connection_provider.dart';
import '../websocket_client.dart';
import '../theme/desktop_theme.dart';

/// PC 端二维码展示页面 —— 手机扫描 PC 二维码完成配对
class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  String? _qrData;

  @override
  void initState() {
    super.initState();
    _startPairing();
  }

  Future<void> _startPairing() async {
    try {
      final pairingUrl = await ref
          .read(pcConnectionProvider.notifier)
          .startPairingServer();
      if (mounted) {
        setState(() {
          _qrData = pairingUrl;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _qrData = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connState = ref.watch(pcConnectionProvider);

    // 连接成功后跳转首页
    ref.listen(pcConnectionProvider, (prev, next) {
      if (next.connectionState == WsConnectionState.connected) {
        context.go('/');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('扫码连接'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.phonelink,
                    size: 64,
                    color: DesktopTheme.primary,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '连接手机',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '请使用手机扫描下方二维码完成连接',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: DesktopTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildQRCode(connState),
                  const SizedBox(height: 16),
                  Text(
                    connState.isPairingServerRunning ? '等待手机扫描...' : '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: DesktopTheme.textHint,
                    ),
                  ),
                  if (connState.connectionState ==
                      WsConnectionState.connecting) ...[
                    const SizedBox(height: 12),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '正在连接手机...',
                          style: TextStyle(
                            fontSize: 13,
                            color: DesktopTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (connState.error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: DesktopTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: DesktopTheme.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: DesktopTheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              connState.error!,
                              style: const TextStyle(
                                color: DesktopTheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildHelpSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQRCode(PCConnectionState state) {
    if (_qrData == null && !state.isPairingServerRunning) {
      return Column(
        children: [
          const SizedBox(
            width: 220,
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _startPairing,
            icon: const Icon(Icons.refresh),
            label: const Text('重新生成二维码'),
          ),
        ],
      );
    }

    if (_qrData == null) {
      return const SizedBox(
        width: 220,
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: QrImageView(
            data: _qrData!,
            version: QrVersions.auto,
            size: 220,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _startPairing,
          icon: const Icon(Icons.refresh),
          label: const Text('刷新二维码'),
        ),
      ],
    );
  }

  Widget _buildHelpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '连接步骤',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: DesktopTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        _buildStep(1, '在手机端打开「我 → 连接电脑」'),
        _buildStep(2, '使用手机扫描上方二维码'),
        _buildStep(3, '等待自动连接完成'),
        const SizedBox(height: 16),
        const Text(
          '提示：二维码有效期为 2 分钟，过期请点击刷新',
          style: TextStyle(fontSize: 12, color: DesktopTheme.textHint),
        ),
      ],
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: DesktopTheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
