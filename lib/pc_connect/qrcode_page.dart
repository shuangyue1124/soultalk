import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../providers/pc_connect_provider.dart';
import '../theme/wechat_colors.dart';

/// 二维码扫描页面 — 手机扫描 PC 端二维码完成配对
class QRCodePage extends ConsumerStatefulWidget {
  const QRCodePage({super.key});

  @override
  ConsumerState<QRCodePage> createState() => _QRCodePageState();
}

class _QRCodePageState extends ConsumerState<QRCodePage> {
  MobileScannerController? _scannerController;
  bool _isScanning = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null) continue;

      // 验证是否为配对 URL 格式
      if (!rawValue.startsWith('http://') || !rawValue.contains('/pair?')) {
        continue;
      }

      setState(() {
        _isScanning = false;
      });

      ref.read(pcConnectProvider.notifier).completePairing(rawValue).then((
        success,
      ) {
        if (!mounted) return;
        if (!success) {
          setState(() {
            _isScanning = true;
            _errorMessage = '配对失败，请重试';
          });
        }
      });

      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectState = ref.watch(pcConnectProvider);

    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        title: const Text('连接电脑'),
        backgroundColor: WeChatColors.appBarBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          if (connectState.qrData != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '手动连接地址: ${connectState.qrData}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(pcConnectProvider.notifier).refreshQRCode(),
                    child: const Text('刷新'),
                  ),
                ],
              ),
            ),
          // 扫描区域
          Expanded(child: _buildScannerArea(connectState)),
          // 状态提示
          _buildStatusBar(connectState),
          if (connectState.errorMessage != null ||
              connectState.statusMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                connectState.errorMessage ?? connectState.statusMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: connectState.errorMessage == null
                      ? WeChatColors.textSecondary
                      : Colors.red,
                ),
              ),
            ),
          if (connectState.qrExpiresAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '二维码有效期至 ${connectState.qrExpiresAt!.hour.toString().padLeft(2, '0')}:${connectState.qrExpiresAt!.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 11,
                  color: WeChatColors.textHint,
                ),
              ),
            ),
          // 已连接设备
          if (connectState.connectedDevices.isNotEmpty) ...[
            _buildConnectedDevices(context, ref, connectState),
          ],
          // 设置
          _buildSettings(context, ref, connectState),
        ],
      ),
    );
  }

  Widget _buildScannerArea(PcConnectState state) {
    // 配对成功时显示结果
    if (state.pairingState == PairingState.success) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              '连接成功',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '已与 PC 端建立连接',
              style: TextStyle(color: WeChatColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (state.pairingState == PairingState.pairing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在连接 PC 端...', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        MobileScanner(controller: _scannerController, onDetect: _onDetect),
        // 扫描框
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        // 提示文字
        Positioned(
          bottom: 60,
          left: 0,
          right: 0,
          child: Column(
            children: [
              const Text(
                '将 PC 端二维码置于框内扫描',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBar(PcConnectState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 服务器状态
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: state.isServerRunning
                  ? Colors.green.shade50
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  state.isServerRunning
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  size: 16,
                  color: state.isServerRunning ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  state.isServerRunning ? '服务运行中' : '服务未启动',
                  style: TextStyle(
                    fontSize: 12,
                    color: state.isServerRunning
                        ? Colors.green.shade700
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (state.connectedDevices.isNotEmpty) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '已连接 ${state.connectedDevices.length} 台设备',
                style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectedDevices(
    BuildContext context,
    WidgetRef ref,
    PcConnectState state,
  ) {
    return SizedBox(
      height: 120,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '已连接设备',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: WeChatColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  if (state.connectedDevices.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        ref
                            .read(pcConnectProvider.notifier)
                            .disconnectAllDevices();
                      },
                      child: const Text(
                        '断开全部',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: state.connectedDevices.isEmpty
                    ? Center(
                        child: Text(
                          '暂无设备连接',
                          style: TextStyle(
                            color: WeChatColors.textHint,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView(
                        children: state.connectedDevices
                            .map(
                              (device) => ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.computer,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                title: Text(
                                  device.name,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                subtitle: Text(
                                  '最后活跃: ${_formatTime(device.lastActiveAt)}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.link_off,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(pcConnectProvider.notifier)
                                        .disconnectDevice(device.deviceId);
                                  },
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettings(
    BuildContext context,
    WidgetRef ref,
    PcConnectState state,
  ) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('禁止 PC 使用手机 API', style: TextStyle(fontSize: 14)),
            subtitle: const Text(
              '开启后 PC 只能使用独立配置',
              style: TextStyle(fontSize: 12),
            ),
            value: !state.allowPCUseApi,
            onChanged: (value) {
              ref.read(pcConnectProvider.notifier).setAllowPCUseApi(!value);
            },
            dense: true,
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('电脑断联后保持只读模式', style: TextStyle(fontSize: 14)),
            subtitle: const Text(
              'PC 可查看历史消息但无法发送',
              style: TextStyle(fontSize: 12),
            ),
            value: state.keepPCReadOnly,
            onChanged: (value) {
              ref.read(pcConnectProvider.notifier).setKeepPCReadOnly(value);
            },
            dense: true,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }
}
