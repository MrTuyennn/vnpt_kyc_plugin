import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';

import 'package:vnpt_kyc_plugin/src/ui/ekyc_log.dart';

/// Serializes [CameraController.takePicture] — only one capture at a time per process.
final class CameraCaptureGate {
  CameraCaptureGate._();
  static final CameraCaptureGate instance = CameraCaptureGate._();

  Future<void> _tail = Future<void>.value();

  Future<Uint8List?> captureJpeg(CameraController controller) async {
    final waitFor = _tail;
    final release = Completer<void>();
    _tail = release.future;

    await waitFor;
    try {
      if (!controller.value.isInitialized) {
        EkycLog.w('camera', 'controller not initialized');
        return null;
      }
      if (controller.value.isTakingPicture) {
        EkycLog.w('camera', 'skip frame — capture already in progress');
        return null;
      }
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      EkycLog.d('camera', 'captured ${bytes.length} bytes');
      return bytes;
    } on CameraException catch (e) {
      EkycLog.w('camera', '${e.code}: ${e.description ?? e.toString()}');
      return null;
    } catch (e, st) {
      EkycLog.e('camera', 'takePicture failed', e, st);
      return null;
    } finally {
      release.complete();
    }
  }
}