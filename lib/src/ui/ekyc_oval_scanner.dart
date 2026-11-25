import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:vnpt_kyc_plugin/src/platform/platform.dart';
import 'package:vnpt_kyc_plugin/src/core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:vnpt_kyc_plugin/src/ui/camera/camera_backdrop.dart';
import 'package:vnpt_kyc_plugin/src/ui/camera/camera_frame_util.dart';
import 'package:vnpt_kyc_plugin/src/ui/camera/camera_preview_stream.dart';
import 'package:vnpt_kyc_plugin/src/ui/camera/ekyc_camera_boot.dart';
import 'package:vnpt_kyc_plugin/src/ui/ekyc_log.dart';
import 'package:vnpt_kyc_plugin/src/ui/oval_face_hints_vi.dart';
import 'package:vnpt_kyc_plugin/src/ui/oval_ux_models.dart';
import 'package:vnpt_kyc_plugin/src/ui/camera/preview_frame.dart';

class EkycOvalScanner extends StatefulWidget {
  const EkycOvalScanner({
    super.key,
    required this.core,
    this.modeFaceOval = 0,
    this.stableFrames = 2,
    this.onCompleted,
  });

  final EkycCore core;
  final int modeFaceOval;
  final int stableFrames;
  final VoidCallback? onCompleted;

  @override
  State<EkycOvalScanner> createState() => _EkycOvalScannerState();
}

class _EkycOvalScannerState extends State<EkycOvalScanner> {
  CameraController? _controller;
  CameraPreviewStream? _stream;
  late final Future<void> _startup;
  Future<void>? _activeFrame;
  bool _engineStarted = false;

  late OvalPhaseUi _phase;
  int _stable = 0;
  int _lastCode = MessageResult.noFace;
  bool _saving = false;
  String? _error;
  final _elapsed = Stopwatch();

  @override
  void initState() {
    super.initState();
    _phase = widget.modeFaceOval == 2 ? OvalPhaseUi.near : OvalPhaseUi.far;
    _startup = _start();
  }

  Future<void> _start() async {
    try {
      final boot = await bootCamera(
        lens: CameraLensDirection.front,
        requireLens: true,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      _controller = boot.controller;
      if (!mounted) return;
      final camera = _controller;
      if (camera == null) {
        EkycLog.e('oval', 'camera: ${boot.userMessage}');
        setState(() => _error = widget.core.strings.cameraUnavailable);
        return;
      }
      await camera.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted) return;

      final isFar = _phase == OvalPhaseUi.far;
      await widget.core.startOvalSession(isFar: isFar);
      _engineStarted = true;
      if (!mounted) return;

      final stream = _stream = CameraPreviewStream(
        controller: camera,
        minInterval: const Duration(milliseconds: 150),
        rotationDegrees: defaultTargetPlatform == TargetPlatform.android
            ? camera.description.sensorOrientation
            : 0,
        // AVFoundation already mirrors both the preview and the video buffer.
        mirrorHorizontally: defaultTargetPlatform == TargetPlatform.android,
      );
      _elapsed.start();
      await stream.start((frame) async {
        if (!mounted || _error != null) return;
        final active = _activeFrame = _process(frame);
        try {
          await active;
        } finally {
          _activeFrame = null;
        }
      });
      if (mounted) setState(() {});
    } catch (error) {
      _showError(widget.core.strings.ovalStartFailed, error);
    }
  }

  Future<void> _process(PreviewFrame frame) async {
    if (_phase != OvalPhaseUi.far && _phase != OvalPhaseUi.near) return;
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        frame.width >= frame.height) {
      // AVFoundation can deliver a queued landscape frame as orientation locks.
      return;
    }
    try {
      final isFar = _phase == OvalPhaseUi.far;
      final code = await widget.core.processOvalFrame(
        frame.jpeg,
        phase: isFar ? 0 : 1,
        frameMs: _elapsed.elapsedMilliseconds,
        frameWidth: ekycOvalReferenceSize.width.toInt(),
        frameHeight: ekycOvalReferenceSize.height.toInt(),
      );
      if (!mounted) return;
      if (code == MessageResult.timeExceed) {
        _showError(widget.core.strings.ovalTimeout);
        return;
      }

      final stable = code == MessageResult.fit ? _stable + 1 : 0;
      final accepted =
          stable >= widget.stableFrames && code == MessageResult.fit;
      if (_lastCode != code || _stable != stable || accepted) {
        setState(() {
          _lastCode = code;
          _stable = stable;
          _saving = accepted;
        });
      }
      if (!accepted) return;

      // Commit the same frame that passed the native engine. The camera stays
      // live while the oval grows for the next step.
      await widget.core.saveOvalFrame(frame.jpeg, isFar: isFar);
      if (!mounted) return;
      await widget.core.notifyOvalCapture();
      if (!mounted) return;

      if (isFar && widget.modeFaceOval == 0) {
        setState(() {
          _saving = false;
          _phase = OvalPhaseUi.transitionToNear;
        });
        await Future<void>.delayed(_OvalGuide.transitionDuration);
        if (!mounted) return;
        setState(() {
          _phase = OvalPhaseUi.near;
          _lastCode = MessageResult.noFace;
          _stable = 0;
        });
        return;
      }

      await widget.core.finalizeScan3d();
      if (!mounted) return;
      setState(() => _phase = OvalPhaseUi.done);
      final navigator = Navigator.of(context);
      widget.onCompleted?.call();
      if (mounted) navigator.pop(true);
    } catch (error) {
      _showError(widget.core.strings.ovalSaveFailed, error);
    }
  }

  void _showError(String message, [Object? error]) {
    if (error != null) EkycLog.e('oval', message, error);
    if (mounted) setState(() => _error = message);
  }

  Future<void> _close(EkycCore core) async {
    await _startup;
    try {
      await _stream?.stop();
      await _activeFrame;
      await _controller?.dispose();
    } finally {
      if (_engineStarted) await core.endOvalSession();
    }
  }

  @override
  void dispose() {
    unawaited(_close(widget.core).catchError((Object error) {
      EkycLog.e('oval', 'Không giải phóng được phiên xác thực', error);
    }));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _controller;
    final strings = widget.core.strings;
    final isFar = _phase == OvalPhaseUi.far;
    final feedback = _error ??
        (_saving
            ? strings.ovalSaving
            : _phase == OvalPhaseUi.transitionToNear
                ? strings.ovalApproach
                : camera == null
                    ? strings.cameraOpening
                    : faceOvalAction(
                        strings,
                        _lastCode,
                        stable: _stable,
                        stableRequired: widget.stableFrames,
                      ));
    final fit = _lastCode == MessageResult.fit;
    // Cung xanh chạy quanh oval từ đỉnh theo chiều kim đồng hồ: mode 0 (xa + gần)
    // pha xa chạy nửa vòng đầu, pha gần nửa vòng sau; mode 1/2 chạy trọn vòng.
    final stableRatio =
        fit ? (_stable / widget.stableFrames).clamp(0.0, 1.0) : 0.0;
    final twoPhase = widget.modeFaceOval == 0;
    final progress = switch (_phase) {
      OvalPhaseUi.done => 1.0,
      OvalPhaseUi.transitionToNear => 0.5,
      OvalPhaseUi.far => twoPhase ? stableRatio * 0.5 : stableRatio,
      OvalPhaseUi.near => twoPhase ? 0.5 + stableRatio * 0.5 : stableRatio,
    };
    final normalized = normalizedOvalOverlay(
      isFar: isFar,
      useIosGuide: defaultTargetPlatform == TargetPlatform.iOS,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF161D25),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Oval giữ nguyên như cũ: chiếu lên vùng 3:4 giữa màn hình.
          final viewport = ovalViewport(constraints.biggest);
          final oval = projectOvalGuide(normalized, viewport);
          return Stack(
            fit: StackFit.expand,
            children: [
              if (camera != null && camera.value.isInitialized)
                CameraBackdrop(
                  controller: camera,
                  ovalRegionWidthFitsScreen: true,
                ),
              if (camera != null && _error == null)
                _OvalGuide(
                  project: (rect) => projectOvalGuide(rect, viewport),
                  normalized: normalized,
                  progress: progress,
                ),
              if (camera != null)
                Positioned(
                  top: oval.bottom + 24,
                  left: 16,
                  right: 16,
                  child: Center(
                    child: _StatusPill(
                      text: feedback,
                      state: _error != null
                          ? _PillState.error
                          : fit
                              ? _PillState.ok
                              : _PillState.hint,
                    ),
                  ),
                ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Material(
                          color: const Color(0x59000000),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(context).pop(),
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(Icons.arrow_back,
                                  color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      strings.faceTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Text(
                        strings.ovalSubtitle,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _PillState { ok, hint, error }

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.state});

  final String text;
  final _PillState state;

  @override
  Widget build(BuildContext context) {
    final (bg, border, icon, iconColor) = switch (state) {
      _PillState.ok => (
          const Color(0xD91B4332),
          const Color(0xFF2E8F62),
          Icons.check_circle,
          const Color(0xFF4ADE9A),
        ),
      _PillState.hint => (
          const Color(0xD9262A2E),
          const Color(0x4DFFFFFF),
          Icons.info,
          const Color(0xFFFFBB32),
        ),
      _PillState.error => (
          const Color(0xD9552626),
          const Color(0xFFB04A4A),
          Icons.error,
          const Color(0xFFFF8A80),
        ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OvalGuide extends StatelessWidget {
  const _OvalGuide({
    required this.project,
    required this.normalized,
    required this.progress,
  });

  static const transitionDuration = Duration(milliseconds: 500);

  final Rect Function(Rect normalized) project;
  final Rect normalized;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Rect?>(
      tween: RectTween(end: normalized),
      duration: transitionDuration,
      curve: Curves.easeInOut,
      builder: (context, rect, _) {
        final oval = project(rect!);
        return CustomPaint(painter: _OvalMask(oval, progress));
      },
    );
  }
}

class _OvalMask extends CustomPainter {
  const _OvalMask(this.oval, this.progress);

  final Rect oval;
  final double progress;

  static const _stroke = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(oval);
    canvas.drawPath(outside, Paint()..color = const Color(0x99161D25));
    canvas.drawOval(
      oval,
      Paint()
        ..color = const Color(0x99B8BDC2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke,
    );
    if (progress > 0) {
      canvas.drawArc(
        oval,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = const Color(0xFF34B873)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = _stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_OvalMask oldDelegate) =>
      oldDelegate.oval != oval || oldDelegate.progress != progress;
}
