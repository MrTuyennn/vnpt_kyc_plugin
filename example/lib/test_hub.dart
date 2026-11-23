import 'package:vnpt_kyc_plugin/vnpt_kyc_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'credentials_prefs.dart';
import 'settings_screen.dart';

class TestHub extends StatefulWidget {
  const TestHub({super.key, required this.core});

  final EkycCore core;

  @override
  State<TestHub> createState() => _TestHubState();
}

class _TestHubState extends State<TestHub> {
  EkycConfig? _config;
  String _log = '';

  @override
  void initState() {
    super.initState();
    _refreshConfig();
  }

  Future<void> _refreshConfig() async {
    final c = await CredentialsPrefs.load();
    await widget.core.configure(c);
    if (mounted) setState(() => _config = c);
  }

  void _append(String s) {
    if (mounted) setState(() => _log = '$_log\n$s');
  }

  Future<void> _runFullIdentity() async {
    await widget.core.startSession();
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EkycCardScanner(core: widget.core, isFront: true)));
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EkycCardScanner(core: widget.core, isFront: false)));
    if (!mounted) return;
    final cfg = _config;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EkycOvalScanner(
          core: widget.core,
          modeFaceOval: cfg?.modeFaceOval ?? 0,
          stableFrames: cfg?.stableFaceFrames ?? 2,
        ),
      ),
    );
    final result = await widget.core.runFullIdentity();
    _append('T1 pipeline success=${result.success}');
    if (result.success) {
      _append(result.ocrJson.substring(0, result.ocrJson.length.clamp(0, 400)));
    } else {
      _append('${result.errorCode}: ${result.errorMessage}');
    }
  }

  Future<void> _cardFrontOnly() async {
    await widget.core.startSession();
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EkycCardScanner(core: widget.core, isFront: true)));
    _append('T2 front at ${widget.core.artifacts?.rootDir.path}');
  }

  Future<void> _cardFrontBack() async {
    await widget.core.startSession();
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EkycCardScanner(core: widget.core, isFront: true)));
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EkycCardScanner(core: widget.core, isFront: false)));
    _append('T3 artifacts at ${widget.core.artifacts?.rootDir.path}');
  }

  Future<void> _ovalFull() async {
    await widget.core.startSession();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EkycOvalScanner(core: widget.core, modeFaceOval: 0)),
    );
    _append('T4 scan3d: ${widget.core.artifacts?.scan3d}');
  }

  Future<void> _ovalFarOnly() async {
    await widget.core.startSession();
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EkycOvalScanner(core: widget.core, modeFaceOval: 1)));
  }

  Future<void> _engineOnly() async {
    await widget.core.startCardSession();
    _append('T9 card session started (open card scanner for live hints)');
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EkycCardScanner(core: widget.core, isFront: true)));
  }

  Future<void> _showArtifacts() async {
    final dir = widget.core.artifacts?.rootDir.path;
    if (dir == null) {
      _append('No session artifacts yet');
      return;
    }
    await Clipboard.setData(ClipboardData(text: dir));
    _append('T10 artifact dir copied:\n$dir');
    _append('L0: dart run tool/acceptance/l0_static_check.dart --dir $dir');
    _append('L1: dart run tool/acceptance/l1_manifest.dart record --label candidate --dir $dir --out /tmp/cand.json');
  }

  Widget _tile(String id, String title, VoidCallback onTap) {
    return ListTile(
      title: Text('$id — $title'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SDK 2.0 — Test hub'),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(core: widget.core)));
            if (!mounted) return;
            _refreshConfig();
          }),
        ],
      ),
      body: Column(
        children: [
          if (_config != null && !_config!.isValidForApi)
            const Material(
              color: Color(0xFFFFF3CD),
              child: ListTile(title: Text('Configure credentials in T0 before API cases')),
            ),
          Expanded(
            child: ListView(
              children: [
                _tile('T1', 'Full identity', _runFullIdentity),
                _tile('T2', 'Card front only', _cardFrontOnly),
                _tile('T6', 'Auto crop_param (toggle in T0)', () {
                  _append('T6: enable isAutoCropParam in Settings, then T1/T3');
                }),
                _tile('T7', 'iBeta vs standard (toggle in T0)', () {
                  _append('T7: set checkLivenessFace=1 or 2 in Settings');
                }),
                _tile('T8', 'Face log on/off (toggle in T0)', () {
                  _append('T8: toggle enableFaceLog, run T4, inspect .3dobj');
                }),
                _tile('T3', 'Card front + back only', _cardFrontBack),
                _tile('T4', 'Oval full + scan3d', _ovalFull),
                _tile('T5', 'Oval far-only', _ovalFarOnly),
                _tile('T9', 'Engine-only card hints', _engineOnly),
                _tile('T10', 'Export artifacts + L0/L1 cmds', _showArtifacts),
                _tile('T11', 'Pipeline from last session folder', () async {
                  final paths = widget.core.artifacts?.toPaths();
                  if (paths == null) return;
                  final r = await widget.core.runFullIdentityFromPaths(paths);
                  _append('T11 success=${r.success} err=${r.errorMessage}');
                }),
              ],
            ),
          ),
          Container(
            color: Colors.black12,
            height: 120,
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(child: Text(_log, style: const TextStyle(fontSize: 12))),
          ),
        ],
      ),
    );
  }
}