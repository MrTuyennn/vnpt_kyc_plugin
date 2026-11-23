import 'dart:async';

import 'package:camera/camera.dart';
import 'package:vnpt_kyc_plugin/src/platform/platform.dart';
import 'package:vnpt_kyc_plugin/src/core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        setState(() => _error = boot.userMessage ?? 'Không mở được camera');
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
      _showError('Không khởi động được xác thực khuôn mặt.', error);
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
        _showError('Đã hết thời gian xác thực. Vui lòng mở lại camera.');
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
      _showError(
          'Không lưu được kết quả xác thực. Vui lòng mở lại camera.', error);
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
    final isFar = _phase == OvalPhaseUi.far;
    final instruction = faceOvalInstructionVi(_phase, widget.modeFaceOval);
    final feedback = _error ??
        (_saving
            ? 'Đang lưu ảnh…'
            : _phase == OvalPhaseUi.transitionToNear
                ? 'Tiến lại gần camera'
                : camera == null
                    ? 'Đang mở camera…'
                    : faceOvalActionVi(
                        _lastCode,
                        stable: _stable,
                        stableRequired: widget.stableFrames,
                      ));
    final fit = _lastCode == MessageResult.fit;
    final primary = Theme.of(context).colorScheme.primary;
    final border = fit ? Colors.lightGreenAccent : Colors.white;

    return Scaffold(
      backgroundColor: const Color(0xFF161D25),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = ovalViewport(constraints.biggest);
          return Stack(
            fit: StackFit.expand,
            children: [
              if (camera != null && camera.value.isInitialized)
                Positioned.fromRect(
                  rect: viewport,
                  child: ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox.fromSize(
                        size: portraitPreviewSize(camera),
                        child: CameraPreview(camera),
                      ),
                    ),
                  ),
                ),
              if (camera != null && _error == null)
                _OvalGuide(
                  viewport: viewport,
                  normalized: normalizedOvalOverlay(
                    isFar: isFar,
                    useIosGuide: defaultTargetPlatform == TargetPlatform.iOS,
                  ),
                  border: border,
                ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 4),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Xác thực khuôn mặt',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Đóng',
                            color: Colors.white,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      color: _error == null ? primary : const Color(0xFF8C3434),
                      child: Text(
                        feedback,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _error == null
                              ? Theme.of(context).colorScheme.onPrimary
                              : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        instruction,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
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

class _OvalGuide extends StatelessWidget {
  const _OvalGuide({
    required this.viewport,
    required this.normalized,
    required this.border,
  });

  static const transitionDuration = Duration(milliseconds: 500);

  final Rect viewport;
  final Rect normalized;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Rect?>(
      tween: RectTween(end: normalized),
      duration: transitionDuration,
      curve: Curves.easeInOut,
      builder: (context, rect, _) {
        final oval = projectOvalGuide(rect!, viewport);
        return CustomPaint(painter: _OvalMask(oval, border));
      },
    );
  }
}

class _OvalMask extends CustomPainter {
  const _OvalMask(this.oval, this.border);

  final Rect oval;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(oval);
    canvas.drawPath(outside, Paint()..color = const Color(0x80161D25));
    canvas.drawOval(
      oval,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_OvalMask oldDelegate) =>
      oldDelegate.oval != oval || oldDelegate.border != border;
}
