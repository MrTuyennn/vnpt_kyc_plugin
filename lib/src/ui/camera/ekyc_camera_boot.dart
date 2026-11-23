import 'package:camera/camera.dart';

import 'package:vnpt_kyc_plugin/src/ui/ekyc_log.dart';

class EkycCameraBootResult {
  const EkycCameraBootResult({this.controller, this.userMessage});

  final CameraController? controller;
  final String? userMessage;

  bool get ok => controller != null;
}

/// Opens camera via [CameraController.initialize] — iOS/Android request permission here.
/// Do not pre-check with permission_handler (misreports on iOS without Pod macros).
Future<EkycCameraBootResult> bootCamera({
  required CameraLensDirection lens,
  bool requireLens = false,
  ImageFormatGroup? imageFormatGroup,

  /// `medium` (~720p) then native scale→180 + oval ROI — parity SDK `HEIGHT_RESOLUTION_VIDEO`.
  ResolutionPreset preset = ResolutionPreset.medium,
}) async {
  CameraController? controller;
  try {
    final cams = await availableCameras();
    if (cams.isEmpty) {
      return const EkycCameraBootResult(userMessage: 'No camera on device');
    }
    final matching = cams.where((camera) => camera.lensDirection == lens);
    if (requireLens && matching.isEmpty) {
      return EkycCameraBootResult(
        userMessage: lens == CameraLensDirection.front
            ? 'Không có camera trước'
            : 'Không có camera sau',
      );
    }
    final cam = matching.isNotEmpty ? matching.first : cams.first;
    final ctrl = controller = CameraController(
      cam,
      preset,
      enableAudio: false,
      imageFormatGroup: imageFormatGroup,
    );
    await ctrl.initialize();
    EkycLog.d('camera', 'ready ${cam.name} lens=$lens');
    return EkycCameraBootResult(controller: ctrl);
  } on CameraException catch (e) {
    await controller?.dispose();
    EkycLog.e('camera', 'init ${e.code}', e.description);
    final msg = _messageForCode(e.code);
    return EkycCameraBootResult(userMessage: msg);
  } catch (e, st) {
    await controller?.dispose();
    EkycLog.e('camera', 'init failed', e);
    EkycLog.e('camera', st.toString());
    return EkycCameraBootResult(userMessage: 'Camera error: $e');
  }
}

String _messageForCode(String code) {
  switch (code) {
    case 'CameraAccessDenied':
    case 'cameraPermissionDenied':
      return 'Camera denied — iOS Settings → app → enable Camera, then reopen app';
    case 'CameraAccessDeniedWithoutPrompt':
      return 'Camera blocked — enable in Settings and force-quit app';
    default:
      return 'Camera init failed ($code)';
  }
}
