import 'package:vnpt_kyc_plugin/vnpt_kyc_plugin.dart';
import 'package:flutter/material.dart';

import 'build_env.dart';
import 'credentials_prefs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.core});

  final EkycCore core;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late EkycConfig _store;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _store = await CredentialsPrefs.load();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final fromBuild = BuildEkycEnv.isActive;
    return Scaffold(
      appBar: AppBar(title: const Text('T0 — Build config')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (fromBuild)
            const ListTile(
              leading: Icon(Icons.lock, color: Colors.teal),
              title: Text('Credentials baked in at build time'),
              subtitle: Text('Change env.local.json and rebuild with --dart-define-from-file'),
            )
          else
            const ListTile(
              leading: Icon(Icons.warning, color: Colors.orange),
              title: Text('No build-time creds'),
              subtitle: Text('Run: flutter run --dart-define-from-file=env.local.json'),
            ),
          _row('Access token', _masked(_store.accessToken)),
          _row('Token-id', _store.tokenId),
          _row('Token-key', _masked(_store.tokenKey)),
          _row('Challenge', _store.challengeCode),
          _row('Base URL', _store.baseUrl),
          _row('OCR token', _store.ocrToken),
          _row('checkLivenessFace', '${_store.checkLivenessFace}'),
          _row('modeFaceOval', '${_store.modeFaceOval}'),
          _row('stableFaceFrames', '${_store.stableFaceFrames}'),
          _row('isAutoCropParam', '${_store.isAutoCropParam}'),
          _row('enableFaceLog', '${_store.enableFaceLog}'),
          _row('sdkVersionLabel', _store.sdkVersionLabel),
          const SizedBox(height: 12),
          Text(
            _store.isValidForApi ? 'T0 PASS — API ready' : 'T0 FAIL — missing fields in env.local.json',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _store.isValidForApi ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => ListTile(
        title: Text(label),
        subtitle: SelectableText(value.isEmpty ? '(empty)' : value),
      );

  String _masked(String s) {
    if (s.length <= 8) return s.isEmpty ? '' : '***';
    return '${s.substring(0, 4)}…${s.substring(s.length - 4)}';
  }
}