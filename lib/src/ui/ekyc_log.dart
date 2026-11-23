import 'package:flutter/foundation.dart';

/// Console logs: filter Xcode / Logcat with `EkycSDK`.
abstract final class EkycLog {
  static void d(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[EkycSDK/$tag] $message');
    }
  }

  static void w(String tag, String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint('[EkycSDK/$tag] WARN: $message${error != null ? ' — $error' : ''}');
    }
  }

  static void e(String tag, String message, [Object? error, StackTrace? st]) {
    if (kDebugMode) {
      debugPrint('[EkycSDK/$tag] ERROR: $message${error != null ? ' — $error' : ''}');
      if (st != null) debugPrint('$st');
    }
  }
}