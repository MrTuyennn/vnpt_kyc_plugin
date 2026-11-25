import 'dart:ui' show Locale;

import 'package:vnpt_kyc_plugin/src/api/ekyc_proxy_client.dart';

/// Thông báo lỗi/trạng thái của luồng xác minh qua proxy, theo ngôn ngữ.
///
/// Dùng bản dựng sẵn bằng `EkycMessages.of(locale)` (hỗ trợ `vi`, `en`; ngôn ngữ
/// khác dùng `vi`), hoặc tự truyền chuỗi riêng qua constructor / [copyWith].
class EkycMessages {
  const EkycMessages({
    required this.imageQuality,
    required this.frontBackMismatch,
    required this.wrongDocumentType,
    required this.frontInvalid,
    required this.backInvalid,
    required this.invalidImageData,
    required this.watermark,
    required this.busy,
    required this.service,
    required this.auth,
    required this.recaptured,
    required this.cardNotGenuine,
    required this.faceMismatch,
    required this.spoofDetected,
    required this.livenessFailed,
    required this.fileTooLarge,
    required this.networkError,
    required this.sessionExpired,
  });

  /// Bản dựng sẵn theo [locale]: `en` → [en]; còn lại → [vi].
  factory EkycMessages.of(Locale locale) =>
      locale.languageCode.toLowerCase() == 'en' ? en : vi;

  final String imageQuality;
  final String frontBackMismatch;
  final String wrongDocumentType;
  final String frontInvalid;
  final String backInvalid;
  final String invalidImageData;
  final String watermark;
  final String busy;
  final String service;
  final String auth;
  final String recaptured;
  final String cardNotGenuine;

  /// `face/compare` trả về không khớp (`compare.isMatch == false`).
  final String faceMismatch;
  final String spoofDetected;
  final String livenessFailed;
  final String fileTooLarge;
  final String networkError;
  final String sessionExpired;

  static const vi = EkycMessages(
    imageQuality:
        'Ảnh giấy tờ không đạt chuẩn (quá mờ hoặc thiếu sáng), vui lòng chụp lại rõ nét hơn.',
    frontBackMismatch:
        'Hai mặt giấy tờ không cùng loại, vui lòng chụp mặt trước và mặt sau của cùng một giấy tờ.',
    wrongDocumentType:
        'Loại giấy tờ không hợp lệ, vui lòng dùng đúng loại giấy tờ được hỗ trợ.',
    frontInvalid:
        'Mặt trước giấy tờ không hợp lệ, vui lòng chụp đúng mặt trước.',
    backInvalid: 'Mặt sau giấy tờ không hợp lệ, vui lòng chụp đúng mặt sau.',
    invalidImageData:
        'Dữ liệu ảnh không hợp lệ, vui lòng chọn hoặc chụp lại ảnh.',
    watermark:
        'Ảnh có dấu hiệu không hợp lệ (watermark), vui lòng chụp lại giấy tờ gốc.',
    busy: 'Hệ thống đang bận, vui lòng thử lại sau ít phút.',
    service: 'Hệ thống xác thực đang gặp sự cố, vui lòng thử lại sau.',
    auth: 'Không thể xác thực với hệ thống eKYC, vui lòng liên hệ hỗ trợ.',
    recaptured:
        'Ảnh giấy tờ có dấu hiệu chụp lại từ màn hình hoặc bản in, vui lòng chụp trực tiếp giấy tờ thật.',
    cardNotGenuine:
        'Không nhận diện được giấy tờ thật, vui lòng chụp trực tiếp giấy tờ gốc.',
    faceMismatch:
        'Khuôn mặt không khớp với ảnh trên giấy tờ, vui lòng quét lại.',
    spoofDetected: 'Không nhận diện được khuôn mặt thật, vui lòng quét lại.',
    livenessFailed: 'Xác thực khuôn mặt không đạt, vui lòng quét lại.',
    fileTooLarge: 'Dung lượng ảnh vượt quá 5 MB.',
    networkError: 'Không kết nối được máy chủ eKYC, vui lòng quét lại.',
    sessionExpired:
        'Phiên xác thực đã kết thúc, vui lòng thực hiện lại từ đầu.',
  );

  static const en = EkycMessages(
    imageQuality:
        'The ID image does not meet the quality standard (too blurry or too dark). Please retake it more clearly.',
    frontBackMismatch:
        'The two sides are not the same type of document. Please capture the front and back of the same document.',
    wrongDocumentType:
        'Invalid document type. Please use a supported document.',
    frontInvalid:
        'The front side is invalid. Please capture the correct front side.',
    backInvalid:
        'The back side is invalid. Please capture the correct back side.',
    invalidImageData:
        'Invalid image data. Please choose or capture the image again.',
    watermark:
        'The image looks invalid (watermark). Please capture the original document again.',
    busy: 'The system is busy. Please try again in a few minutes.',
    service:
        'The verification service is having problems. Please try again later.',
    auth:
        'Unable to authenticate with the eKYC service. Please contact support.',
    recaptured:
        'The ID image looks recaptured from a screen or print. Please capture the real document directly.',
    cardNotGenuine:
        'The document could not be verified as genuine. Please capture the original document directly.',
    faceMismatch: 'Your face does not match the ID photo. Please rescan.',
    spoofDetected: "This doesn't look like a live face. Please rescan.",
    livenessFailed: 'Face verification failed. Please rescan.',
    fileTooLarge: 'Image size must not exceed 5 MB.',
    networkError: "Couldn't reach the eKYC server. Please rescan.",
    sessionExpired: 'The verification session has ended. Please start over.',
  );

  /// Thông báo cho [error]; nếu mã chưa được map thì trả nội dung gốc của
  /// server (vẫn có thể hữu ích). `IDG-00010003` dùng chung cho hai lỗi nên
  /// phân biệt bằng nội dung.
  String forError(EkycProxyException error) {
    final text = switch (error.code) {
      'IDG-00010003' => error.message.contains('khong cung loai')
          ? frontBackMismatch
          : imageQuality,
      'IDG-00010445' => wrongDocumentType,
      'IDG-00010448' => frontInvalid,
      'IDG-00010449' => backInvalid,
      'IDG-00010446' => watermark,
      'IDG-00010102' ||
      'IDG-00010202' ||
      'IDG-00010302' ||
      'IDG-00010402' ||
      'IDG-00010444' ||
      'IDG-00010450' ||
      'IDG-00010451' ||
      'IDG-00010452' ||
      'IDG-00000400' =>
        invalidImageData,
      'IDG-00010004' => busy,
      'IDG-00000500' ||
      'IDG-00010101' ||
      'IDG-00010201' ||
      'IDG-00010301' ||
      'IDG-00010401' ||
      'IDG-00010501' =>
        service,
      'IDG-00000401' || 'IDG-00000404' => auth,
      'RECAPTURED_DOCUMENT' => recaptured,
      EkycProxyException.cardNotGenuine => cardNotGenuine,
      EkycProxyException.spoofDetected => spoofDetected,
      EkycProxyException.livenessFailed => livenessFailed,
      EkycProxyException.fileTooLarge => fileTooLarge,
      EkycProxyException.network => networkError,
      EkycProxyException.sessionNotActive => sessionExpired,
      _ => null,
    };
    return text ?? error.message;
  }

  EkycMessages copyWith({
    String? imageQuality,
    String? frontBackMismatch,
    String? wrongDocumentType,
    String? frontInvalid,
    String? backInvalid,
    String? invalidImageData,
    String? watermark,
    String? busy,
    String? service,
    String? auth,
    String? recaptured,
    String? cardNotGenuine,
    String? faceMismatch,
    String? spoofDetected,
    String? livenessFailed,
    String? fileTooLarge,
    String? networkError,
    String? sessionExpired,
  }) =>
      EkycMessages(
        imageQuality: imageQuality ?? this.imageQuality,
        frontBackMismatch: frontBackMismatch ?? this.frontBackMismatch,
        wrongDocumentType: wrongDocumentType ?? this.wrongDocumentType,
        frontInvalid: frontInvalid ?? this.frontInvalid,
        backInvalid: backInvalid ?? this.backInvalid,
        invalidImageData: invalidImageData ?? this.invalidImageData,
        watermark: watermark ?? this.watermark,
        busy: busy ?? this.busy,
        service: service ?? this.service,
        auth: auth ?? this.auth,
        recaptured: recaptured ?? this.recaptured,
        cardNotGenuine: cardNotGenuine ?? this.cardNotGenuine,
        faceMismatch: faceMismatch ?? this.faceMismatch,
        spoofDetected: spoofDetected ?? this.spoofDetected,
        livenessFailed: livenessFailed ?? this.livenessFailed,
        fileTooLarge: fileTooLarge ?? this.fileTooLarge,
        networkError: networkError ?? this.networkError,
        sessionExpired: sessionExpired ?? this.sessionExpired,
      );
}
