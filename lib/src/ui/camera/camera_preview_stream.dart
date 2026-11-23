import 'dart:async';

import 'package:camera/camera.dart';

import 'package:vnpt_kyc_plugin/src/ui/camera/camera_image_jpeg.dart';
import 'package:vnpt_kyc_plugin/src/ui/ekyc_log.dart';
import 'package:vnpt_kyc_plugin/src/ui/camera/preview_frame.dart';

/// Throttled preview frames from [CameraController.startImageStream] — silent (no shutter).
final class CameraPreviewStream {
  CameraPreviewStream({
    required this.controller,
    this.minInterval = const Duration(milliseconds: 450),
    this.jpegQuality = 85,
    this.rotationDegrees = 0,
    this.mirrorHorizontally = false,
    this.cropCard = false,
  });

  final CameraController controller;
  final Duration minInterval;
  final int jpegQuality;
  final int rotationDegrees;
  final bool mirrorHorizontally;
  final bool cropCard;

  bool _on = false;
  bool _busy = false;
  DateTime _lastTick = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> Function(PreviewFrame frame)? _handler;

  bool get isRunning => _on;

  Future<void> start(Future<void> Function(PreviewFrame frame) onFrame) async {
    if (_on) return;
    _handler = onFrame;
    if (!controller.value.isInitialized) return;
    if (controller.value.isStreamingImages) {
      EkycLog.w('camera', 'already streaming');
      _on = true;
      return;
    }
    _on = true;
    try {
      await controller.startImageStream(_onImage);
    } catch (_) {
      _on = false;
      _handler = null;
      rethrow;
    }
    EkycLog.d('camera', 'preview stream started (silent)');
  }

  void _onImage(CameraImage image) {
    if (!_on || _busy || _handler == null) return;
    final now = DateTime.now();
    if (now.difference(_lastTick) < minInterval) return;
    _busy = true;
    _lastTick = now;
    unawaited(
      (() async {
        try {
          final frame = await encodePreviewFrame(
            image,
            quality: jpegQuality,
            rotationDegrees: rotationDegrees,
            mirrorHorizontally: mirrorHorizontally,
            cropCard: cropCard,
          );
          final handler = _handler;
          if (frame != null && _on && handler != null) await handler(frame);
        } finally {
          _busy = false;
        }
      })(),
    );
  }

  Future<void> stop() async {
    _on = false;
    _handler = null;
    if (controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
        EkycLog.d('camera', 'preview stream stopped');
      } on CameraException catch (e) {
        EkycLog.w('camera', 'stopImageStream ${e.code}');
      }
    }
  }
}
