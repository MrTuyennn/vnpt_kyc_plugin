import 'package:flutter/foundation.dart';

abstract final class EkycSdkLog {
  static void d(String tag, String message) {
    if (kDebugMode) debugPrint('[EkycSDK/$tag] $message');
  }

  static void e(String tag, String message, [Object? e]) {
    if (kDebugMode) debugPrint('[EkycSDK/$tag] ERROR: $message${e != null ? ' — $e' : ''}');
  }
}