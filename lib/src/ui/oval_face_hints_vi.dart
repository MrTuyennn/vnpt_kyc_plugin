import 'package:vnpt_kyc_plugin/src/platform/platform.dart';

import 'package:vnpt_kyc_plugin/src/ui/oval_ux_models.dart';

String faceOvalInstructionVi(OvalPhaseUi phase, int modeFaceOval) {
  return switch (phase) {
    OvalPhaseUi.far => modeFaceOval == 0 ? 'Bước 1/2 · Mặt xa' : 'Mặt xa',
    OvalPhaseUi.near ||
    OvalPhaseUi.transitionToNear =>
      modeFaceOval == 0 ? 'Bước 2/2 · Mặt gần' : 'Mặt gần',
    OvalPhaseUi.done => 'Đã chụp xong',
  };
}

String faceOvalActionVi(int code,
    {required int stable, required int stableRequired}) {
  return switch (code) {
    MessageResult.fit => stable >= stableRequired ? 'Đang chụp…' : 'Giữ yên',
    MessageResult.tooFar => 'Gần hơn nữa',
    MessageResult.tooNear => 'Lùi xa một chút',
    MessageResult.notStraight => 'Nhìn thẳng vào camera',
    MessageResult.awayFromLeft ||
    MessageResult.awayFromTop ||
    MessageResult.awayFromRight ||
    MessageResult.awayFromBottom ||
    MessageResult.awayFromCenter =>
      'Đưa mặt vào giữa khung oval',
    MessageResult.manyFaces => 'Chỉ để một khuôn mặt trong khung',
    _ => 'Đưa mặt vào khung oval',
  };
}

ColorHint faceOvalColorHint(int code, int stable, int stableRequired) {
  if (code == MessageResult.fit && stable >= stableRequired - 1) {
    return ColorHint.success;
  }
  return switch (code) {
    MessageResult.fit => ColorHint.good,
    MessageResult.tooFar ||
    MessageResult.tooNear ||
    MessageResult.noFace =>
      ColorHint.adjust,
    _ => ColorHint.neutral,
  };
}

enum ColorHint { success, good, adjust, neutral }
