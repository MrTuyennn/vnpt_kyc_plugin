import 'package:vnpt_kyc_plugin/src/platform/platform.dart';

String messageResultLabel(int code) {
  switch (code) {
    case MessageResult.fit:
      return 'FIT';
    case MessageResult.tooFar:
      return 'TOO_FAR';
    case MessageResult.tooNear:
      return 'TOO_NEAR';
    case MessageResult.noFace:
      return 'NO_FACE';
    case MessageResult.cardValid:
      return 'CARD_VALID';
    case MessageResult.noCard:
      return 'NO_CARD';
    default:
      return 'HINT_$code';
  }
}