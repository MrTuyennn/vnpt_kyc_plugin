/// Đường dẫn artifact của một phiên (ảnh CCCD, ảnh khuôn mặt, dữ liệu 3D).
class FullIdentityArtifactPaths {
  FullIdentityArtifactPaths({
    this.frontFullPath = '',
    this.backFullPath = '',
    this.frontCropPath = '',
    this.backCropPath = '',
    this.cropParamFront = '',
    this.cropParamBack = '',
    this.farPreviewPath = '',
    this.farCropPath = '',
    this.nearPreviewPath = '',
    this.nearCropPath = '',
    this.scan3dPath = '',
    this.faceLogPath = '',
  });

  String frontFullPath;
  String backFullPath;
  String frontCropPath;
  String backCropPath;
  String cropParamFront;
  String cropParamBack;
  String farPreviewPath;
  String farCropPath;
  String nearPreviewPath;
  String nearCropPath;
  String scan3dPath;
  String faceLogPath;
}

/// Kết quả chạy pipeline upload + OCR + liveness.
class PipelineResult {
  PipelineResult({
    this.success = false,
    this.ocrJson = '',
    this.liveness3dJson = '',
    this.errorCode = '',
    this.errorMessage = '',
  });

  bool success;
  String ocrJson;
  String liveness3dJson;
  String errorCode;
  String errorMessage;
}

/// Kết quả xác thực danh tính trả về cho app host.
typedef IdentityResult = PipelineResult;
