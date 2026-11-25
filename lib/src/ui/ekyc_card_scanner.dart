import 'dart:async';

import 'package:camera/camera.dart';
import 'package:vnpt_kyc_plugin/src/platform/platform.dart';
import 'package:vnpt_kyc_plugin/src/core/core.dart';
import 'package:vnpt_kyc_plugin/src/l10n/ekyc_strings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:vnpt_kyc_plugin/src/ui/camera/camera_backdrop.dart';
import 'package:vnpt_kyc_plugin/src/ui/camera/camera_frame_util.dart';
import 'package:vnpt_kyc_plugin/src/ui/camera/camera_preview_stream.dart';
import 'package:vnpt_kyc_plugin/src/ui/card_capture_image.dart';
import 'package:vnpt_kyc_plugin/src/ui/camera/ekyc_camera_boot.dart';
import 'package:vnpt_kyc_plugin/src/ui/ekyc_log.dart';
import 'package:vnpt_kyc_plugin/src/ui/camera/preview_frame.dart';

class EkycCardScanner extends StatefulWidget {
  const EkycCardScanner({
    super.key,
    required this.core,
    required this.isFront,
    this.onCaptured,
  });

  final EkycCore core;
  final bool isFront;
  final VoidCallback? onCaptured;

  @override
  State<EkycCardScanner> createState() => _EkycCardScannerState();
}

class _EkycCardScannerState extends State<EkycCardScanner> {
  CameraController? _camera;
  CameraPreviewStream? _stream;
  late final Future<void> _startup;
  Future<void>? _frameCheck;
  Future<bool>? _captureWork;
  Future<void>? _releaseWork;
  bool _engineStarted = false;
  bool _capturing = false;
  bool _ready = false;
  bool _closing = false;
  final _previewClock = Stopwatch()..start();
  int? _lastValidMs;

  /// Kích thước màn hình (camera phủ kín): preview, crop và khung vẽ cùng dùng.
  Size get _viewSize {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return view.physicalSize / view.devicePixelRatio;
  }

  late String _hint = widget.core.strings.cameraOpening;
  Timer? _readyExpiry;

  @override
  void initState() {
    super.initState();
    _startup = _start();
  }

  Future<void> _start() async {
    try {
      final isIos = defaultTargetPlatform == TargetPlatform.iOS;
      final boot = await bootCamera(
        lens: CameraLensDirection.back,
        requireLens: true,
        preset: isIos ? ResolutionPreset.high : ResolutionPreset.medium,
        imageFormatGroup:
            isIos ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
      );
      _camera = boot.controller;
      if (!mounted || _closing) return;
      final camera = _camera;
      if (camera == null) {
        EkycLog.e('card', 'camera: ${boot.userMessage}');
        setState(() => _hint = widget.core.strings.cameraUnavailable);
        return;
      }
      await camera.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted || _closing) return;

      await widget.core.startCardSession();
      _engineStarted = true;
      if (!mounted || _closing) return;
      final stream = _stream = CameraPreviewStream(
        controller: camera,
        minInterval: const Duration(milliseconds: 250),
        rotationDegrees: isIos ? 0 : camera.description.sensorOrientation,
        cropCard: true,
        cardView: _viewSize,
      );
      await stream.start(_onFrame);
      if (mounted && !_closing) {
        setState(() => _hint = widget.core.strings.cardPlaceInFrame);
      }
    } catch (error, stack) {
      EkycLog.e('card', 'Không khởi động được camera', error, stack);
      if (mounted && !_closing) {
        setState(() => _hint = widget.core.strings.cameraStartFailed);
      }
    }
  }

  Future<void> _onFrame(PreviewFrame frame) async {
    if (!mounted || _capturing || _closing) return;
    final check = _frameCheck = _validate(frame);
    try {
      await check;
    } finally {
      _frameCheck = null;
    }
  }

  Future<void> _validate(PreviewFrame frame) async {
    final frameMs = _previewClock.elapsedMilliseconds;
    try {
      final code = await widget.core
          .validateCardFrame(frame.jpeg, isFront: widget.isFront);
      if (!mounted || _capturing || _closing) return;
      final valid = code == MessageResult.cardValid;
      _lastValidMs = valid ? frameMs : null;
      _readyExpiry?.cancel();
      final remaining = 1000 - (_previewClock.elapsedMilliseconds - frameMs);
      final ready = valid && remaining > 0;
      final strings = widget.core.strings;
      final hint =
          ready ? strings.cardHoldAndCapture : _cardHint(strings, code);
      if (_ready != ready || _hint != hint) {
        setState(() {
          _ready = ready;
          _hint = hint;
        });
      }
      if (ready) {
        _readyExpiry = Timer(Duration(milliseconds: remaining), () {
          if (!mounted || _capturing || _closing) return;
          setState(() {
            _ready = false;
            _hint = 'Đặt giấy tờ vào khung';
          });
        });
      }
    } catch (error, stack) {
      EkycLog.e('card', 'Lỗi kiểm tra ảnh', error, stack);
      if (mounted && !_capturing && !_closing) {
        setState(() {
          _ready = false;
          _hint = 'Chưa kiểm tra được ảnh. Giữ thẻ trong khung để thử lại.';
        });
      }
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    final lastValid = _lastValidMs;
    if (camera == null ||
        !_ready ||
        lastValid == null ||
        _previewClock.elapsedMilliseconds - lastValid >= 1000 ||
        _capturing ||
        _closing) {
      return;
    }
    _readyExpiry?.cancel();
    setState(() {
      _capturing = true;
      _ready = false;
      _hint = widget.core.strings.cardChecking;
    });
    final work = _captureWork = _commit(camera);
    final saved = await work;
    _captureWork = null;
    if (!mounted || _closing) return;
    if (saved) {
      _closing = true;
      await _release();
      if (!mounted) return;
      final navigator = Navigator.of(context);
      widget.onCaptured?.call();
      if (mounted) navigator.pop(true);
    }
  }

  Future<bool> _commit(CameraController camera) async {
    var hint = widget.core.strings.cardCaptureFailed;
    try {
      await _stream?.stop();
      await _frameCheck;
      if (!mounted || _closing) return false;
      final jpeg = await captureStillJpeg(camera);
      if (jpeg != null && mounted && !_closing) {
        final image = await prepareCardCapture(jpeg, view: _viewSize);
        if (!mounted || _closing) return false;
        final code = await widget.core.commitCardCapture(
          image.full,
          isFront: widget.isFront,
          guideJpeg: image.crop,
          cropParam: image.cropParam,
        );
        if (code == MessageResult.cardValid) return true;
        hint = _cardHint(widget.core.strings, code);
      }
    } catch (error, stack) {
      EkycLog.e('card', 'Không lưu được ảnh CCCD', error, stack);
    }
    if (!mounted || _closing) return false;
    setState(() {
      _capturing = false;
      _hint = hint;
    });
    try {
      await _stream?.start(_onFrame);
    } catch (error, stack) {
      EkycLog.e('card', 'Không mở lại được preview', error, stack);
      if (mounted && !_closing) {
        setState(() => _hint = widget.core.strings.cameraReopenFailed);
      }
    }
    return false;
  }

  Future<void> _release() => _releaseWork ??= _disposeResources();

  Future<void> _disposeResources() async {
    await _startup;
    try {
      await _captureWork;
      await _stream?.stop();
      await _frameCheck;
      await _camera?.dispose();
    } catch (error, stack) {
      EkycLog.e('card', 'Lỗi giải phóng camera', error, stack);
    } finally {
      if (_engineStarted) {
        try {
          await widget.core.endCardSession();
        } catch (error, stack) {
          EkycLog.e('card', 'Lỗi đóng phiên CCCD', error, stack);
        }
      }
    }
  }

  @override
  void dispose() {
    _closing = true;
    _readyExpiry?.cancel();
    unawaited(_release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final strings = widget.core.strings;
    const surface = Color(0xFF161D25);
    final outline = _ready ? const Color(0xff00bd78) : const Color(0xffffbb32);
    return Scaffold(
      backgroundColor: surface,
      body: LayoutBuilder(builder: (context, constraints) {
        // Camera phủ kín màn hình; khung thẻ nằm giữa, rộng 86% màn hình.
        final guide = cardGuide(constraints.biggest);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (camera != null && camera.value.isInitialized)
              CameraBackdrop(controller: camera),
            CustomPaint(painter: _CardMask(guide, outline)),
            SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    top: 8,
                    child: Material(
                      color: const Color(0x99161D25),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: strings.back,
                        color: Colors.white,
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    top: 64,
                    child: Column(
                      children: [
                        Text(
                          widget.isFront
                              ? strings.frontTitle
                              : strings.backTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.cardSubtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    top: guide.bottom + 24 - MediaQuery.paddingOf(context).top,
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _hint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: outline,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: const Color(0xffffbb32),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.white12,
                        disabledForegroundColor: Colors.white54,
                      ),
                      onPressed: _ready && !_capturing ? _capture : null,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(_capturing
                          ? strings.processing
                          : strings.captureLabel(widget.isFront)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

String _cardHint(EkycStrings s, int code) => switch (code) {
      22 => s.cardGlare,
      27 => s.cardBlurry,
      28 => s.cardTooFar,
      29 => s.cardTooNear,
      30 => s.cardNotFlat,
      23 || 24 || 25 || 26 => s.cardCorners,
      _ => s.cardPlaceInFrame,
    };

class _CardMask extends CustomPainter {
  const _CardMask(this.guide, this.outline);
  final Rect guide;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(guide, const Radius.circular(14));
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(frame);
    canvas.drawPath(mask, Paint()..color = const Color(0x8C161D25));
    final paint = Paint()
      ..color = outline
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const length = 30.0;
    const radius = 12.0;
    for (final sx in [-1.0, 1.0]) {
      for (final sy in [-1.0, 1.0]) {
        final x = sx < 0 ? guide.left : guide.right;
        final y = sy < 0 ? guide.top : guide.bottom;
        final path = Path()
          ..moveTo(x - sx * length, y)
          ..lineTo(x - sx * radius, y)
          ..quadraticBezierTo(x, y, x, y - sy * radius)
          ..lineTo(x, y - sy * length);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CardMask oldDelegate) =>
      oldDelegate.guide != guide || oldDelegate.outline != outline;
}
