import 'package:vnpt_kyc_plugin/vnpt_kyc_plugin.dart';
import 'package:flutter/material.dart';

import 'credentials_prefs.dart';
import 'api_result_screen.dart';
import 'identity_info_screen.dart';
import 'settings_screen.dart';
import 'test_hub.dart';

class DemoHomeScreen extends StatefulWidget {
  const DemoHomeScreen({super.key, required this.core});

  final EkycCore core;

  @override
  State<DemoHomeScreen> createState() => _DemoHomeScreenState();
}

class _DemoHomeScreenState extends State<DemoHomeScreen> {
  EkycConfig? _config;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await CredentialsPrefs.load();
    await widget.core.configure(c);
    if (mounted) setState(() => _config = c);
  }

  /// Chạy luồng eKYC bằng API cấp cao của plugin rồi hiển thị kết quả.
  Future<void> _startFlow(EkycConfig cfg) async {
    final navigator = Navigator.of(context);
    final result = await VnptEkyc.startFullFlow(
      context,
      cfg,
      core: widget.core,
    );
    if (!mounted || result.errorCode == 'CANCELLED') return;
    final dir = widget.core.artifacts?.rootDir.path;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => result.success
            ? IdentityInfoScreen(result: result, artifactDir: dir)
            : ApiResultScreen(result: result, artifactDir: dir),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config;
    final ready = cfg?.isValidForApi ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('VNPT eKYC SDK 2.0'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'SDK 2.0 Demo',
              applicationVersion: '0.1',
              children: const [
                Text(
                  'Luồng chính: Mặt trước → Mặt sau → Khuôn mặt → Thông tin CCCD.\n'
                  'Token: env.local.json + flutter run --dart-define-from-file=…',
                ),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: Icon(
                  ready ? Icons.verified : Icons.warning,
                  color: ready ? Colors.green : Colors.orange,
                ),
                title: Text(
                  ready ? 'Sẵn sàng gọi API' : 'Chưa có token build-time',
                ),
                subtitle: Text(
                  ready
                      ? (cfg!.baseUrl)
                      : 'env.local.json → flutter run --dart-define-from-file=env.local.json',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(core: widget.core),
                    ),
                  );
                  _load();
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Xác thực danh tính',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Chuẩn bị CCCD và chọn nơi đủ sáng. Bạn sẽ chụp hai mặt thẻ, xác thực khuôn mặt rồi xem thông tin VNPT đọc được.',
              style: TextStyle(height: 1.4),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: cfg == null
                  ? null
                  : () => _startFlow(cfg),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Bắt đầu xác thực'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TestHub(core: widget.core)),
              ),
              child: const Text('Công cụ kiểm tra'),
            ),
          ],
        ),
      ),
    );
  }
}
