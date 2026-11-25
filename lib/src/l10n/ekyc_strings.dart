import 'dart:ui' show Locale;

/// Chuỗi giao diện của plugin (màn luồng, màn quét CCCD, màn quét khuôn mặt).
///
/// Chọn bản dựng sẵn bằng `EkycStrings.of(locale)` (`vi`, `en`; ngôn ngữ khác
/// dùng `vi`) hoặc truyền chuỗi riêng qua `EkycConfig.strings` / [copyWith].
class EkycStrings {
  const EkycStrings({
    required this.flowTitle,
    required this.frontTitle,
    required this.backTitle,
    required this.faceTitle,
    required this.cardHint,
    required this.faceHint,
    required this.frontImage,
    required this.backImage,
    required this.noImage,
    required this.retake,
    required this.back,
    required this.next,
    required this.missingConfig,
    required this.noResult,
    required this.cameraOpening,
    required this.cameraUnavailable,
    required this.cameraStartFailed,
    required this.cameraReopenFailed,
    required this.sideFront,
    required this.sideBack,
    required this.cardSubtitle,
    required this.cardPlaceInFrame,
    required this.cardHoldAndCapture,
    required this.cardChecking,
    required this.cardCheckFailed,
    required this.cardCaptureFailed,
    required this.processing,
    required this.captureFront,
    required this.captureBack,
    required this.cardGlare,
    required this.cardBlurry,
    required this.cardTooFar,
    required this.cardTooNear,
    required this.cardNotFlat,
    required this.cardCorners,
    required this.ovalSubtitle,
    required this.ovalStepFar,
    required this.ovalStepNear,
    required this.ovalFar,
    required this.ovalNear,
    required this.ovalDone,
    required this.ovalSaving,
    required this.ovalApproach,
    required this.ovalCapturing,
    required this.ovalHoldStill,
    required this.ovalCloser,
    required this.ovalFurther,
    required this.ovalLookStraight,
    required this.ovalCenter,
    required this.ovalOneFace,
    required this.ovalPutInFrame,
    required this.ovalStartFailed,
    required this.ovalTimeout,
    required this.ovalSaveFailed,
  });

  /// Bản dựng sẵn theo [locale]: `en` → [en]; còn lại → [vi].
  factory EkycStrings.of(Locale locale) =>
      locale.languageCode.toLowerCase() == 'en' ? en : vi;

  // Màn luồng
  final String flowTitle;
  final String frontTitle;
  final String backTitle;
  final String faceTitle;
  final String cardHint;
  final String faceHint;
  final String frontImage;
  final String backImage;
  final String noImage;
  final String retake;
  final String back;
  final String next;
  final String missingConfig;
  final String noResult;

  // Camera
  final String cameraOpening;
  final String cameraUnavailable;
  final String cameraStartFailed;
  final String cameraReopenFailed;

  // Quét CCCD
  final String sideFront;
  final String sideBack;
  final String cardSubtitle;
  final String cardPlaceInFrame;
  final String cardHoldAndCapture;
  final String cardChecking;
  final String cardCheckFailed;
  final String cardCaptureFailed;
  final String processing;
  final String captureFront;
  final String captureBack;
  final String cardGlare;
  final String cardBlurry;
  final String cardTooFar;
  final String cardTooNear;
  final String cardNotFlat;
  final String cardCorners;

  // Quét khuôn mặt
  final String ovalSubtitle;
  final String ovalStepFar;
  final String ovalStepNear;
  final String ovalFar;
  final String ovalNear;
  final String ovalDone;
  final String ovalSaving;
  final String ovalApproach;
  final String ovalCapturing;
  final String ovalHoldStill;
  final String ovalCloser;
  final String ovalFurther;
  final String ovalLookStraight;
  final String ovalCenter;
  final String ovalOneFace;
  final String ovalPutInFrame;
  final String ovalStartFailed;
  final String ovalTimeout;
  final String ovalSaveFailed;

  static const vi = EkycStrings(
    flowTitle: 'Xác minh danh tính',
    frontTitle: 'Căn Cước mặt trước',
    backTitle: 'Căn Cước mặt sau',
    faceTitle: 'Ảnh chân dung',
    cardHint: 'Giấy tờ rõ nét, không che khuất, không bị mờ hay chói sáng.',
    faceHint: 'Xác thực ở nơi có đủ ánh sáng và không đeo phụ kiện che mặt.',
    frontImage: 'Ảnh mặt trước',
    backImage: 'Ảnh mặt sau',
    noImage: 'Chưa có ảnh',
    retake: 'Nhấn để chụp lại',
    back: 'Quay lại',
    next: 'Tiếp tục',
    missingConfig: 'Thiếu cấu hình VNPT. Hãy kiểm tra cài đặt trước khi gửi.',
    noResult: 'Không nhận được kết quả. Hãy thử lại.',
    cameraOpening: 'Đang mở camera…',
    cameraUnavailable: 'Không mở được camera.',
    cameraStartFailed: 'Không khởi động được camera. Hãy mở lại bước này.',
    cameraReopenFailed: 'Không mở lại được camera. Hãy mở lại bước này.',
    sideFront: 'mặt trước',
    sideBack: 'mặt sau',
    cardSubtitle: 'Đặt thẻ trong khung, không làm che khuất thông tin trên thẻ',
    cardPlaceInFrame: 'Đặt giấy tờ vào khung',
    cardHoldAndCapture: 'Giữ yên rồi bấm chụp',
    cardChecking: 'Đang kiểm tra ảnh chụp…',
    cardCheckFailed: 'Chưa kiểm tra được ảnh. Giữ thẻ trong khung để thử lại.',
    cardCaptureFailed: 'Không chụp được ảnh. Hãy thử lại.',
    processing: 'Đang xử lý…',
    captureFront: 'Chụp mặt trước',
    captureBack: 'Chụp mặt sau',
    cardGlare: 'Đổi góc để tránh ánh sáng phản chiếu',
    cardBlurry: 'Ảnh chưa rõ. Giữ yên thẻ và camera',
    cardTooFar: 'Đưa camera ra xa một chút',
    cardTooNear: 'Đưa camera lại gần giấy tờ',
    cardNotFlat: 'Đặt thẻ phẳng và giữ camera thẳng',
    cardCorners: 'Đặt trọn bốn góc giấy tờ vào khung',
    ovalSubtitle: 'Nhìn thẳng vào camera, đưa mặt vào khung hình',
    ovalStepFar: 'Bước 1/2 · Mặt xa',
    ovalStepNear: 'Bước 2/2 · Mặt gần',
    ovalFar: 'Mặt xa',
    ovalNear: 'Mặt gần',
    ovalDone: 'Đã chụp xong',
    ovalSaving: 'Đang lưu ảnh…',
    ovalApproach: 'Tiến lại gần camera',
    ovalCapturing: 'Đang chụp…',
    ovalHoldStill: 'Giữ yên',
    ovalCloser: 'Gần hơn nữa',
    ovalFurther: 'Lùi xa một chút',
    ovalLookStraight: 'Nhìn thẳng vào camera',
    ovalCenter: 'Đưa mặt vào giữa khung oval',
    ovalOneFace: 'Chỉ để một khuôn mặt trong khung',
    ovalPutInFrame: 'Đưa mặt vào khung oval',
    ovalStartFailed: 'Không khởi động được xác thực khuôn mặt.',
    ovalTimeout: 'Đã hết thời gian xác thực. Vui lòng mở lại camera.',
    ovalSaveFailed: 'Không lưu được kết quả xác thực. Vui lòng mở lại camera.',
  );

  static const en = EkycStrings(
    flowTitle: 'Identity verification',
    frontTitle: 'ID card front',
    backTitle: 'ID card back',
    faceTitle: 'Portrait photo',
    cardHint: 'Clear, unobscured document with no blur or glare.',
    faceHint:
        'Verify in a well-lit place and remove anything covering your face.',
    frontImage: 'Front image',
    backImage: 'Back image',
    noImage: 'No image yet',
    retake: 'Tap to retake',
    back: 'Back',
    next: 'Continue',
    missingConfig:
        'VNPT configuration is missing. Check settings before sending.',
    noResult: 'No result received. Please try again.',
    cameraOpening: 'Opening camera…',
    cameraUnavailable: 'Unable to open the camera.',
    cameraStartFailed: 'Unable to start the camera. Please reopen this step.',
    cameraReopenFailed: 'Unable to reopen the camera. Please reopen this step.',
    sideFront: 'front',
    sideBack: 'back',
    cardSubtitle:
        'Place the card inside the frame without covering any details',
    cardPlaceInFrame: 'Place the document inside the frame',
    cardHoldAndCapture: 'Hold still, then tap capture',
    cardChecking: 'Checking the photo…',
    cardCheckFailed:
        'Unable to check the image. Keep the card in the frame to retry.',
    cardCaptureFailed: 'Unable to capture the photo. Please try again.',
    processing: 'Processing…',
    captureFront: 'Capture front',
    captureBack: 'Capture back',
    cardGlare: 'Change the angle to avoid glare',
    cardBlurry: 'Image is unclear. Hold the card and camera still',
    cardTooFar: 'Move the camera a little farther away',
    cardTooNear: 'Move the camera closer to the document',
    cardNotFlat: 'Lay the card flat and keep the camera straight',
    cardCorners: 'Fit all four corners of the document in the frame',
    ovalSubtitle:
        'Look straight at the camera and place your face in the frame',
    ovalStepFar: 'Step 1/2 · Far',
    ovalStepNear: 'Step 2/2 · Near',
    ovalFar: 'Far',
    ovalNear: 'Near',
    ovalDone: 'Capture complete',
    ovalSaving: 'Saving photo…',
    ovalApproach: 'Move closer to the camera',
    ovalCapturing: 'Capturing…',
    ovalHoldStill: 'Hold still',
    ovalCloser: 'Move closer',
    ovalFurther: 'Move back a little',
    ovalLookStraight: 'Look straight at the camera',
    ovalCenter: 'Center your face in the oval',
    ovalOneFace: 'Keep only one face in the frame',
    ovalPutInFrame: 'Place your face in the oval',
    ovalStartFailed: 'Unable to start face verification.',
    ovalTimeout: 'Verification timed out. Please reopen the camera.',
    ovalSaveFailed: 'Unable to save the result. Please reopen the camera.',
  );

  /// Tên mặt để ghép vào nhãn nút/tiêu đề.
  String captureLabel(bool isFront) => isFront ? captureFront : captureBack;

  EkycStrings copyWith({
    String? flowTitle,
    String? frontTitle,
    String? backTitle,
    String? faceTitle,
    String? cardHint,
    String? faceHint,
    String? frontImage,
    String? backImage,
    String? noImage,
    String? retake,
    String? back,
    String? next,
    String? missingConfig,
    String? noResult,
    String? cameraOpening,
    String? cameraUnavailable,
    String? cameraStartFailed,
    String? cameraReopenFailed,
    String? sideFront,
    String? sideBack,
    String? cardSubtitle,
    String? cardPlaceInFrame,
    String? cardHoldAndCapture,
    String? cardChecking,
    String? cardCheckFailed,
    String? cardCaptureFailed,
    String? processing,
    String? captureFront,
    String? captureBack,
    String? cardGlare,
    String? cardBlurry,
    String? cardTooFar,
    String? cardTooNear,
    String? cardNotFlat,
    String? cardCorners,
    String? ovalSubtitle,
    String? ovalStepFar,
    String? ovalStepNear,
    String? ovalFar,
    String? ovalNear,
    String? ovalDone,
    String? ovalSaving,
    String? ovalApproach,
    String? ovalCapturing,
    String? ovalHoldStill,
    String? ovalCloser,
    String? ovalFurther,
    String? ovalLookStraight,
    String? ovalCenter,
    String? ovalOneFace,
    String? ovalPutInFrame,
    String? ovalStartFailed,
    String? ovalTimeout,
    String? ovalSaveFailed,
  }) =>
      EkycStrings(
        flowTitle: flowTitle ?? this.flowTitle,
        frontTitle: frontTitle ?? this.frontTitle,
        backTitle: backTitle ?? this.backTitle,
        faceTitle: faceTitle ?? this.faceTitle,
        cardHint: cardHint ?? this.cardHint,
        faceHint: faceHint ?? this.faceHint,
        frontImage: frontImage ?? this.frontImage,
        backImage: backImage ?? this.backImage,
        noImage: noImage ?? this.noImage,
        retake: retake ?? this.retake,
        back: back ?? this.back,
        next: next ?? this.next,
        missingConfig: missingConfig ?? this.missingConfig,
        noResult: noResult ?? this.noResult,
        cameraOpening: cameraOpening ?? this.cameraOpening,
        cameraUnavailable: cameraUnavailable ?? this.cameraUnavailable,
        cameraStartFailed: cameraStartFailed ?? this.cameraStartFailed,
        cameraReopenFailed: cameraReopenFailed ?? this.cameraReopenFailed,
        sideFront: sideFront ?? this.sideFront,
        sideBack: sideBack ?? this.sideBack,
        cardSubtitle: cardSubtitle ?? this.cardSubtitle,
        cardPlaceInFrame: cardPlaceInFrame ?? this.cardPlaceInFrame,
        cardHoldAndCapture: cardHoldAndCapture ?? this.cardHoldAndCapture,
        cardChecking: cardChecking ?? this.cardChecking,
        cardCheckFailed: cardCheckFailed ?? this.cardCheckFailed,
        cardCaptureFailed: cardCaptureFailed ?? this.cardCaptureFailed,
        processing: processing ?? this.processing,
        captureFront: captureFront ?? this.captureFront,
        captureBack: captureBack ?? this.captureBack,
        cardGlare: cardGlare ?? this.cardGlare,
        cardBlurry: cardBlurry ?? this.cardBlurry,
        cardTooFar: cardTooFar ?? this.cardTooFar,
        cardTooNear: cardTooNear ?? this.cardTooNear,
        cardNotFlat: cardNotFlat ?? this.cardNotFlat,
        cardCorners: cardCorners ?? this.cardCorners,
        ovalSubtitle: ovalSubtitle ?? this.ovalSubtitle,
        ovalStepFar: ovalStepFar ?? this.ovalStepFar,
        ovalStepNear: ovalStepNear ?? this.ovalStepNear,
        ovalFar: ovalFar ?? this.ovalFar,
        ovalNear: ovalNear ?? this.ovalNear,
        ovalDone: ovalDone ?? this.ovalDone,
        ovalSaving: ovalSaving ?? this.ovalSaving,
        ovalApproach: ovalApproach ?? this.ovalApproach,
        ovalCapturing: ovalCapturing ?? this.ovalCapturing,
        ovalHoldStill: ovalHoldStill ?? this.ovalHoldStill,
        ovalCloser: ovalCloser ?? this.ovalCloser,
        ovalFurther: ovalFurther ?? this.ovalFurther,
        ovalLookStraight: ovalLookStraight ?? this.ovalLookStraight,
        ovalCenter: ovalCenter ?? this.ovalCenter,
        ovalOneFace: ovalOneFace ?? this.ovalOneFace,
        ovalPutInFrame: ovalPutInFrame ?? this.ovalPutInFrame,
        ovalStartFailed: ovalStartFailed ?? this.ovalStartFailed,
        ovalTimeout: ovalTimeout ?? this.ovalTimeout,
        ovalSaveFailed: ovalSaveFailed ?? this.ovalSaveFailed,
      );
}
