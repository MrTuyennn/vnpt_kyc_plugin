import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vnpt_kyc_plugin/src/core/ekyc_config.dart';
import 'package:vnpt_kyc_plugin/src/core/ekyc_core.dart';
import 'package:vnpt_kyc_plugin/src/core/ekyc_session_artifacts.dart';
import 'package:vnpt_kyc_plugin/src/core/pipeline_models.dart';
import 'package:vnpt_kyc_plugin/src/l10n/ekyc_strings.dart';
import 'package:vnpt_kyc_plugin/src/ui/ekyc_card_scanner.dart';
import 'package:vnpt_kyc_plugin/src/ui/ekyc_oval_scanner.dart';

enum _Step { front, back, face }

/// Màn hình điều phối luồng: 3 bước chụp rồi gửi VNPT. Dùng qua `VnptEkyc`.
class EkycFlowScreen extends StatefulWidget {
  const EkycFlowScreen({super.key, required this.core, required this.config});

  final EkycCore core;
  final EkycConfig config;

  @override
  State<EkycFlowScreen> createState() => _EkycFlowScreenState();
}

class _EkycFlowScreenState extends State<EkycFlowScreen> {
  bool _working = false;
  String? _error;
  IdentityResult? _lastResult;
  List<bool> _done = const [false, false, false];

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  /// Cập nhật trạng thái đã chụp của 3 bước (front, back, face).
  Future<void> _refresh() async {
    final art = _art;
    final face = await Future.wait([
      _has(art.farPreview),
      _has(art.nearPreview),
      _has(art.scan3d),
    ]);
    final done = [
      await _has(art.frontFull),
      await _has(art.backFull),
      face.every((e) => e),
    ];
    if (mounted) setState(() => _done = done);
  }

  EkycSessionArtifacts get _art => widget.core.artifacts!;

  EkycStrings get strings => widget.core.strings;

  List<String> _faceFiles(EkycSessionArtifacts art) => [
        art.farPreview,
        art.farCrop,
        art.nearPreview,
        art.nearCrop,
        art.scan3d,
        art.faceLog,
      ];

  Future<bool> _has(String path) async {
    final f = File(path);
    return await f.exists() && await f.length() > 0;
  }

  Future<void> _evict(String path) => FileImage(File(path)).evict();

  /// Mở scanner cho [step]. Chụp lại khuôn mặt thì sao lưu ảnh cũ và khôi phục
  /// nếu người dùng thoát giữa chừng.
  Future<void> _capture(_Step step) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    final art = _art;
    Directory? backup;
    var captured = false;
    try {
      if (step == _Step.face) {
        backup = Directory('${art.rootDir.path}/face_backup');
        if (await backup.exists()) await backup.delete(recursive: true);
        await backup.create();
        for (final path in _faceFiles(art)) {
          final file = File(path);
          if (await file.exists()) {
            await file.copy('${backup.path}/${file.uri.pathSegments.last}');
          }
        }
        for (final path in _faceFiles(art)) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
      }
      if (!mounted) return;
      captured = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => step == _Step.face
                  ? EkycOvalScanner(
                      core: widget.core,
                      modeFaceOval: widget.config.modeFaceOval,
                      stableFrames: widget.config.stableFaceFrames,
                    )
                  : EkycCardScanner(
                      core: widget.core,
                      isFront: step == _Step.front,
                    ),
            ),
          ) ==
          true;
      if (captured && step != _Step.face) {
        await _evict(step == _Step.front ? art.frontFull : art.backFull);
        await _evict(step == _Step.front ? art.frontCrop : art.backCrop);
      }
    } finally {
      if (backup != null && await backup.exists()) {
        if (!captured) {
          for (final path in _faceFiles(art)) {
            final saved =
                File('${backup.path}/${File(path).uri.pathSegments.last}');
            if (await saved.exists()) await saved.copy(path);
          }
        }
        await backup.delete(recursive: true);
      }
      await _refresh();
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _submit() async {
    if (!widget.config.isValidForApi) {
      setState(() => _error = strings.missingConfig);
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final result = await widget.core.runFullIdentity();
      _lastResult = result;
      if (!mounted) return;
      if (result.success) {
        Navigator.of(context).pop(result);
        return;
      }
      setState(() => _error = result.errorMessage);
    } catch (_) {
      if (mounted) setState(() => _error = strings.noResult);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Ô xem ảnh đầy đủ; chạm để mở toàn màn hình (zoom được).
  Widget _imageBox(String label, String path, bool exists) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 5),
          InkWell(
            onTap: exists ? () => _showFull(label, path) : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 200,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xff383a3d),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: exists
                  ? Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      key: ValueKey('$path:${File(path).lastModifiedSync()}'),
                    )
                  : Text(strings.noImage,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showFull(String title, String path) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child:
                    Center(child: Image.file(File(path), fit: BoxFit.contain)),
              ),
            ),
            SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                  Text(title),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xffffbb32);
    const surface = Color(0xff1c1e20);
    final art = _art;
    return PopScope<IdentityResult>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_working) Navigator.of(context).pop(_lastResult);
      },
      child: Theme(
        data: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: surface,
          colorScheme:
              const ColorScheme.dark(primary: yellow, surface: surface),
        ),
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: surface,
            centerTitle: true,
            title: Text(strings.flowTitle),
          ),
          body: SafeArea(
            child: Builder(
              builder: (context) {
                final done = _done;
                final rows = <(_Step, String, String, bool, String)>[
                  (
                    _Step.front,
                    strings.frontTitle,
                    strings.cardHint,
                    done[0],
                    art.frontCrop
                  ),
                  (
                    _Step.back,
                    strings.backTitle,
                    strings.cardHint,
                    done[1],
                    art.backCrop
                  ),
                  (
                    _Step.face,
                    strings.faceTitle,
                    strings.faceHint,
                    done[2],
                    art.nearPreview
                  ),
                ];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ListView(
                          children: [
                            for (final row in rows)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: InkWell(
                                  onTap:
                                      _working ? null : () => _capture(row.$1),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.white38),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(7),
                                          child: Container(
                                            width: 108,
                                            height: 68,
                                            color: const Color(0xff363229),
                                            child: row.$4
                                                ? Image.file(
                                                    File(row.$5),
                                                    fit: BoxFit.cover,
                                                    key: ValueKey(
                                                      '${row.$5}:${File(row.$5).lastModifiedSync()}',
                                                    ),
                                                  )
                                                : const Icon(Icons.add,
                                                    color: yellow, size: 28),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(row.$2,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              const SizedBox(height: 4),
                                              Text(
                                                row.$4
                                                    ? strings.retake
                                                    : row.$3,
                                                style: const TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (row.$4)
                                          const Padding(
                                            padding: EdgeInsets.all(8),
                                            child: Icon(
                                                Icons.check_circle_outline,
                                                color: Color(0xff00bc78)),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            _imageBox(
                                strings.frontImage, art.frontCrop, done[0]),
                            _imageBox(strings.backImage, art.backCrop, done[1]),
                            if (_error != null)
                              Text(_error!,
                                  style:
                                      const TextStyle(color: Colors.redAccent)),
                            if (_working)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _working
                                  ? null
                                  : () =>
                                      Navigator.of(context).pop(_lastResult),
                              child: Text(strings.back),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: !_working && done.every((e) => e)
                                  ? _submit
                                  : null,
                              child: Text(strings.next),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
