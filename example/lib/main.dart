import 'package:flutter/material.dart';
import 'package:vnpt_kyc_plugin/vnpt_kyc_plugin.dart';

import 'credentials_prefs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EkycSdk2ExampleApp());
}

class EkycSdk2ExampleApp extends StatelessWidget {
  const EkycSdk2ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VNPT eKYC',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const _Home(),
    );
  }
}

/// Màn demo tối giản: một nút mở luồng eKYC (`VnptEkyc.startFullFlow`).
class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  IdentityResult? _result;

  @override
  void initState() {
    super.initState();
    // Mở thẳng EkycFlowScreen ngay khi app khởi động.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final config = await CredentialsPrefs.load();
    if (!mounted) return;
    final result = await VnptEkyc.startFullFlow(context, config);
    if (!mounted) return;
    setState(() => _result = result.errorCode == 'CANCELLED' ? null : result);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result == null) {
      // Trong lúc luồng eKYC đang mở (hoặc người dùng vừa thoát): nền đen,
      // chạm nút để mở lại.
      return Scaffold(
        backgroundColor: const Color(0xff1c1e20),
        body: Center(
          child: FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Bắt đầu xác thực'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('VNPT eKYC')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  result.success
                      ? 'Thành công\n\n${result.ocrJson}'
                      : 'Lỗi ${result.errorCode}\n${result.errorMessage}',
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Bắt đầu xác thực'),
            ),
          ],
        ),
      ),
    );
  }
}
