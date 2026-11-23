import 'dart:async';

import 'package:camera/camera.dart';
import 'package:vnpt_kyc_plugin/src/platform/platform.dart';
import 'package:vnpt_kyc_plugin/src/core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  String _hint = 'Đang mở camera…';
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
        setState(() => _hint = boot.userMessage ?? 'Không mở được camera.');
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
      );
      await stream.start(_onFrame);
      if (mounted && !_closing) {
        setState(() => _hint = 'Đặt giấy tờ vào khung');
      }
    } catch (error, stack) {
      EkycLog.e('card', 'Không khởi động được camera', error, stack);
      if (mounted && !_closing) {
        setState(
            () => _hint = 'Không khởi động được camera. Hãy mở lại bước này.');
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
      final hint = ready ? 'Giữ yên rồi bấm chụp' : _cardHint(code);
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
      _hint = 'Đang kiểm tra ảnh chụp…';
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
    var hint = 'Không chụp được ảnh. Hãy thử lại.';
    try {
      await _stream?.stop();
      await _frameCheck;
      if (!mounted || _closing) return false;
      final jpeg = await captureStillJpeg(camera);
      if (jpeg != null && mounted && !_closing) {
        final image = await prepareCardCapture(jpeg);
        if (!mounted || _closing) return false;
        final code = await widget.core.commitCardCapture(
          image.full,
          isFront: widget.isFront,
          guideJpeg: image.crop,
          cropParam: image.cropParam,
        );
        if (code == MessageResult.cardValid) return true;
        hint = _cardHint(code);
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
        setState(
            () => _hint = 'Không mở lại được camera. Hãy mở lại bước này.');
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
    final side = widget.isFront ? 'Mặt trước' : 'Mặt sau';
    const surface = Color(0xFF161D25);
    final outline = _ready ? const Color(0xff00bd78) : const Color(0xffffbb32);
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text('Căn Cước ${side.toLowerCase()}'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: outline,
                      fontSize: 17,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                final viewport = ovalViewport(constraints.biggest);
                final guide = cardGuide(viewport.size).shift(viewport.topLeft);
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
                    CustomPaint(painter: _CardMask(guide, outline)),
                  ],
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    disabledBackgroundColor: Colors.white12,
                    disabledForegroundColor: Colors.white54,
                  ),
                  onPressed: _ready && !_capturing ? _capture : null,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(_capturing
                      ? 'Đang xử lý…'
                      : 'Chụp ${side.toLowerCase()}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _cardHint(int code) => switch (code) {
      22 => 'Đổi góc để tránh ánh sáng phản chiếu',
      27 => 'Ảnh chưa rõ. Giữ yên thẻ và camera',
      28 => 'Đưa camera ra xa một chút',
      29 => 'Đưa camera lại gần giấy tờ',
      30 => 'Đặt thẻ phẳng và giữ camera thẳng',
      23 || 24 || 25 || 26 => 'Đặt trọn bốn góc giấy tờ vào khung',
      _ => 'Đặt giấy tờ vào khung',
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
    canvas.drawPath(mask, Paint()..color = const Color(0x99161D25));
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
