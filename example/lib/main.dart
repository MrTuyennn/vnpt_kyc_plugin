import 'package:vnpt_kyc_plugin/vnpt_kyc_plugin.dart';
import 'package:flutter/material.dart';

import 'credentials_prefs.dart';
import 'demo_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final core = EkycCore();
  final cfg = await CredentialsPrefs.load();
  await core.configure(cfg);
  runApp(EkycSdk2ExampleApp(core: core));
}

class EkycSdk2ExampleApp extends StatelessWidget {
  const EkycSdk2ExampleApp({super.key, required this.core});

  final EkycCore core;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VNPT eKYC SDK 2.0',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal), useMaterial3: true),
      home: DemoHomeScreen(core: core),
    );
  }
}