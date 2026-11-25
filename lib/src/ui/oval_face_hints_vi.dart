import 'package:vnpt_kyc_plugin/src/l10n/ekyc_strings.dart';
import 'package:vnpt_kyc_plugin/src/platform/platform.dart';

import 'package:vnpt_kyc_plugin/src/ui/oval_ux_models.dart';

String faceOvalInstruction(
    EkycStrings s, OvalPhaseUi phase, int modeFaceOval) {
  return switch (phase) {
    OvalPhaseUi.far => modeFaceOval == 0 ? s.ovalStepFar : s.ovalFar,
    OvalPhaseUi.near ||
    OvalPhaseUi.transitionToNear =>
      modeFaceOval == 0 ? s.ovalStepNear : s.ovalNear,
    OvalPhaseUi.done => s.ovalDone,
  };
}

String faceOvalAction(EkycStrings s, int code,
    {required int stable, required int stableRequired}) {
  return switch (code) {
    MessageResult.fit => stable >= stableRequired ? s.ovalCapturing : s.ovalHoldStill,
    MessageResult.tooFar => s.ovalCloser,
    MessageResult.tooNear => s.ovalFurther,
    MessageResult.notStraight => s.ovalLookStraight,
    MessageResult.awayFromLeft ||
    MessageResult.awayFromTop ||
    MessageResult.awayFromRight ||
    MessageResult.awayFromBottom ||
    MessageResult.awayFromCenter =>
      s.ovalCenter,
    MessageResult.manyFaces => s.ovalOneFace,
    _ => s.ovalPutInFrame,
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
